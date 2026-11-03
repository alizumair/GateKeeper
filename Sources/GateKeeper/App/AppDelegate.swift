import AppKit
import SwiftUI

/// Main application delegate handling the status bar item, popover lifecycle, and startup sequence.
public final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var onboardingWindowController: NSWindowController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run purely as an accessory / menu-bar agent (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupPopover()
        
        // Start background engines
        _ = WorkspaceMonitor.shared
        _ = AppScanner.shared
        _ = AccessibilityManager.shared
        _ = LaunchAtLoginManager.shared
        _ = RecoveryManager.shared
        
        // First launch checks
        checkFirstLaunchExperience()
    }
    
    // MARK: - Status Bar Item & Popover Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let lockImage = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "GateKeeper")?.withSymbolConfiguration(config) {
                lockImage.isTemplate = true
                button.image = lockImage
            } else if let fallback = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "GateKeeper")?.withSymbolConfiguration(config) {
                fallback.isTemplate = true
                button.image = fallback
            }
            
            button.toolTip = "GateKeeper - Secure App Locker"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: DashboardView())
    }
    
    @objc public func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    // MARK: - NSPopoverDelegate
    
    public func popoverDidClose(_ notification: Notification) {
        // Notify dashboard to re-lock so next opening requires password again
        NotificationCenter.default.post(name: Notification.Name("GateKeeperPopoverDidClose"), object: nil)
    }
    
    // MARK: - Onboarding & Initial Setup
    
    private func checkFirstLaunchExperience() {
        let authManager = AuthManager.shared
        let hasCompleted = UserDefaults.standard.bool(forKey: "GateKeeperHasCompletedOnboarding")
        
        // Only show onboarding window once on true first launch if passcode is not yet configured
        if !hasCompleted && !authManager.isPasscodeConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.presentOnboardingWindow()
            }
        }
    }
    
    private func presentOnboardingWindow() {
        let onboardingView = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: "GateKeeperHasCompletedOnboarding")
            self?.onboardingWindowController?.close()
            self?.onboardingWindowController = nil
            // Show the popover dashboard after onboarding finishes
            if let button = self?.statusItem.button {
                self?.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to GateKeeper"
        window.contentViewController = NSHostingController(rootView: onboardingView)
        window.isReleasedWhenClosed = false
        
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.onboardingWindowController = controller
    }
}
