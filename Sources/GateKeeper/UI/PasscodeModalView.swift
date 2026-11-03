import SwiftUI

/// Modal sheet for setting up or modifying the master passcode.
public struct PasscodeModalView: View {
    public enum Mode {
        case initialSetup
        case changePasscode
    }
    
    let mode: Mode
    let onDismiss: () -> Void
    
    @ObservedObject private var authManager = AuthManager.shared
    
    @State private var currentPasscode: String = ""
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    public init(mode: Mode, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: mode == .initialSetup ? "shield.lefthalf.filled" : "key.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.accentColor)
                
                Text(mode == .initialSetup ? "Set Master Passcode" : "Change Passcode")
                    .font(.system(size: 18, weight: .bold))
                
                Text(mode == .initialSetup
                     ? "Create a secure passcode to unlock protected applications."
                     : "Enter your current passcode and choose a new one.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            
            // Error / Success Banner
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
            } else if let success = successMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(success)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            }
            
            // Input Fields
            VStack(spacing: 12) {
                if mode == .changePasscode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Passcode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureField("Enter current passcode", text: $currentPasscode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .initialSetup ? "Master Passcode" : "New Passcode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    SecureField("At least 4 characters", text: $newPasscode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm Passcode")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    SecureField("Re-enter passcode", text: $confirmPasscode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .frame(width: 260)
            
            // Buttons
            HStack(spacing: 12) {
                if mode == .changePasscode {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                Button(action: savePasscode) {
                    Text(mode == .initialSetup ? "Save Passcode" : "Update Passcode")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320)
    }
    
    private func savePasscode() {
        errorMessage = nil
        
        if mode == .changePasscode {
            guard !currentPasscode.isEmpty else {
                errorMessage = "Please enter your current passcode."
                return
            }
            guard authManager.verifyPasscode(currentPasscode) else {
                errorMessage = "Current passcode is incorrect."
                return
            }
        }
        
        guard newPasscode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 characters."
            return
        }
        
        guard newPasscode == confirmPasscode else {
            errorMessage = "Passcodes do not match."
            return
        }
        
        let success = authManager.setMasterPasscode(newPasscode)
        if success {
            successMessage = "Passcode saved successfully!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onDismiss()
            }
        } else {
            errorMessage = "Failed to store passcode in Keychain."
        }
    }
}
