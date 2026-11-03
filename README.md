<p align="center">
  <img src="Resources/AppIcon_1024.png" width="128" height="128" alt="GateKeeper Icon" />
</p>

<h1 align="center">GateKeeper</h1>

<p align="center">
  <strong>Production-ready, secure, native macOS menu-bar App Locker built with Swift, SwiftUI, and AppKit.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue.svg" alt="Platform: macOS 13+" />
  <img src="https://img.shields.io/badge/Language-Swift%205.9%2B-orange.svg" alt="Language: Swift" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple.svg" alt="UI: SwiftUI + AppKit" />
  <img src="https://img.shields.io/badge/Security-Keychain%20%2B%20Touch%20ID-green.svg" alt="Security: Keychain + Touch ID" />
  <img src="https://img.shields.io/badge/Recovery-TOTP%20%2B%20Emergency%20Key-teal.svg" alt="Recovery: TOTP + Emergency Key" />
  <img src="https://img.shields.io/badge/Dependencies-Zero%20(Pure%20Native)-lightgrey.svg" alt="Zero Dependencies" />
</p>

---

## 🔒 Overview

**GateKeeper** is an open-source, local macOS security utility that locks applications behind biometric verification (Touch ID) or a master passcode. When a locked app is launched or brought into the foreground, GateKeeper instantly intercepts it with a high-priority frosted-glass lock screen, hiding sensitive contents and preventing unauthorized access.

Crafted with **100% native Apple frameworks** (`AppKit`, `SwiftUI`, `LocalAuthentication`, `Security`, `CryptoKit`, `CoreImage`, and `ServiceManagement`), GateKeeper requires zero third-party dependencies, sends zero analytics, and operates completely offline on your Mac.

---

## ✨ Key Features

### 1. Menu Bar Popover & In-App Security Gate
- **Menu Bar Utility (`LSUIElement = true`):** Runs purely in the macOS status bar with no Dock clutter.
- **In-Popover Password Gate:** When opening GateKeeper from the menu bar, it prompts for authentication right inside the popover before revealing protected apps, toggles, or settings.
- **Auto-Relock on Close:** The dashboard automatically locks back down as soon as the popover closes.
- **Manual Dashboard Lock:** One-click lock icon in the popover header to lock settings immediately.
- **Live Search & Quick Filters:** Search through installed apps by name or bundle identifier; filter by *All*, *Locked*, or *Unlocked*.

### 2. Real-Time Workspace Interception Engine
- **Active Workspace Monitoring:** Observes `NSWorkspace.didActivateApplicationNotification`, `didLaunchApplicationNotification`, and `didDeactivateApplicationNotification`.
- **Instant Suppress & Hide:** Suppresses the target app (`app.hide()`) immediately upon activation so confidential content never flashes on screen.
- **Configurable Relocking Policies:**
  - *Immediately on switch* (locks whenever switching away from the app)
  - *After 1 minute*, *5 minutes*, or *15 minutes* of inactivity.

### 3. Full-Screen Frosted Glass Overlay
- **Topmost Priority:** `NSPanel` at `.screenSaver` window level covering all connected displays (`canBecomeKey = true`, `fullScreenAuxiliary`).
- **Native Frosted Glass:** `NSVisualEffectView` with `.fullScreenUI` material.
- **On-Demand Biometrics:** Prompts Touch ID only on demand or when clicked, keeping the lock screen clean and avoiding double dialogs.
- **Cancel & Push to Background:** Cancelling or failing verification immediately hides the target app and restores focus to Finder.

### 4. Offline Recovery System (Never Get Locked Out)
- **Authenticator App Support (RFC 6238 TOTP):**
  - Compatible with Google Authenticator, Apple Passwords / iCloud Keychain, 1Password, Microsoft Authenticator, and Authy.
  - Generates crisp native QR codes directly on-device using `CIQRCodeGenerator` (`CoreImage`).
  - Single-click **"Add to Apple Passwords"** (`otpauth://`) integration.
