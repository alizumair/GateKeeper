import SwiftUI
import AppKit

/// Individual row view for an application in the dashboard list.
public struct AppRowView: View {
    let app: InstalledApp
    let isLocked: Bool
    let onToggle: () -> Void
    
    public init(app: InstalledApp, isLocked: Bool, onToggle: @escaping () -> Void) {
        self.app = app
        self.isLocked = isLocked
        self.onToggle = onToggle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .cornerRadius(7)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            
            // Name & Bundle Identifier
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(app.bundleIdentifier)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Lock Toggle Switch
            Toggle("", isOn: Binding(
                get: { isLocked },
                set: { _ in onToggle() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isLocked ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
