import AppKit
import SwiftUI

/// Custom NSPanel allowing keyboard input even with borderless style mask.
final class LockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Controller responsible for presenting and dismissing the full-screen lock overlay window.
public final class LockOverlayController {
    public static let shared = LockOverlayController()
    
    private var overlayPanels: [LockPanel] = []
    private var currentTargetApp: NSRunningApplication?
    private var unlockCompletion: ((Bool) -> Void)?
    
    private init() {}
    
    /// Presents a full-screen, high-priority blocking overlay covering all screens.
    public func presentLockOverlay(for targetApp: NSRunningApplication, completion: @escaping (Bool) -> Void) {
        // Dismiss any existing overlay first
        dismissOverlay(didUnlock: false, shouldHideTarget: false)
        
        self.currentTargetApp = targetApp
        self.unlockCompletion = completion
        
        // Hide target app immediately so confidential content is not visible
        targetApp.hide()
        
        // Create an overlay panel for each connected screen
        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        
        for screen in screens {
            let panel = LockPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            
            let contentView = LockOverlayView(
                app: targetApp,
                onUnlock: { [weak self] in
                    self?.handleUnlockSuccess()
                },
                onCancel: { [weak self] in
                    self?.handleUnlockFailure()
                }
            )
            
            panel.contentView = NSHostingView(rootView: contentView)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            
            overlayPanels.append(panel)
        }
        
        // Make the primary screen's panel key
        if let primaryPanel = overlayPanels.first {
            primaryPanel.makeKey()
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func handleUnlockSuccess() {
        let appToActivate = currentTargetApp
        dismissOverlay(didUnlock: true, shouldHideTarget: false)
        
        // Unhide and restore focus to target app
        if let app = appToActivate {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
    
    private func handleUnlockFailure() {
        let appToHide = currentTargetApp
        dismissOverlay(didUnlock: false, shouldHideTarget: true)
        
        // Ensure target app stays hidden and switch focus away
        appToHide?.hide()
        
        // Switch to Finder or another open app
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            finder.activate(options: [.activateIgnoringOtherApps])
        }
    }
    
    private func dismissOverlay(didUnlock: Bool, shouldHideTarget: Bool) {
        for panel in overlayPanels {
            panel.orderOut(nil)
        }
        overlayPanels.removeAll()
        
        let completion = unlockCompletion
        unlockCompletion = nil
        
        if shouldHideTarget {
            currentTargetApp?.hide()
        }
        currentTargetApp = nil
        
        completion?(didUnlock)
    }
}
