import SwiftUI
import AppKit

/// Setup sheet for managing recovery methods (Authenticator App, Emergency Key, Email).
public struct RecoverySetupView: View {
    @ObservedObject private var recovery = RecoveryManager.shared
    let onDismiss: () -> Void
    
    @State private var selectedTab: Int = 0
    
    // Authenticator setup state
    @State private var currentSecret: String = ""
    @State private var qrImage: NSImage? = nil
    @State private var verificationCode: String = ""
    @State private var totpErrorMessage: String? = nil
    @State private var totpSuccessMessage: String? = nil
    
    // Recovery key state
    @State private var generatedKey: String = ""
    @State private var keyCopied: Bool = false
    
    // Email state
    @State private var emailInput: String = ""
    @State private var emailSaved: Bool = false
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Security & Recovery")
                        .font(.system(size: 16, weight: .bold))
                    Text("Prevent permanent lockout if you forget your master passcode.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Authenticator (TOTP)").tag(0)
                Text("Emergency Key").tag(1)
                Text("Recovery Email").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            
            // Tab Content
            Group {
                if selectedTab == 0 {
                    authenticatorTab
                } else if selectedTab == 1 {
                    recoveryKeyTab
                } else {
                    emailTab
                }
            }
            .frame(height: 320)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 8)
        }
        .frame(width: 440, height: 420)
        .onAppear {
            initializeSetup()
        }
    }
    
    private func initializeSetup() {
        if !recovery.isTOTPConfigured {
            currentSecret = recovery.generateNewTOTPSecret()
            if let uri = recovery.totpURI(secret: currentSecret) {
                qrImage = recovery.generateQRCode(from: uri.absoluteString)
            }
        }
        generatedKey = recovery.generateEmergencyRecoveryKey()
        emailInput = recovery.recoveryEmail
    }
    
    // MARK: - Authenticator Tab
    
    private var authenticatorTab: some View {
        VStack(spacing: 12) {
            if recovery.isTOTPConfigured {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    
                    Text("Authenticator App is Active")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("You can use any 6-digit code from your authenticator app to regain access if you forget your passcode.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        Button("Reconfigure") {
                            recovery.removeTOTP()
                            initializeSetup()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Remove Authenticator") {
                            recovery.removeTOTP()
                            initializeSetup()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 20) {
                    // QR Code
                    if let img = qrImage {
                        Image(nsImage: img)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    
                    // Instructions & Key
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Scan with Google Authenticator or Apple Passwords.")
                            .font(.system(size: 11, weight: .medium))
                        
                        // Secret Key Box
                        HStack {
                            Text(currentSecret)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(currentSecret, forType: .string)
                            }
                            .controlSize(.mini)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                        
                        // Add to Passwords button
                        if let uri = recovery.totpURI(secret: currentSecret) {
                            Button("Add to Apple Passwords") {
                                NSWorkspace.shared.open(uri)
                            }
                            .controlSize(.small)
                        }
                    }
                }
                
                Divider()
                
                // Verification input
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Enter 6-digit code to verify", text: $verificationCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 180)
                        
                        Button("Verify & Enable") {
                            verifyAndSaveTOTP()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    
                    if let err = totpErrorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func verifyAndSaveTOTP() {
        totpErrorMessage = nil
        if recovery.validateTOTPCode(verificationCode, secret: currentSecret) {
            _ = recovery.saveTOTPSecret(currentSecret)
            totpSuccessMessage = "Authenticator configured successfully!"
        } else {
            totpErrorMessage = "Invalid code. Make sure the time on your device matches."
        }
    }
    
    // MARK: - Recovery Key Tab
    
    private var recoveryKeyTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.viewfinder")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            
            Text("Emergency Recovery Key")
                .font(.system(size: 14, weight: .semibold))
            
            Text("Write this key down or save it in a safe place. It can bypass the lock if you lose both your passcode and authenticator device.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 10) {
                Text(generatedKey)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                
                Button(action: copyRecoveryKey) {
                    HStack(spacing: 4) {
                        Image(systemName: keyCopied ? "checkmark" : "doc.on.doc")
                        Text(keyCopied ? "Copied" : "Copy")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Button("Save & Activate This Key") {
                _ = recovery.saveRecoveryKey(generatedKey)
                keyCopied = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
            if recovery.isRecoveryKeyConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Emergency Key is saved and active.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func copyRecoveryKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedKey, forType: .string)
        keyCopied = true
        _ = recovery.saveRecoveryKey(generatedKey)
    }
    
    // MARK: - Recovery Email Tab
    
    private var emailTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            
            Text("Recovery Email Address")
                .font(.system(size: 14, weight: .semibold))
            
            Text("Associate an emergency email address with GateKeeper to record recovery activity and store emergency verification credentials.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Emergency Contact Email")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g. name@example.com", text: $emailInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 280)
            }
            
            Button(action: {
                recovery.recoveryEmail = emailInput
                emailSaved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    emailSaved = false
                }
            }) {
                HStack(spacing: 4) {
                    if emailSaved {
                        Image(systemName: "checkmark")
                    }
                    Text(emailSaved ? "Saved" : "Save Email")
                }
                .frame(width: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
