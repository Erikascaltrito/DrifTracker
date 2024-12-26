//
//  DataController.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 21/11/24.
//

import Foundation
import CoreData

/// A controller for managing Core Data operations
/// This class handles the initialization of the Core Data stack and provides an in-memory option for testing or temporary data storage
class DataController: ObservableObject {
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "DrifTrackerModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}

