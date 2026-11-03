import AppKit
import ApplicationServices
import Combine

/// Manages and monitors macOS Accessibility Permissions.
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    private let dismissedKey = "GateKeeperAccessibilityBannerDismissed"
    
    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public var isBannerDismissed: Bool {
        didSet {
            UserDefaults.standard.set(isBannerDismissed, forKey: dismissedKey)
        }
    }
    
    private var checkTimer: Timer?
    
    private init() {
        self.isBannerDismissed = UserDefaults.standard.bool(forKey: dismissedKey)
        checkPermission()
        startPeriodicCheck()
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    /// Checks current accessibility permission status without triggering a prompt.
    @discardableResult
    public func checkPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        if self.isAccessibilityGranted != isTrusted {
            DispatchQueue.main.async {
                self.isAccessibilityGranted = isTrusted
            }
        }
        return isTrusted
    }
    
    /// Prompts the macOS system prompt dialog to grant accessibility permissions.
    public func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.isAccessibilityGranted = isTrusted
        }
        
        if !isTrusted {
            openSystemSettings()
        }
    }
    
    public func dismissBanner() {
        isBannerDismissed = true
    }
    
    /// Opens the macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            let legacyUrl = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(legacyUrl)
        }
    }
    
    private func startPeriodicCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }
}
