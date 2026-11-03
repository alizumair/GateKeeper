import SwiftUI
import AppKit

/// Main popover view displayed when clicking the menu-bar status item.
public struct DashboardView: View {
    @ObservedObject private var monitor = WorkspaceMonitor.shared
    @ObservedObject private var scanner = AppScanner.shared
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared
    @ObservedObject private var recovery = RecoveryManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedFilter: AppFilter = .all
    @State private var showingChangePasscodeSheet: Bool = false
    @State private var showingRecoverySetupSheet: Bool = false
    
    public enum AppFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case locked = "Locked"
        case unlocked = "Unlocked"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    private var filteredApps: [InstalledApp] {
        var list = scanner.installedApps
        
        // Search filter
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Tab filter
        switch selectedFilter {
        case .all:
            return list
        case .locked:
            return list.filter { monitor.isAppLocked($0.bundleIdentifier) }
        case .unlocked:
            return list.filter { !monitor.isAppLocked($0.bundleIdentifier) }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
            
            // Accessibility Warning Banner (if permission missing)
            if !accessibilityManager.isAccessibilityGranted {
                accessibilityWarningBanner
            }
            
            // Search & Filter Bar
            searchAndFilterBar
            
            Divider()
            
            // Applications List
            appListSection
            
            Divider()
            
            // Footer Toolbar
            footerToolbar
        }
        .frame(width: 360, height: 520)
        .sheet(isPresented: $showingChangePasscodeSheet) {
            PasscodeModalView(
                mode: authManager.isPasscodeConfigured ? .changePasscode : .initialSetup
            ) {
                showingChangePasscodeSheet = false
            }
        }
        .sheet(isPresented: $showingRecoverySetupSheet) {
            RecoverySetupView {
                showingRecoverySetupSheet = false
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: monitor.isEngineEnabled ? [Color.blue, Color.purple] : [Color.gray, Color.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: monitor.isEngineEnabled ? "lock.shield.fill" : "lock.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("GateKeeper")
                        .font(.system(size: 14, weight: .bold))
                    
                    Text(monitor.isEngineEnabled ? "Protection Active" : "Protection Paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(monitor.isEngineEnabled ? .green : .secondary)
                }
            }
            
            Spacer()
            
            // Master Engine Toggle
            Toggle("", isOn: $monitor.isEngineEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var accessibilityWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Needed")
                    .font(.system(size: 11, weight: .semibold))
                Text("Required to monitor app switching.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Grant") {
                accessibilityManager.promptForPermission()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search installed apps...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Filter Pills
            HStack(spacing: 6) {
                ForEach(AppFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    let count = countForFilter(filter)
                    
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text("\(filter.rawValue) (\(count))")
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Rescan button
                Button(action: {
                    scanner.scanApplications()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Rescan Applications")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private func countForFilter(_ filter: AppFilter) -> Int {
        switch filter {
        case .all:
            return scanner.installedApps.count
        case .locked:
            return scanner.installedApps.filter { monitor.isAppLocked($0.bundleIdentifier) }.count
        case .unlocked:
            return scanner.installedApps.filter { !monitor.isAppLocked($0.bundleIdentifier) }.count
        }
    }
    
    private var appListSection: some View {
        Group {
            if scanner.isScanning && scanner.installedApps.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning applications...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(searchText.isEmpty ? "No applications found" : "No matching applications")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredApps) { app in
                            AppRowView(
                                app: app,
                                isLocked: monitor.isAppLocked(app.bundleIdentifier),
                                onToggle: {
                                    monitor.toggleAppLock(app.bundleIdentifier)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
    }
    
    private var footerToolbar: some View {
        HStack(spacing: 10) {
            // Passcode Settings Button
            Button(action: {
                showingChangePasscodeSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                    Text(authManager.isPasscodeConfigured ? "Passcode" : "Set Passcode")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // Recovery Button
            Button(action: {
                showingRecoverySetupSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: recovery.isRecoveryConfigured ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 11))
                        .foregroundColor(recovery.isRecoveryConfigured ? .green : .accentColor)
                    Text("Recovery")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // Relock Policy Menu
            Menu {
                ForEach(RelockPolicy.allCases) { policy in
                    Button(action: {
                        monitor.relockPolicy = policy
                    }) {
                        HStack {
                            Text(policy.rawValue)
                            if monitor.relockPolicy == policy {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                    Text("Relock: \(monitor.relockPolicy.rawValue)")
                        .font(.system(size: 10))
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer()
            
            // Quit Button
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Quit GateKeeper")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
