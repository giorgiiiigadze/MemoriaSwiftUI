import SwiftUI
import UIKit

/// The 4 real tabs from the spec (Home/Friends/Calendar/Profile) plus a center "+" item.
/// "+" isn't a real destination — Create Drop is a modal flow (spec: "modal sheet or
/// full-screen cover"), so its tab selection is intercepted before it ever reaches
/// `TabView`'s state, avoiding a flash of an empty "Create" tab before the sheet appears.
struct MainTabView: View {
    @Environment(AppState.self) private var appState

    private enum Tab: Hashable {
        case home, friends, createDrop, calendar, profile
    }

    @State private var selectedTab: Tab = .home
    @State private var isShowingCreateDrop = false
    /// The Profile tab icon rendered as a `UIImage` — a `.tabItem` can't host an `AsyncImage`
    /// or an arbitrary view. Holds either the fetched circular avatar or, when there's no
    /// photo, the same initials badge used elsewhere (`InitialAvatar`).
    @State private var avatarIcon: UIImage?

    /// Name the initials fallback derives from.
    private var avatarName: String {
        appState.profile?.displayName ?? appState.profile?.username ?? ""
    }

    private var selection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .createDrop {
                    isShowingCreateDrop = true
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(Tab.friends)

            Color.clear
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }
                .tag(Tab.createDrop)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(Tab.calendar)

            ProfileView()
                .tabItem {
                    Label {
                        Text("Profile")
                    } icon: {
                        if let avatarIcon {
                            Image(uiImage: avatarIcon)
                                .renderingMode(.original)
                        } else {
                            Image(systemName: "person.fill")
                        }
                    }
                }
                .tag(Tab.profile)
        }
        .sheet(isPresented: $isShowingCreateDrop) {
            CreateDropView()
        }
        .task(id: [appState.profile?.avatarURL, avatarName]) {
            await loadAvatarIcon()
        }
    }

    private func loadAvatarIcon() async {
        guard
            let urlString = appState.profile?.avatarURL,
            let url = URL(string: urlString)
        else {
            // No photo on file — the initials badge is the final answer, nothing to fetch.
            avatarIcon = initialsIcon(name: avatarName)
            return
        }

        // Instant path: render last-seen bytes from disk so the photo is up before the first frame
        // instead of after a ~2s download. First-ever load has no cache, so show initials meanwhile.
        if let cached = AvatarImageCache.data(for: url), let icon = Self.circularIcon(from: cached) {
            avatarIcon = icon
        } else {
            avatarIcon = initialsIcon(name: avatarName)
        }

        // Refresh from network and re-cache. Overwriting each launch is how a changed photo (same
        // stable `{uid}/avatar.jpg` URL, so same cache key) heals — within one launch.
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            AvatarImageCache.store(data, for: url)
            if let icon = Self.circularIcon(from: data) {
                avatarIcon = icon
            }
        }
    }

    /// Renders `InitialAvatar` into a tab-bar-sized `UIImage`, `.alwaysOriginal` so its own
    /// colours survive instead of being tinted like a template glyph.
    private func initialsIcon(name: String, pointSize: CGFloat = 28) -> UIImage? {
        let renderer = ImageRenderer(content: InitialAvatar(name: name, size: pointSize))
        renderer.scale = UITraitCollection.current.displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }

    /// Decodes `data` and aspect-fills it into a circular, tab-bar-sized image tagged
    /// `.alwaysOriginal` so the tab bar shows the photo instead of a tinted template.
    private static func circularIcon(from data: Data, pointSize: CGFloat = 28) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }

        let target = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: target)).addClip()
            let fill = max(target.width / image.size.width, target.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * fill, height: image.size.height * fill)
            let origin = CGPoint(
                x: (target.width - drawSize.width) / 2,
                y: (target.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
