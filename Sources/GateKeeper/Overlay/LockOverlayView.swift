import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// SwiftUI View presented within the Lock Overlay Panel.
public struct LockOverlayView: View {
    let app: NSRunningApplication
    let onUnlock: () -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var recovery = RecoveryManager.shared
    
    @State private var passcode: String = ""
    @State private var errorMessage: String? = nil
    @State private var isShaking: Bool = false
    @State private var isAuthenticatingBiometrics: Bool = false
    @State private var showingRecovery: Bool = false
    
    public init(app: NSRunningApplication, onUnlock: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.app = app
        self.onUnlock = onUnlock
        self.onCancel = onCancel
    }
    
    private var appName: String {
        app.localizedName ?? "Application"
    }
    
    private var appIcon: NSImage {
        if let icon = app.icon {
            return icon
        }
        if let bundleURL = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
        if #available(macOS 12.0, *), let appType = UTType("com.apple.application-bundle") {
            return NSWorkspace.shared.icon(for: appType)
        }
        return NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
    }
    
    public var body: some View {
        ZStack {
            // Background Frosted Glass Blur
            VisualEffectBlur(material: .fullScreenUI, blendingMode: .withinWindow)
                .edgesIgnoringSafeArea(.all)
                .overlay(Color.black.opacity(0.35))
            
            if showingRecovery {
                RecoveryUnlockView(
                    onUnlock: onUnlock,
                    onCancel: {
                        withAnimation {
                            showingRecovery = false
                        }
                    }
                )
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            } else {
                // Central Auth Card
                VStack(spacing: 24) {
                // App Icon with glowing lock badge
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
                    
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.blue.opacity(0.6), radius: 6, x: 0, y: 2)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: 4)
                }
                
                // Titles
                VStack(spacing: 6) {
                    Text(appName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("This application is protected by GateKeeper.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                // Error message
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Passcode Entry
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 20)
                        
                        SecureField("Enter master passcode", text: $passcode)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .onSubmit {
                                handlePasscodeSubmit()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(errorMessage != nil ? Color.red.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 1.5)
                            )
                    )
                    .offset(x: isShaking ? -10 : 0)
                    .animation(isShaking ? Animation.default.repeatCount(4, autoreverses: true).speed(4) : .default, value: isShaking)
                    
                    // Buttons: Touch ID & Unlock
                    HStack(spacing: 12) {
                        if authManager.isBiometricsEnabled && authManager.isBiometricsAvailable {
                            Button(action: triggerBiometrics) {
                                HStack(spacing: 6) {
                                    Image(systemName: "touchid")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(authManager.biometryTypeDescription)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.15))
                                )
                                .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: handlePasscodeSubmit) {
                            HStack(spacing: 6) {
                                Text("Unlock")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(width: 320)
                
                // Cancel / Lock Action
                VStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel and Hide App")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.5))
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    if recovery.isRecoveryConfigured {
                        Button(action: {
                            withAnimation {
                                showingRecovery = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "key.viewfinder")
                                Text("Forgot Passcode? Use Recovery")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.cyan.opacity(0.85))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            )
            }
        }
    }
    
    private func handlePasscodeSubmit() {
        guard !passcode.isEmpty else { return }
        
        if authManager.verifyPasscode(passcode) {
            errorMessage = nil
            onUnlock()
        } else {
            errorMessage = "Incorrect passcode. Please try again."
            isShaking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isShaking = false
            }
        }
    }
    
    private func triggerBiometrics() {
        guard !isAuthenticatingBiometrics else { return }
        isAuthenticatingBiometrics = true
        
        let reason = "unlock \(appName)"
        authManager.authenticateWithBiometrics(reason: reason) { success, error in
            isAuthenticatingBiometrics = false
            if success {
                onUnlock()
            } else if let error = error, !error.contains("canceled") && !error.contains("cancelled") {
                errorMessage = error
            }
        }
    }
}

/// AppKit NSVisualEffectView wrapper for SwiftUI.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
