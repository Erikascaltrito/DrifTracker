//
//  MainView.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 03/12/24.
//

import SwiftUI
import CoreData

/// The main view of the application
/// Provides a TabView-based navigation interface with multiple features accessible via tabs
struct MainView: View {
    var body: some View {
        TabView {
            TrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "steeringwheel.and.hands")
                }

            ReferenceListView()
                .tabItem {
                    Label("References", systemImage: "road.lanes.curved.left")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
            ConsentView()
                .tabItem {
                    Label("Consents", systemImage: "checkmark.shield")
                }

        }
        .onAppear {
            configureTabBarAppearance()
        }
        .background(Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                                .edgesIgnoringSafeArea(.all))
        .toolbarBackground(Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(.orange)
        .ignoresSafeArea()
    }
    
    /// Configures the appearance of the TabBar
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 31/255, green: 48/255, blue: 59/255, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = .lightGray
        UITabBar.appearance().backgroundColor = UIColor(red: 31/255, green: 48/255, blue: 59/255, alpha: 1.0)
    }
}


#Preview {
    MainView()
}
