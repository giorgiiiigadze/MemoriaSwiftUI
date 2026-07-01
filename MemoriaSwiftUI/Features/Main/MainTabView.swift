import SwiftUI

/// The 4 real tabs from the spec (Home/Friends/Calendar/Profile) plus a center "+" item.
/// "+" isn't a real destination — Create Drop is a modal flow (spec: "modal sheet or
/// full-screen cover"), so its tab selection is intercepted before it ever reaches
/// `TabView`'s state, avoiding a flash of an empty "Create" tab before the sheet appears.
struct MainTabView: View {
    private enum Tab: Hashable {
        case home, friends, createDrop, calendar, profile
    }

    @State private var selectedTab: Tab = .home
    @State private var isShowingCreateDrop = false

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
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .sheet(isPresented: $isShowingCreateDrop) {
            CreateDropView()
        }
    }
}

#Preview {
    MainTabView()
}
