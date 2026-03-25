import SwiftUI

struct SettingsView: View {
    let credentials: Credentials
    let onLogout: () -> Void

    @ObservedObject private var cacheService = CacheService.shared
    @State private var showLogoutConfirmation = false
    @State private var showClearCacheConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var keyIdPrefix: String {
        let id = credentials.accessKeyId
        return id.count > 8 ? String(id.prefix(8)) + "..." : id
    }

    var body: some View {
        List {
            accountSection
            cacheSection
            dangerSection
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Clear Cache?",
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                cacheService.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached thumbnails.")
        }
        .confirmationDialog(
            "Logout?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Logout", role: .destructive) {
                dismiss()
                onLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your credentials and cached thumbnails will be deleted from this device.")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Access Key ID", value: keyIdPrefix)
            LabeledContent("Region", value: credentials.region)
        }
    }

    private var cacheSection: some View {
        Section("Thumbnail Cache") {
            LabeledContent("Disk Usage") {
                Text(formattedUsage)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Max Cache Size: \(cacheService.maxDiskSizeMB) MB")
                    .font(.body)
                Slider(
                    value: Binding(
                        get: { Double(cacheService.maxDiskSizeMB) },
                        set: { cacheService.maxDiskSizeMB = Int($0) }
                    ),
                    in: 50...2000,
                    step: 50
                )
                .accessibilityLabel("Max cache size in megabytes")
            }

            Button("Clear Cache") {
                showClearCacheConfirmation = true
            }
            .foregroundStyle(.red)
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Logout", role: .destructive) {
                showLogoutConfirmation = true
            }
        }
    }

    private var formattedUsage: String {
        let used = ByteCountFormatter.string(
            fromByteCount: cacheService.diskUsageBytes,
            countStyle: .file
        )
        let max = "\(cacheService.maxDiskSizeMB) MB"
        return "\(used) / \(max)"
    }
}
