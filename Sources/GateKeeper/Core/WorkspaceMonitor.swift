import AppKit
import Foundation
import Combine

/// Relock policy defining when an authenticated app must be locked again.
public enum RelockPolicy: String, CaseIterable, Identifiable {
    case immediately = "Immediately on switch"
    case after1Minute = "After 1 minute"
    case after5Minutes = "After 5 minutes"
    case after15Minutes = "After 15 minutes"
    
    public var id: String { rawValue }
    
    public var timeoutInterval: TimeInterval? {
        switch self {
        case .immediately: return nil
        case .after1Minute: return 60
        case .after5Minutes: return 300
        case .after15Minutes: return 900
        }
    }
}

/// Core engine that monitors workspace events and intercepts locked applications.
public final class WorkspaceMonitor: ObservableObject {
    public static let shared = WorkspaceMonitor()
    
    private let lockedAppsStorageKey = "GateKeeperLockedBundleIDs"
    private let engineEnabledKey = "GateKeeperEngineEnabled"
    private let relockPolicyKey = "GateKeeperRelockPolicy"
    
    @Published public var isEngineEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEngineEnabled, forKey: engineEnabledKey)
            if !isEngineEnabled {
                unlockedSessions.removeAll()
            }
        }
    }
    
    @Published public private(set) var lockedBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(lockedBundleIDs), forKey: lockedAppsStorageKey)
        }
    }
    
    @Published public var relockPolicy: RelockPolicy {
        didSet {
            UserDefaults.standard.set(relockPolicy.rawValue, forKey: relockPolicyKey)
        }
    }
    
    /// Maps bundle ID to timestamp when it was unlocked.
    private var unlockedSessions: [String: Date] = [:]
    
    /// Reference to currently intercepted app to avoid recursive interception.
    private var currentlyInterceptingBundleID: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.isEngineEnabled = UserDefaults.standard.object(forKey: engineEnabledKey) as? Bool ?? true
        
        let savedIDs = UserDefaults.standard.stringArray(forKey: lockedAppsStorageKey) ?? []
        self.lockedBundleIDs = Set(savedIDs)
        
        if let savedPolicyRaw = UserDefaults.standard.string(forKey: relockPolicyKey),
           let policy = RelockPolicy(rawValue: savedPolicyRaw) {
            self.relockPolicy = policy
        } else {
            self.relockPolicy = .immediately
        }
        
        setupWorkspaceObservers()
    }
    
    // MARK: - Lock State Management
    
    public func isAppLocked(_ bundleIdentifier: String) -> Bool {
        return lockedBundleIDs.contains(bundleIdentifier)
    }
    
    public func toggleAppLock(_ bundleIdentifier: String) {
        if lockedBundleIDs.contains(bundleIdentifier) {
            lockedBundleIDs.remove(bundleIdentifier)
            unlockedSessions.removeValue(forKey: bundleIdentifier)
        } else {
            lockedBundleIDs.insert(bundleIdentifier)
        }
    }
    
    public func lockAll(bundleIDs: [String]) {
        for id in bundleIDs {
            lockedBundleIDs.insert(id)
        }
    }
    
    public func unlockAll() {
        lockedBundleIDs.removeAll()
        unlockedSessions.removeAll()
    }
    
    // MARK: - Session Validation
    
    public func markAppUnlocked(_ bundleIdentifier: String) {
        unlockedSessions[bundleIdentifier] = Date()
    }
    
    public func relockApp(_ bundleIdentifier: String) {
        unlockedSessions.removeValue(forKey: bundleIdentifier)
    }
    
    public func isSessionValid(for bundleIdentifier: String) -> Bool {
        guard let unlockDate = unlockedSessions[bundleIdentifier] else {
            return false
        }
        
        if let timeout = relockPolicy.timeoutInterval {
            let elapsed = Date().timeIntervalSince(unlockDate)
            return elapsed < timeout
        } else {
            // For .immediately, valid only during its active run until deactivated
            return true
        }
    }
    
    // MARK: - Workspace Monitoring
    
    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        
        // Observe app activations
        center.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Observe app launches
        center.addObserver(
            self,
            selector: #selector(handleAppLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // Observe app deactivations (for immediate relocking)
        center.addObserver(
            self,
            selector: #selector(handleAppDeactivation(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func handleAppActivation(_ notification: Notification) {
        guard isEngineEnabled else { return }
        
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }
        
        checkAndIntercept(app: app, bundleID: bundleID)
    }
    
    @objc private func handleAppLaunch(_ notification: Notification) {
        guard isEngineEnabled else { return }
        
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }
        
        checkAndIntercept(app: app, bundleID: bundleID)
    }
    
    @objc private func handleAppDeactivation(_ notification: Notification) {
        guard isEngineEnabled else { return }
        
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }
        
        // If relock policy is immediate, deactivating the app terminates the unlocked session
        if relockPolicy == .immediately && lockedBundleIDs.contains(bundleID) {
            // Give a tiny grace period if it deactivated because our lock overlay or touch ID prompt appeared
            if currentlyInterceptingBundleID != bundleID {
                unlockedSessions.removeValue(forKey: bundleID)
            }
        }
    }
    
    private func checkAndIntercept(app: NSRunningApplication, bundleID: String) {
        // Do not intercept GateKeeper itself
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.gatekeeper.app"
        if bundleID == myBundleID {
            return
        }
        
        // Check if app is in locked set
        guard lockedBundleIDs.contains(bundleID) else {
            return
        }
        
        // If already validated in session, allow access
        if isSessionValid(for: bundleID) {
            return
        }
        
        // Prevent duplicate trigger for same app interception in flight
        if currentlyInterceptingBundleID == bundleID {
            return
        }
        
        currentlyInterceptingBundleID = bundleID
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            LockOverlayController.shared.presentLockOverlay(for: app) { [weak self] didUnlock in
                guard let self = self else { return }
                self.currentlyInterceptingBundleID = nil
                
                if didUnlock {
                    self.markAppUnlocked(bundleID)
                }
            }
        }
    }
}
