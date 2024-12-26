//
//  GeneralManager.swift
//  DriftTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 21/11/24.
//

import Foundation
import CoreLocation
import CoreMotion
import CoreData
import SwiftUI
import MapKit

/// The GeneralManager acts as the central controller:  based on Apple’s CoreLocation and CoreMotion frameworks,
/// handles GPS and gyroscope data, recording sessions and telemetry data, and
/// computing drift and performance metrics in real time. It stores session data in Core Data
/// and incorporates a Kalman filter to enhance motion data accuracy,
class GeneralManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    private var locationManager = CLLocationManager()
    private var motionManager = CMMotionManager()
    private var gpsUpdateTimer: Timer?
    private var kalmanFilter = SimpleKalmanFilter(initialEstimate: 0.0, initialUncertainty: 1.0, measurementNoise: 0.1, processNoise: 0.01)
    
    private var referenceEntries: [ReferenceEntryData] = []
    private var isRecordingReference = false
    private var isRecordingDrift = false
    private var currentDriftSession: DriftSession?
    private var angleOffset: Double = 0.0
    
    @Published var angle: Double = 0.0  // Angle to show in the tracker view
    @Published var speedInKmh: Double = 0.0
    @Published var angleDifference: Double = 0.0
    @Published var angle_auto: Double = 0.0
    @Published var currentLocation: CLLocation? = nil
    @Published var polylineCoordinates: [CLLocationCoordinate2D] = []
    
    var context: NSManagedObjectContext? // Core Data Context
    
    // Struct for reference sample data
    struct ReferenceEntryData {
        let latitude: Double
        let longitude: Double
        let angle: Double
    }

    /// Initialization:  configure the location and motion managers
    override init() {
        super.init()
        configureLocationManager()
        configureMotionManager()
    }

    /// Configuration for the location manager
    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestWhenInUseAuthorization()
    }

    /// Configuration for motion manager (gyroscope)
    private func configureMotionManager() {
        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion else { return }
            let gyroRate = motion.rotationRate.z * 180 / .pi
            self?.kalmanFilter.predict(rate: gyroRate, dt: 0.01)
        }
    }
    
    // MARK: Reference Management

    /// Starts recording a new reference session and initializes it in Core Data
    func startReferenceRecording() {
        isRecordingReference = true
        referenceEntries = []
        angle = 0.0
        guard let context = context else { return }
        let referenceSession = ReferenceSession(context: context)
        
        if let location = locationManager.location {
            getLocationName(from: location) { locationName in
                referenceSession.location = locationName
            }
        }
        
        referenceSession.startTime = Date()
        referenceSession.name = "Reference Session \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"

        // When a new reference is registered, it becomes the new active one by default
        setActiveReferenceSession(referenceSession: referenceSession)

        do {
            try context.save()
        } catch {
            print("Error saving ReferenceSession: \(error.localizedDescription)")
        }

        startRecordingUpdates()
    }
    
    /// Stops the currently active reference recording and saves the session to Core Data
    func stopReferenceRecording() {
        isRecordingReference = false
        stopRecordingUpdates()
        angle = 0.0
        DispatchQueue.main.async {
            self.polylineCoordinates = self.polylineCoordinates
        }
        guard let context = context else { return }

        let fetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            if let currentSession = try context.fetch(fetchRequest).first {
                currentSession.endTime = Date()
                try context.save()
            } else {
                print("No active reference session found.")
            }
        } catch {
            print("Error stopping ReferenceSession: \(error.localizedDescription)")
        }
    }

    /// Saves a single reference entry to Core Data, associating it with the currently active reference session
    /// - Parameters:
    ///   - latitude: The latitude of the reference entry as a `Double`
    ///   - longitude: The longitude of the reference entry as a `Double`
    ///   - angle: The gyro Z-axis angle (in degrees) of the reference entry as a `Double`
    private func saveReferenceEntry(latitude: Double, longitude: Double, angle: Double) {
        guard let context = context else { return }

        // Recupera l'ultima sessione di riferimento attiva
        let sessionFetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
        sessionFetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        sessionFetchRequest.fetchLimit = 1

        do {
            if let currentSession = try context.fetch(sessionFetchRequest).first {
                let referenceEntry = ReferenceEntry(context: context)
                referenceEntry.latitude = latitude
                referenceEntry.longitude = longitude
                referenceEntry.gyroZ = angle
                referenceEntry.timestamp = Date()
                referenceEntry.referenceSession = currentSession

                try context.save()
            } else {
                print("No active reference session found to save entry.")
            }
        } catch {
            print("Error saving ReferenceEntry: \(error.localizedDescription)")
        }
    }
    
    /// Loads the entries associated with the currently active reference session from Core Data into memory
    func loadActiveReferenceEntries() {
        guard let context = context else {
            print("Error: Core Data context is nil")
            return
        }

        let sessionFetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
        sessionFetchRequest.predicate = NSPredicate(format: "isActive == true")
        sessionFetchRequest.fetchLimit = 1

        do {
            if let activeReferenceSession = try context.fetch(sessionFetchRequest).first {
                if let entries = activeReferenceSession.referenceEntries as? Set<ReferenceEntry>, !entries.isEmpty {
                    self.referenceEntries = entries.map {
                        ReferenceEntryData(latitude: $0.latitude, longitude: $0.longitude, angle: $0.gyroZ)
                    }
                } else {
                    self.referenceEntries = []
                }
            } else {
                self.referenceEntries = []
            }
        } catch {
            print("Error loading active reference session: \(error.localizedDescription)")
        }
    }

    /// Loads the coordinates from the currently active reference session into memory for polyline visualization in the map
    func loadActiveReferenceCoordinates() {
        guard let context = context else {
            print("Error: Core Data context is nil.")
            return
        }

        let fetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == true")
        fetchRequest.fetchLimit = 1

        do {
            if let activeSession = try context.fetch(fetchRequest).first {
                if let entries = activeSession.referenceEntries as? Set<ReferenceEntry>, !entries.isEmpty {
                    DispatchQueue.main.async {
                        let sortedEntries = entries.sorted { (a, b) in
                            guard let dateA = a.timestamp, let dateB = b.timestamp else {
                                // Se uno dei due timestamp è nil, decidi come gestirlo.
                                // Ad esempio, puoi metterli in fondo all'ordinamento restituendo 'false'
                                return false
                            }
                            return dateA < dateB
                        }
                        self.polylineCoordinates = sortedEntries.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                    }
                } else {
                    print("No entries found in the active reference session.")
                    self.polylineCoordinates = []
                }
            } else {
                print("No active reference session found.")
                self.polylineCoordinates = []
            }
        } catch {
            print("Error loading active reference coordinates: \(error.localizedDescription)")
        }
    }

    /// Sets a given reference session as the active session in Core Data.
    /// - Parameter referenceSession: The `ReferenceSession` object to be marked as active
    func setActiveReferenceSession (referenceSession: ReferenceSession) {
        
        // First disables the current active session (if any) using `disableActualReferenceSession`
        disableActualReferenceSession()

        guard let context = context else {
            print("Error: Core Data context is nil")
            return
        }
        
        referenceSession.isActive = true
        
        do {
            try context.save()
            print("La sessione \(referenceSession.name ?? "") è ora attiva.")
            loadActiveReferenceEntries()

        } catch {
            print("Errore durante il salvataggio della sessione attiva: \(error.localizedDescription)")
        }
    }

    /// Disables the currently active reference session in Core Data
    func disableActualReferenceSession() {
        guard let context = context else {
            print("Error: Core Data context is nil")
            return
        }

        // Fetch the active reference session from Core Data
        let fetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == true")
        fetchRequest.fetchLimit = 1
        
        do {
            // Disable the current reference session
            if let activeSession = try context.fetch(fetchRequest).first {
                activeSession.isActive = false
                try context.save()
                print("La sessione di riferimento attiva è stata disabilitata.")
                referenceEntries = []
            } else {
                print("Nessuna sessione di riferimento attiva trovata.")
            }
        } catch {
            print("Errore durante il fetch o il salvataggio: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Drift Session
    /// Starts recording a drift session by initializing the necessary data and state
    /// - Parameter driftSession: The `DriftSession` object that represents the session being recorded
    func startDriftRecording(driftSession: DriftSession) {
        guard let context = context else {
            print("Error: Core Data context is nil.")
            return
        }
        self.currentDriftSession = driftSession
        self.isRecordingDrift = true

        loadActiveReferenceEntries()

        if referenceEntries.isEmpty {
            print("No reference entries available for drift calculation.")
        } else {
            print("Reference entries loaded for drift calculation.")
        }

        if let currentLoc = locationManager.location {
            let currentAngle = kalmanFilter.getState()
            if let nearestRef = findNearestReferenceEntry(latitude: currentLoc.coordinate.latitude, longitude: currentLoc.coordinate.longitude) {
                angleOffset = currentAngle - nearestRef.angle
            } else {
                angleOffset = 0.0
            }
        } else {
            angleOffset = 0.0
        }

        startRecordingUpdates()
    }
    
    /// Stops the current drift session and resets all relevant state and data
    func stopDriftRecording() {
        isRecordingDrift = false
        stopRecordingUpdates()
        angleDifference = 0.0
        angle_auto = 0.0
        speedInKmh = 0.0
        angle = 0.0
    }
    
    /// Saves a single drift  entry to Core Data
    /// - Parameters:
    ///   - latitude: The latitude of the drift entry
    ///   - longitude: The longitude of the drift  entry
    ///   - angle: The gyro Z-axis angle (in degrees) of the drift  entry
    ///   - speed: The speed of the drift entry
    private func saveDriftEntry(latitude: Double, longitude: Double, angle: Double, speed: Double) {
        guard let context = context, let currentDriftSession = currentDriftSession else {
            print("Error: Context or Current Drift Session is nil.")
            return
        }

        let driftEntry = DriftEntry(context: context)
        driftEntry.latitude = latitude
        driftEntry.longitude = longitude
        driftEntry.gyroZ = angle
        driftEntry.speed = speed
        driftEntry.timestamp = Date()
        driftEntry.driftSession = currentDriftSession

        do {
            try context.save()
        } catch {
            print("Error saving Drift Entry: \(error.localizedDescription)")
        }
    }
    
    /// Calculates the angular difference between the current position and the nearest reference entry
    /// - Parameters:
    ///   - currentLatitude: The latitude of the current position
    ///   - currentLongitude: The longitude of the current position
    ///   - angle: The current gyro angle (in degrees) of the car
    private func calculateAngleDifference(currentLatitude: Double, currentLongitude: Double, angle: Double) -> Double? {
        guard let nearestReference = findNearestReferenceEntry(latitude: currentLatitude, longitude: currentLongitude) else {
            return nil
        }
        let correctedAngle = angle - angleOffset
        let difference = correctedAngle - nearestReference.angle
        print("Angle Difference: \(difference) (Current: \(correctedAngle), Reference: \(nearestReference.angle), Offset: \(angleOffset))")
        return difference
    }
    
    /// Finds the nearest reference entry to the specified latitude and longitude.
    /// - Parameters:
    ///   - latitude: The latitude of the current position.
    ///   - longitude: The longitude of the current position.
    func findNearestReferenceEntry(latitude: Double, longitude: Double) -> ReferenceEntryData? {
        print("Available reference entries: \(referenceEntries.count)")

        guard let nearest = referenceEntries.min(by: {
            haversineDistance(lat1: $0.latitude, lon1: $0.longitude, lat2: latitude, lon2: longitude) <
            haversineDistance(lat1: $1.latitude, lon1: $1.longitude, lat2: latitude, lon2: longitude)
        }) else {
            print("No nearest reference found")
            return nil
        }

        print("Nearest reference found: (\(nearest.latitude), \(nearest.longitude), \(nearest.angle))")
        return nearest
    }

    /// Determines if the current location is too far from the nearest reference entry.
    func isTooFarFromReference() -> Bool {
        guard let currentLocation = currentLocation else {
            print("Current location is not available.")
            return true // If the current position is not available, it could be considered as "too far"
        }

        let currentLatitude = currentLocation.coordinate.latitude
        let currentLongitude = currentLocation.coordinate.longitude
        
        loadActiveReferenceEntries()
        print("Checking distance from references...")
        print("Current location: (\(currentLatitude), \(currentLongitude))")
        print("Available reference entries: \(referenceEntries.count)")

        // Find the nearest reference entries
        guard let nearest = referenceEntries.min(by: {
            haversineDistance(lat1: $0.latitude, lon1: $0.longitude, lat2: currentLatitude, lon2: currentLongitude) <
            haversineDistance(lat1: $1.latitude, lon1: $1.longitude, lat2: currentLatitude, lon2: currentLongitude)
        }) else {
            print("No nearest reference found.")
            return true // There are no reference - too far
        }

        // Compute the distance
        let distance = haversineDistance(lat1: nearest.latitude, lon1: nearest.longitude, lat2: currentLatitude, lon2: currentLongitude)
        print("Nearest reference distance: \(distance) meters")
        
        if distance > 50 {
            print("Too far: \(distance) meters")
            return true
        } else {
            print("Within range: \(distance) meters")
            return false
        }
    }

    // MARK: - Updates
    /// Starts periodic updates for recording GPS and motion data
    private func startRecordingUpdates() {
        gpsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordUpdate()
        }
    }

    /// Stops the periodic updates for recording GPS and motion data
    private func stopRecordingUpdates() {
        gpsUpdateTimer?.invalidate()
        gpsUpdateTimer = nil
    }

    /// Processes a single update for GPS and motion data during a recording session
    func recordUpdate() {
        guard let location = locationManager.location else {
            print("No location available")
            return
        }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let speed = location.speed > 0 ? location.speed * 3.6 : 0.0
        let angle = kalmanFilter.getState()

        if isRecordingReference {
            saveReferenceEntry(latitude: latitude, longitude: longitude, angle: angle)
        } else if isRecordingDrift {
            if let angleDiff = calculateAngleDifference(currentLatitude: latitude, currentLongitude: longitude, angle: angle) {
                DispatchQueue.main.async {
                    self.angleDifference = angleDiff
                    self.angle_auto = angleDiff
                }
                saveDriftEntry(latitude: latitude, longitude: longitude, angle: angleDiff, speed: speed)
            } else {
                print("No angle difference calculated")
            }
        }

        DispatchQueue.main.async {
            self.speedInKmh = speed
            self.angle = abs(self.angleDifference)
        }
    }
    
    /// Handles updates to the device's location from the `CLLocationManager`
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        currentLocation = latestLocation
    }

    // MARK: - Utility
    /// Computes the Haversine distance between two coordinates
    func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371e3
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180

        let a = sin(Δφ / 2) * sin(Δφ / 2) +
                cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
    
    /// Retrieves the human-readable name of a location using reverse geocoding.
    private func getLocationName(from location: CLLocation, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
                completion("Unknown Location")
            } else if let placemark = placemarks?.first {
                let locationName = placemark.locality ?? placemark.administrativeArea ?? "Unknown Location"
                completion(locationName)
            } else {
                print("DEBUG: Nessuna località trovata")
                completion("Unknown Location")
            }
        }
    }
    
    /// Starts GPS location updates using the `CLLocationManager`
    func startGPSUpdates() {
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }

    /// Stops GPS location updates and invalidates the timer for periodic updates.
    func stopFGPSUpdates() {
        gpsUpdateTimer?.invalidate()
        gpsUpdateTimer = nil
        locationManager.stopUpdatingLocation()
    }

    /// Handles errors related to location updates from the `CLLocationManager`
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Errore nella richiesta della posizione: \(error.localizedDescription)")
    }

}
