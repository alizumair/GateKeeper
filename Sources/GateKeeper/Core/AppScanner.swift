import AppKit
import Foundation
import Combine

/// Scans standard macOS directories to discover installed applications.
public final class AppScanner: ObservableObject {
    public static let shared = AppScanner()
    
    @Published public private(set) var installedApps: [InstalledApp] = []
    @Published public private(set) var isScanning: Bool = false
    
    private let fileManager = FileManager.default
    
    private init() {
        scanApplications()
    }
    
    public func scanApplications() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var discoveredApps: [InstalledApp] = []
            var seenBundleIDs = Set<String>()
            
            let directoriesToScan: [URL] = [
                URL(fileURLWithPath: "/Applications"),
                self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities")
            ]
            
            for directory in directoriesToScan {
                guard self.fileManager.fileExists(atPath: directory.path) else { continue }
                
                let apps = self.scanDirectory(directory, seenBundleIDs: &seenBundleIDs)
                discoveredApps.append(contentsOf: apps)
            }
            
            // Filter out GateKeeper itself
            let currentBundleID = Bundle.main.bundleIdentifier ?? "com.gatekeeper.app"
            discoveredApps.removeAll { $0.bundleIdentifier == currentBundleID }
            
            // Sort alphabetically by name
            discoveredApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.installedApps = discoveredApps
                self.isScanning = false
            }
        }
    }
    
    private func scanDirectory(_ directoryURL: URL, seenBundleIDs: inout Set<String>) -> [InstalledApp] {
        var results: [InstalledApp] = []
        
        let keys: [URLResourceKey] = [.isPackageKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else {
            return results
        }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "app" else { continue }
            
            if let app = extractAppInfo(from: fileURL), !seenBundleIDs.contains(app.bundleIdentifier) {
                seenBundleIDs.insert(app.bundleIdentifier)
                results.append(app)
            }
        }
        
        return results
    }
    
    private func extractAppInfo(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        
        // Extract bundle ID
        guard let bundleID = bundle.bundleIdentifier, !bundleID.isEmpty else {
            return nil
        }
        
        // Extract localized or friendly display name
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        // Version string
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        
        // High-res Icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        
        return InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            url: url,
            icon: icon,
            version: version
        )
    }
}
