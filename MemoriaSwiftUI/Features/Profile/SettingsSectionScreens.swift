import SwiftUI
import UserNotifications

// MARK: - Notifications

struct NotificationSettingsView: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isLoading = true

    var body: some View {
        List {
            switch authStatus {
            case .authorized, .provisional, .ephemeral:
                enabledContent
            case .denied:
                deniedContent
            case .notDetermined:
                notDeterminedContent
            @unknown default:
                notDeterminedContent
            }
        }
        .scrollContentBackground(.hidden)
        .background(Colors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
    }

    private var enabledContent: some View {
        Group {
            Section {
                HStack(spacing: Spacing.md) {
                    statusIcon("checkmark.circle.fill", color: Colors.success)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Push notifications are on")
                            .font(Typography.font(.sm, weight: .medium))
                            .foregroundStyle(Colors.textPrimary)
                        Text("You'll get notified when drops open, friends join, and more.")
                            .font(Typography.font(.xsm))
                            .foregroundStyle(Colors.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .listRowBackground(Colors.surfaceGrouped)
            }

            Section {
                settingsSystemLink()
            } header: {
                sectionHeader("Manage")
            }
        }
    }

    private var deniedContent: some View {
        Group {
            Section {
                HStack(spacing: Spacing.md) {
                    statusIcon("bell.slash.fill", color: Colors.crimson)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Notifications are off")
                            .font(Typography.font(.sm, weight: .medium))
                            .foregroundStyle(Colors.textPrimary)
                        Text("Turn them on in Settings so you don't miss when a drop opens.")
                            .font(Typography.font(.xsm))
                            .foregroundStyle(Colors.textSecondary)
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .listRowBackground(Colors.surfaceGrouped)
            }

            Section {
                settingsSystemLink()
            } header: {
                sectionHeader("Fix it")
            }
        }
    }

    private var notDeterminedContent: some View {
        Section {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Colors.textSecondary)
                Text("Stay in the loop")
                    .font(Typography.font(.md, weight: .semiBold))
                    .foregroundStyle(Colors.textPrimary)
                Text("Get notified when drops open, friends upload, or someone joins your drop.")
                    .font(Typography.font(.sm))
                    .foregroundStyle(Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await requestPermission() }
                } label: {
                    Text("Enable notifications")
                        .font(Typography.font(.sm, weight: .semiBold))
                        .foregroundStyle(Colors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Colors.white, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity)
            .listRowBackground(Colors.surfaceGrouped)
        }
    }

    private func statusIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 22))
            .foregroundStyle(color)
    }

    private func settingsSystemLink() -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label {
                Text("Open System Settings")
                    .foregroundStyle(Colors.textPrimary)
            } icon: {
                Image(systemName: "gear")
                    .font(.system(size: 15))
                    .foregroundStyle(Colors.textPrimary)
            }
        }
        .listRowBackground(Colors.surfaceGrouped)
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
        isLoading = false
    }

    private func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refreshStatus()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.font(.md, weight: .strong))
            .foregroundStyle(Colors.textPrimary)
            .textCase(nil)
    }
}

// MARK: - Privacy & Safety

