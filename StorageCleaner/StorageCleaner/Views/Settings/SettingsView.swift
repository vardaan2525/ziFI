import SwiftUI
import Photos

public struct SettingsView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("zifi_color_scheme") private var colorSchemePreference: String = "system"

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // ── App Header ───────────────────────────────────────────
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ziFI")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Version 1.0 • Storage Cleaner")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                        if storage.totalSpaceFreedEver > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteCountFormatter.string(fromByteCount: storage.totalSpaceFreedEver, countStyle: .file))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.accent)
                                Text("cleaned")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Appearance (Exclusive location for Dark / Light mode) ─
                Section("Appearance") {
                    Picker("Mode", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                // ── Permissions ──────────────────────────────────────────
                Section("Permissions") {
                    HStack {
                        Label("Photos", systemImage: "photo")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(photoStatusDescription)
                            .font(.system(size: 12))
                            .foregroundColor(photoStatusColor)
                    }

                    if storage.photoAuthStatus == .denied || storage.photoAuthStatus == .restricted {
                        Button(action: { openAppSettings() }) {
                            Label("Open Settings", systemImage: "arrow.up.right.square")
                                .foregroundColor(AppTheme.accent)
                        }
                    } else if storage.photoAuthStatus == .notDetermined {
                        Button(action: {
                            Task { _ = await storage.requestPhotoPermission() }
                        }) {
                            Label("Grant Photos Access", systemImage: "checkmark.circle")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }

                // ── Widgets ──────────────────────────────────────────────
                Section("Home Screen Widget") {
                    HStack(spacing: 12) {
                        Image(systemName: "square.dashed.inset.filled")
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Storage Status Widget")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Hold Home Screen → Tap + → Select ziFI")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Helpers
    private var photoStatusDescription: String {
        switch storage.photoAuthStatus {
        case .authorized:    return "Full Access"
        case .limited:       return "Limited"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default:    return "Unknown"
        }
    }

    private var photoStatusColor: Color {
        switch storage.photoAuthStatus {
        case .authorized:             return AppTheme.success
        case .limited:                return AppTheme.amberAccent
        case .denied, .restricted:   return AppTheme.destructive
        case .notDetermined:          return AppTheme.textMuted
        @unknown default:             return AppTheme.textMuted
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
