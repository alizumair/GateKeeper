import SwiftUI

/// Modal presented on the lock overlay allowing recovery via Authenticator (TOTP) or Emergency Key.
public struct RecoveryUnlockView: View {
    let onUnlock: () -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var recovery = RecoveryManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
    @State private var inputCodeOrKey: String = ""
    @State private var errorMessage: String? = nil
    @State private var isVerified: Bool = false
    
    // New passcode state (after recovery verification)
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    
    public init(onUnlock: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onUnlock = onUnlock
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            if !isVerified {
                verificationStep
            } else {
                resetPasscodeStep
            }
        }
        .padding(32)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 10)
        )
    }
    
    // MARK: - Step 1: Verification
    
    private var verificationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 38))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("Account Recovery")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Enter your 6-digit Authenticator code or Emergency Recovery Key.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            TextField("Code or GK-XXXX-XXXX-XXXX", text: $inputCodeOrKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.center)
                .onSubmit {
                    verifyRecovery()
                }
            
            HStack(spacing: 12) {
                Button("Back") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Verify") {
                    verifyRecovery()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private func verifyRecovery() {
        errorMessage = nil
        let clean = inputCodeOrKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check TOTP 6-digit code
        if clean.count == 6 && recovery.validateTOTPCode(clean) {
            withAnimation { isVerified = true }
            return
        }
        
        // 2. Check Emergency Recovery Key
        if clean.uppercased().starts(with: "GK-") && recovery.validateRecoveryKey(clean) {
            withAnimation { isVerified = true }
            return
        }
        
        errorMessage = "Invalid Authenticator code or Emergency Recovery Key."
    }
    
    // MARK: - Step 2: Reset Passcode
    
    private var resetPasscodeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 38))
                .foregroundColor(.green)
            
            VStack(spacing: 4) {
                Text("Identity Verified")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Please set a new master passcode to continue.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 10) {
                SecureField("New Passcode", text: $newPasscode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Confirm New Passcode", text: $confirmPasscode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button("Save Passcode & Unlock") {
                saveNewPasscodeAndUnlock()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }
    
    private func saveNewPasscodeAndUnlock() {
        guard newPasscode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 characters."
            return
        }
        guard newPasscode == confirmPasscode else {
            errorMessage = "Passcodes do not match."
            return
        }
        
        if authManager.setMasterPasscode(newPasscode) {
            onUnlock()
        } else {
            errorMessage = "Failed to update passcode."
        }
    }
}