- **Emergency Recovery Key:**
  - Generates a FileVault-style 24-character master recovery key (`GK-XXXX-XXXX-XXXX-XXXX`).
  - Hashed and stored securely in macOS Keychain.
- **Emergency Recovery Email:**
  - Store an emergency contact email for security verification and record keeping.
- **Lock Screen Recovery:**
  - A *"Forgot Passcode? Use Recovery"* option right on the lock overlay validates your 6-digit TOTP code or Emergency Key and lets you reset your master passcode on the spot.

### 5. Launch at Login (Auto Start on Startup)
- Native macOS 13+ background service management via `SMAppService.mainApp.register()`.
- Toggle on/off anytime from the popover **Settings** menu.

---

## 🏗️ Architecture & Project Structure

```
GateKeeper/
├── GateKeeper.xcodeproj/               # Native Xcode project
├── Package.swift                       # Swift Package Manager manifest
├── build.sh                            # Automated build, signing & install script
├── Resources/
│   ├── AppIcon.icns                    # Multi-resolution macOS icon
│   ├── AppIcon_1024.png                # 1024×1024 Master icon
│   ├── Assets.xcassets/                # Xcode Asset Catalog (16x16 through 1024x1024)
│   ├── Info.plist                      # Agent app bundle config (LSUIElement = true)
│   └── GateKeeper.entitlements         # Runtime entitlements
└── Sources/
    └── GateKeeper/
        ├── App/
        │   ├── GateKeeperApp.swift              # @main SwiftUI entry point
        │   └── AppDelegate.swift                # StatusItem & Popover lifecycle
        ├── Core/
        │   ├── WorkspaceMonitor.swift           # Real-time NSWorkspace interceptor
        │   ├── AuthManager.swift                # Touch ID & Passcode coordinator
        │   ├── KeychainHelper.swift             # Keychain wrapper & salted SHA-256
        │   ├── RecoveryManager.swift            # RFC 6238 TOTP, QR codes & Emergency Keys
        │   ├── LaunchAtLoginManager.swift       # SMAppService auto-start on boot
        │   ├── AppScanner.swift                 # Discovers applications in /Applications
        │   └── AccessibilityManager.swift       # AXIsProcessTrusted() monitoring
        ├── Models/
        │   └── InstalledApp.swift               # Installed application data model
        ├── Overlay/
        │   ├── LockOverlayController.swift      # Full-screen .screenSaver NSPanel presenter
        │   └── LockOverlayView.swift            # Frosted-glass lock screen & Touch ID UI
        └── UI/
            ├── DashboardView.swift              # Popover dashboard & password gate
            ├── PasscodeModalView.swift          # Set / Change passcode sheet
            ├── RecoverySetupView.swift          # Configure Authenticator & Emergency Key
            ├── RecoveryUnlockView.swift         # Lock screen account recovery flow
            ├── OnboardingView.swift             # First-launch setup guide
            └── Components/
                └── AppRowView.swift             # Application row item with lock toggle
```

---

## 🚀 Building & Installing

### Automatic Build & Install to `/Applications`
Run the build script from the repository root:
```bash
./build.sh
```
This compiles a release binary, codesigns it with entitlements, sets correct permissions, and automatically installs it to `/Applications/GateKeeper.app`.

### Open the Application
```bash
open /Applications/GateKeeper.app
```
*(Or press `Cmd + Space`, search for **GateKeeper**, and hit Enter).*

### Xcode
Double-click `GateKeeper.xcodeproj` to open the project in Xcode, select the **GateKeeper** scheme, and press **Cmd + R**.

### Swift Package Manager
```bash
swift build -c release
```

---

## ⚙️ Requirements

- **macOS:** macOS 13.0 (Ventura) or later (Sonoma, Sequoia, etc.)
- **Hardware:** Apple Silicon (M1/M2/M3/M4) or Intel Mac
- **Developer Tools:** Swift 5.9+ / Xcode 15+

---

## 🛡️ License

MIT License. Designed and crafted for native macOS privacy and security.
