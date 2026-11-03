import SwiftUI

/// Onboarding sheet guiding the user through system permissions and security setup.
public struct OnboardingView: View {
    let onComplete: () -> Void
    
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
    @State private var showingPasscodeSetup: Bool = false
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Welcome to GateKeeper")
                    .font(.system(size: 20, weight: .bold))
                
                Text("Secure local app protection for macOS.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Steps Card
            VStack(alignment: .leading, spacing: 16) {
                // Step 1: Accessibility
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: accessibilityManager.isAccessibilityGranted ? "checkmark.circle.fill" : "1.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accessibilityManager.isAccessibilityGranted ? .green : .accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Permission")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text("Required for GateKeeper to reliably detect frontmost applications and intercept locked apps without delay.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if !accessibilityManager.isAccessibilityGranted {
                            Button(action: {
                                accessibilityManager.promptForPermission()
                            }) {
                                HStack(spacing: 4) {
                                    Text("Open System Settings")
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        } else {
                            Text("Permission granted")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Divider()
                
                // Step 2: Master Passcode
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: authManager.isPasscodeConfigured ? "checkmark.circle.fill" : "2.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(authManager.isPasscodeConfigured ? .green : .accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Master Passcode")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text("Set a master passcode stored securely in your macOS Keychain to unlock protected apps.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if !authManager.isPasscodeConfigured {
                            Button("Set Passcode Now") {
                                showingPasscodeSetup = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        } else {
                            Text("Passcode configured")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Completion button
            Button(action: onComplete) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!authManager.isPasscodeConfigured)
        }
        .padding(24)
        .frame(width: 380)
        .sheet(isPresented: $showingPasscodeSetup) {
            PasscodeModalView(mode: .initialSetup) {
                showingPasscodeSetup = false
            }
        }
    }
}
