//
//  MemoriaSwiftUIApp.swift
//  MemoriaSwiftUI
//
//  Created by giorgi giorgadze on 01/07/2026.
//

import SwiftUI
import UIKit
import TipKit

@main
struct MemoriaSwiftUIApp: App {
    init() {
        Self.configureTabBarAppearance()
        // Enable TipKit so feature hints (e.g. the Drop Detail invite button) can appear.
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }

    /// Forces tab bar icons/labels white in both selected and unselected states.
    /// Only touches per-state colors — no background/blur configuration is set, so the
    /// system's automatic Liquid Glass tab bar material on iOS 26 is left untouched.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.stackedLayoutAppearance.normal.iconColor = .white
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