struct PrivacySettingsView: View {
    var body: some View {
        List {
            Section {
                infoRow(
                    icon: "eye.slash.fill",
                    title: "Your photos are sealed",
                    detail: "Nobody sees your photo until the drop opens — not even the creator."
                )
                infoRow(
                    icon: "lock.fill",
                    title: "End-to-end private",
                    detail: "Only drop members can view photos. There's no public feed or discover page."
                )
                infoRow(
                    icon: "person.crop.circle.badge.minus",
                    title: "Leave anytime",
                    detail: "You can leave any drop. Your photos are removed immediately."
                )
            } header: {
                sectionHeader("How Memoria protects you")
            }

            Section {
                comingSoonRow("Blocked users", systemImage: "person.fill.xmark")
                comingSoonRow("Who can invite me", systemImage: "person.badge.shield.checkmark.fill")
            } header: {
                sectionHeader("Controls")
            } footer: {
                Text("These controls are coming in a future update.")
                    .font(Typography.font(.xsm))
                    .foregroundStyle(Colors.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Colors.background)
        .navigationTitle("Privacy & Safety")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Colors.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.font(.sm, weight: .medium))
                    .foregroundStyle(Colors.textPrimary)
                Text(detail)
                    .font(Typography.font(.xsm))
                    .foregroundStyle(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .listRowBackground(Colors.surfaceGrouped)
    }

    private func comingSoonRow(_ title: String, systemImage: String) -> some View {
        Label {
            HStack {
                Text(title)
                    .foregroundStyle(Colors.textPrimary)
                Spacer()
                Text("Soon")
                    .font(Typography.font(.xsm, weight: .medium))
                    .foregroundStyle(Colors.textTertiary)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(Colors.textSecondary)
        }
        .listRowBackground(Colors.surfaceGrouped)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.font(.md, weight: .strong))
            .foregroundStyle(Colors.textPrimary)
            .textCase(nil)
    }
}

// MARK: - Data & Storage

struct DataStorageSettingsView: View {
    @State private var cacheSize: String = "Calculating…"
    @State private var isClearing = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label {
                        Text("Image cache")
                            .foregroundStyle(Colors.textPrimary)
                    } icon: {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Colors.textSecondary)
                    }
                    Spacer()
                    Text(cacheSize)
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.textTertiary)
                }
                .listRowBackground(Colors.surfaceGrouped)

                Button {
                    clearCache()
                } label: {
                    HStack {
                        Label {
                            Text(isClearing ? "Clearing…" : "Clear image cache")
                                .foregroundStyle(isClearing ? Colors.textTertiary : Colors.crimson)
                        } icon: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(isClearing ? Colors.textTertiary : Colors.crimson)
                        }
                        Spacer()
                    }
                }
                .disabled(isClearing)
                .listRowBackground(Colors.surfaceGrouped)
            } header: {
                sectionHeader("Cache")
            } footer: {
                Text("Cached images let photos load instantly. Clearing the cache frees storage but photos will re-download when you view them.")
                    .font(Typography.font(.xsm))
                    .foregroundStyle(Colors.textTertiary)
            }

            Section {
                HStack {
                    Label {
                        Text("Network requests")
                            .foregroundStyle(Colors.textPrimary)
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Colors.textSecondary)
                    }
                    Spacer()
                    Text(urlCacheSize)
                        .font(Typography.font(.sm))
                        .foregroundStyle(Colors.textTertiary)
                }
                .listRowBackground(Colors.surfaceGrouped)
            } header: {
                sectionHeader("System")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Colors.background)
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .task { cacheSize = Self.measureCacheSize() }
    }

    private var urlCacheSize: String {
        let bytes = URLCache.shared.currentDiskUsage
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    nonisolated private static func measureCacheSize() -> String {
        let fm = FileManager.default
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("RemoteImageCache", isDirectory: true)
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 KB"
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func clearCache() {
        isClearing = true
        Task.detached {
            let fm = FileManager.default
            let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let dir = base.appendingPathComponent("RemoteImageCache", isDirectory: true)
            try? fm.removeItem(at: dir)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let newSize = DataStorageSettingsView.measureCacheSize()
            await MainActor.run {
                cacheSize = newSize
                isClearing = false
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.font(.md, weight: .strong))
            .foregroundStyle(Colors.textPrimary)
            .textCase(nil)
    }
}

// MARK: - About

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Colors.textSecondary)
                    Text("Memoria")
                        .font(Typography.font(.xl, weight: .semiBold))
                        .foregroundStyle(Colors.textPrimary)
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(Typography.font(.xsm))
                        .foregroundStyle(Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
                .listRowBackground(Color.clear)
            }

            Section {
                aboutRow("Help & Support", systemImage: "questionmark.circle.fill", url: "mailto:support@memoria.app")
                aboutRow("Rate Memoria", systemImage: "star.fill", url: "https://apps.apple.com/app/id0000000000")
                aboutRow("Follow us", systemImage: "link", url: "https://instagram.com/memoria")
            } header: {
                sectionHeader("Connect")
            }

            Section {
                aboutRow("Privacy Policy", systemImage: "hand.raised.fill", url: "https://memoria.app/privacy")
                aboutRow("Terms of Service", systemImage: "doc.text.fill", url: "https://memoria.app/terms")
            } header: {
                sectionHeader("Legal")
            }

            Section {
                HStack {
                    Text("Made with love in Georgia")
                        .font(Typography.font(.xsm))
                        .foregroundStyle(Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Colors.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func aboutRow(_ title: String, systemImage: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(Colors.textPrimary)
                } icon: {
                    Image(systemName: systemImage)
                        .font(.system(size: 15))
                        .foregroundStyle(Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Colors.textTertiary)
            }
        }
        .listRowBackground(Colors.surfaceGrouped)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.font(.md, weight: .strong))
            .foregroundStyle(Colors.textPrimary)
            .textCase(nil)
    }
}
