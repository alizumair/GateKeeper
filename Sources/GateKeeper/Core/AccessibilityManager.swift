import AppKit
import ApplicationServices
import Combine

/// Manages and monitors macOS Accessibility Permissions required for workspace monitoring.
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public private(set) var isAccessibilityGranted: Bool = false
    private var checkTimer: Timer?
    
    private init() {
        checkPermission()
        startPeriodicCheck()
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    /// Checks current accessibility permission status without prompting.
    @discardableResult
    public func checkPermission() -> Bool {
        let isTrusted = AXIsProcessTrusted()
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
    
    /// Opens the macOS System Settings directly to Privacy & Security -> Accessibility.
    public func openSystemSettings() {
        // macOS Ventura, Sonoma, Sequoia URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            let legacyUrl = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
            NSWorkspace.shared.open(legacyUrl)
        }
    }
    
    /// Periodically checks permission so UI automatically updates when user grants it in System Settings.
    private func startPeriodicCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermission()
        }
    }
}
