import AppKit
import Foundation

/// Represents an installed application scanned on the Mac.
public struct InstalledApp: Identifiable, Hashable {
    public var id: String { bundleIdentifier }
    
    public let name: String
    public let bundleIdentifier: String
    public let url: URL
    public let icon: NSImage
    public let version: String?
    
    public init(name: String, bundleIdentifier: String, url: URL, icon: NSImage, version: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.icon = icon
        self.version = version
    }
    
    public static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}
