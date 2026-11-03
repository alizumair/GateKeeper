import SwiftUI

/// Main application entry point for GateKeeper.
@main
struct GateKeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Pure menu-bar utility without default window
        Settings {
            EmptyView()
        }
    }
}
