//
//  HealthManager.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 01/12/24.
//

import CoreData
import Foundation
import HealthKit
import Combine

/// `HealthManager` is responsible for managing HealthKit data, in particular HRV (Heart Rate Variability) data.
class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore() // HealthKit store for accessing health data
    @Published var hrvData: [(timestamp: Date, hrv: Double)] = [] // Published property to store fetched HRV data
    
    init() {
        requestAuthorization()  // Request authorization to access HealthKit data when the manager is initialized
    }
    
    // MARK: - Request Authorization
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available on this device.")
            return
        }
        
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let typesToRead: Set = [hrvType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fetch HRV Data
    /// Fetches HRV data for a specific time range from HealthKit.
    /// - Parameters:
    ///   - startDate: Start date of the data range.
    ///   - endDate: End date of the data range.
    ///   - completion: Completion handler that returns the fetched HRV data or an error.
    func fetchHRVData(for startDate: Date, to endDate: Date, completion: @escaping (Result<[(timestamp: Date, value: Double)], Error>) -> Void) {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else {
                completion(.success([]))
                return
            }
            
            let hrvData = samples.map { sample -> (timestamp: Date, value: Double) in
                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                return (timestamp: sample.startDate, value: value)
            }
            
            completion(.success(hrvData))
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Save HRV Data to Core Data
    /// Saves HRV data to Core Data for a specific session.
    /// - Parameters:
    ///   - hrvData: Array of HRV data containing timestamps and values.
    ///   - session: Drift session to associate the HRV data with.
    ///   - context: Core Data managed object context for saving the data.
    func saveHRVDataToCoreData(hrvData: [(timestamp: Date, hrv: Double)], for session: DriftSession, context: NSManagedObjectContext) {
        for data in hrvData {
            let entry = StressEntry(context: context)
            entry.timestamp = data.timestamp
            entry.hrv = data.hrv
            entry.driftSession = session
        }
        
        do {
            try context.save()
            print("HRV data saved successfully!")
        } catch {
            print("Error saving HRV data: \(error.localizedDescription)")
        }
    }
}
