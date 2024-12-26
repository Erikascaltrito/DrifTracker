//
//  DrifTrackerApp.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 21/11/24.
//

import SwiftUI

/// The entry point of the DriftTracker application
/// Injects the generalManager and Core Data context into the environment to ensure dependency availability across the app
@main
struct DrifTrackerApp: App {
    
    @StateObject private var dataController = DataController()
    @StateObject private var generalManager = GeneralManager()

    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(generalManager)
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
