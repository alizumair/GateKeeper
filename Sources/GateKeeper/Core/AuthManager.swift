import Foundation
import LocalAuthentication
import Combine

/// Central authentication coordinator managing passcode verification and Touch ID / Biometrics.
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    private let keychain = KeychainHelper.shared
    private let passcodeAccountKey = "MasterPasscodeHash"
    private let biometricEnabledKey = "GateKeeperBiometricEnabled"
    
    @Published public private(set) var isPasscodeConfigured: Bool = false
    @Published public var isBiometricsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBiometricsEnabled, forKey: biometricEnabledKey)
        }
    }
    
    private init() {
        self.isBiometricsEnabled = UserDefaults.standard.object(forKey: biometricEnabledKey) as? Bool ?? true
        self.isPasscodeConfigured = hasPasscodeSet()
    }
    
    // MARK: - Passcode Management
    
    public func hasPasscodeSet() -> Bool {
        return keychain.read(key: passcodeAccountKey) != nil
    }
    
    public func setMasterPasscode(_ passcode: String) -> Bool {
        guard !passcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let hash = keychain.hashPasscode(passcode)
        if let data = hash.data(using: .utf8) {
            let success = keychain.save(key: passcodeAccountKey, data: data)
            if success {
                DispatchQueue.main.async {
                    self.isPasscodeConfigured = true
                }
            }
            return success
        }
        return false
    }
    
    public func verifyPasscode(_ passcode: String) -> Bool {
        guard let data = keychain.read(key: passcodeAccountKey),
              let storedHash = String(data: data, encoding: .utf8) else {
            return false
        }
        let inputHash = keychain.hashPasscode(passcode)
        return inputHash == storedHash
    }
    
    public func changePasscode(oldPasscode: String, newPasscode: String) -> Bool {
        if verifyPasscode(oldPasscode) {
            return setMasterPasscode(newPasscode)
        }
        return false
    }
    
    // MARK: - Biometrics (Touch ID / LocalAuthentication)
    
    public var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public var biometryTypeDescription: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if #available(macOS 10.15, *) {
                switch context.biometryType {
                case .touchID:
                    return "Touch ID"
                case .opticID:
                    return "Optic ID"
                case .faceID:
                    return "Face ID"
                case .none:
                    return "Biometrics"
                @unknown default:
                    return "Biometrics"
                }
            }
        }
        return "Touch ID"
    }
    
    public func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, String?) -> Void) {
        guard isBiometricsEnabled && isBiometricsAvailable else {
            completion(false, "Biometrics unavailable or disabled.")
            return
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    let errorMessage = error?.localizedDescription ?? "Authentication failed."
                    completion(false, errorMessage)
                }
            }
        }
    }
}
