import Foundation
import ServiceManagement

/// Manages Launch at Login (auto start on startup) using macOS 13+ SMAppService.
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    private let userDefaultsKey = "GateKeeperLaunchAtLoginEnabled"
    
    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
            applyLaunchAtLogin(enabled: isEnabled)
        }
    }
    
    private init() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            let savedPref = UserDefaults.standard.bool(forKey: userDefaultsKey)
            self.isEnabled = (status == .enabled) || savedPref
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
    }
    
    public func applyLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("LaunchAtLoginManager: Could not update SMAppService: \(error)")
            }
        }
    }
}
