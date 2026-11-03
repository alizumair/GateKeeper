import AppKit
import CoreImage
import CryptoKit
import Foundation

/// Manages recovery options including RFC 6238 TOTP (Authenticator App) and Emergency Recovery Keys.
public final class RecoveryManager: ObservableObject {
    public static let shared = RecoveryManager()
    
    private let keychain = KeychainHelper.shared
    private let totpSecretKey = "GateKeeperTOTPSecret"
    private let recoveryKeyHashKey = "GateKeeperRecoveryKeyHash"
    private let recoveryEmailKey = "GateKeeperRecoveryEmail"
    
    @Published public private(set) var isTOTPConfigured: Bool = false
    @Published public private(set) var isRecoveryKeyConfigured: Bool = false
    @Published public var recoveryEmail: String = "" {
        didSet {
            UserDefaults.standard.set(recoveryEmail, forKey: recoveryEmailKey)
        }
    }
    
    private init() {
        self.isTOTPConfigured = getStoredTOTPSecret() != nil
        self.isRecoveryKeyConfigured = keychain.read(key: recoveryKeyHashKey) != nil
        self.recoveryEmail = UserDefaults.standard.string(forKey: recoveryEmailKey) ?? ""
    }
    
    public var isRecoveryConfigured: Bool {
        return isTOTPConfigured || isRecoveryKeyConfigured
    }
    
    // MARK: - TOTP Authenticator (RFC 6238)
    
    public func getStoredTOTPSecret() -> String? {
        guard let data = keychain.read(key: totpSecretKey),
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }
        return secret
    }
    
    /// Generates a new 160-bit Base32 secret string.
    public func generateNewTOTPSecret() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 20)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return Base32.encode(Data(randomBytes))
    }
    
    /// Saves and enables the TOTP secret in Keychain after verification.
    public func saveTOTPSecret(_ secret: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }
        let success = keychain.save(key: totpSecretKey, data: data)
        if success {
            DispatchQueue.main.async {
                self.isTOTPConfigured = true
            }
        }
        return success
    }
    
    public func removeTOTP() {
        _ = keychain.delete(key: totpSecretKey)
        DispatchQueue.main.async {
            self.isTOTPConfigured = false
        }
    }
    
    /// Generates standard otpauth:// URI for authenticator apps.
    public func totpURI(secret: String, account: String = "Mac Admin") -> URL? {
        let issuer = "GateKeeper"
        let encodedIssuer = issuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? issuer
        let encodedAccount = account.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? account
        let urlString = "otpauth://totp/\(encodedIssuer):\(encodedAccount)?secret=\(secret)&issuer=\(encodedIssuer)&algorithm=SHA1&digits=6&period=30"
        return URL(string: urlString)
    }
    
    /// Validates a 6-digit TOTP code against the current or provided secret, supporting ±1 time period (30s drift).
    public func validateTOTPCode(_ code: String, secret: String? = nil) -> Bool {
        guard let secretToUse = secret ?? getStoredTOTPSecret() else {
            return false
        }
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanCode.count == 6, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: cleanCode)) else {
            return false
        }
        
        let currentTime = Date().timeIntervalSince1970
        let currentCounter = UInt64(currentTime / 30.0)
        
        // Check window: current, -1 period, +1 period
        for drift in [-1, 0, 1] {
            let testCounter = UInt64(Int64(currentCounter) + Int64(drift))
            if let generated = generateTOTP(secret: secretToUse, counter: testCounter), generated == cleanCode {
                return true
            }
        }
        return false
    }
    
    private func generateTOTP(secret: String, counter: UInt64) -> String? {
        guard let keyData = Base32.decode(secret) else { return nil }
        
        var bigCounter = counter.bigEndian
        let counterData = withUnsafeBytes(of: &bigCounter) { Data($0) }
        
        let key = SymmetricKey(data: keyData)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacData = Data(hmac)
        
        guard hmacData.count == 20 else { return nil }
        
        let offset = Int(hmacData[19] & 0x0f)
        let truncated = hmacData.subdata(in: offset..<offset + 4)
        
        var number = truncated.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        number &= 0x7fffffff
        let otp = number % 1_000_000
        
        return String(format: "%06d", otp)
    }
    
    // MARK: - Emergency Recovery Key
    
    /// Generates a human-readable 24-character recovery key (e.g., GK-9F2B-4A1C-8E7D-3C0B).
    public func generateEmergencyRecoveryKey() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        func chunk() -> String {
            return (0..<4).map { _ in String(chars.randomElement()!) }.joined()
        }
        return "GK-\(chunk())-\(chunk())-\(chunk())-\(chunk())"
    }
    
    public func saveRecoveryKey(_ key: String) -> Bool {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let hash = keychain.hashPasscode(cleanKey)
        guard let data = hash.data(using: .utf8) else { return false }
        
        let success = keychain.save(key: recoveryKeyHashKey, data: data)
        if success {
            DispatchQueue.main.async {
                self.isRecoveryKeyConfigured = true
            }
        }
        return success
    }
    
    public func validateRecoveryKey(_ key: String) -> Bool {
        guard let data = keychain.read(key: recoveryKeyHashKey),
              let storedHash = String(data: data, encoding: .utf8) else {
            return false
        }
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let inputHash = keychain.hashPasscode(cleanKey)
        return inputHash == storedHash
    }
    
    public func removeRecoveryKey() {
        _ = keychain.delete(key: recoveryKeyHashKey)
        DispatchQueue.main.async {
            self.isRecoveryKeyConfigured = false
        }
    }
    
    // MARK: - QR Code Generation
    
    public func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputCIImage = filter.outputImage else { return nil }
        
        // Scale up to crisp 200x200 image without blur
        let transform = CGAffineTransform(scaleX: 8.0, y: 8.0)
        let scaledCIImage = outputCIImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaledCIImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

// MARK: - Native Base32 Implementation

public enum Base32 {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    
    public static func encode(_ data: Data) -> String {
        var result = ""
        var buffer: UInt32 = 0
        var bitsLeft = 0
        
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> bitsLeft) & 0x1f)
                let charIndex = alphabet.index(alphabet.startIndex, offsetBy: index)
                result.append(alphabet[charIndex])
            }
        }
        
        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1f)
            let charIndex = alphabet.index(alphabet.startIndex, offsetBy: index)
            result.append(alphabet[charIndex])
        }
        
        return result
    }
    
    public static func decode(_ string: String) -> Data? {
        var cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        cleanString.removeAll { $0 == "=" || $0 == "-" || $0 == " " }
        
        var data = Data()
        var buffer: UInt32 = 0
        var bitsLeft = 0
        
        for char in cleanString {
            guard let index = alphabet.firstIndex(of: char) else {
                return nil
            }
            let val = UInt32(alphabet.distance(from: alphabet.startIndex, to: index))
            buffer = (buffer << 5) | val
            bitsLeft += 5
            
            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xff)
                data.append(byte)
            }
        }
        
        return data
    }
}
