//
//  TrackerView.swift
//  DriftTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 21/11/24.
//

import SwiftUI
import CoreData
import CoreLocation
import MapKit

///This dashboard provides users with real-time telemetry data: drift angles, speed, and a visualization of their
/// reference path, integrated with a map. This view utilizes the backend functionalities
/// provided by the GeneralManager to update performance metrics in real time, giving
/// accurate and quick feedback during training sessions
struct TrackerView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var navigateToCharts = false
    @State private var currentSession: DriftSession? = nil
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 46.04012, longitude: 11.09014),
            distance: 100,    // Distance in meters
            heading: 270,     // Heading direction (270° = west)
            pitch: 0          // Camera angle (0 = flat)
        )
    )
    @State private var isRunning = false // Indicates if a drift session is currently running
    @State private var showConsentAlert = false
    @State private var isRecordingReference = false // Indicates if a reference session is currently running
    @State private var sessionToPass: DriftSession? = nil // The session to pass to the charts view
    @AppStorage("trackingConsent") private var trackingConsent: Bool = false // Use AppStorage
    @EnvironmentObject var generalManager: GeneralManager
    @State private var carAnnotation = Car(coordinate: CLLocationCoordinate2D(latitude: 46.04012, longitude: 11.09014))
    @State private var showReferenceAlert: Bool = false
    @State private var showTooFarAlert: Bool = false

    // For Polyline
    @State var reference_coordinates : [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 46.03872501080494, longitude: 11.109396771075204),
        CLLocationCoordinate2D(latitude: 46.03838389715741, longitude: 11.10970535537121)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                    .ignoresSafeArea(.all, edges: .all) // Copre tutte le aree
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
             VStack(spacing: 20) {
                    // Logo
                    VStack {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 60)
                            .padding(.top)
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.bottom)
                    }

                    // Speed and Angle detail - horizontal layout
                    HStack(spacing: 20) {
                        StatCard(
                            title: "SPEED [Kmh]",
                            value: .constant(String(format: "%.0f", generalManager.speedInKmh))
                        )
                        StatCard(
                            title: "ANGLE [°]",
                            value: .constant(String(format: "%.0f", generalManager.angle.truncatingRemainder(dividingBy: 360)))
                        )
                    }
                    .padding(.horizontal)

                    // Map with Car Annotation
                    Map(position: $cameraPosition) {
                        Annotation("", coordinate: carAnnotation.coordinate) {
                            Image("car")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .rotationEffect(Angle(degrees: -generalManager.angle_auto)) // Rotate the image based on the angle
                        }
                        if !generalManager.polylineCoordinates.isEmpty {
                            MapPolyline(coordinates: generalManager.polylineCoordinates)
                                .stroke(.orange, lineWidth: 4.0)
                        }
                    }
                    .onAppear {
                        generalManager.context = context // Pass the context to the GeneralManager
                        generalManager.startGPSUpdates()
                        generalManager.loadActiveReferenceCoordinates()
                    }
                    .onChange(of: generalManager.currentLocation) { newLocation in
                        if let currentLocation = newLocation {
                            updateMapRegion(with: currentLocation)
                        }
                    }
                    .frame(height: 300)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(radius: 5)
                    .mapStyle(.imagery)

                    // Buttons
                    HStack(spacing: 20) {
                        TrackerButton(title: "START", color: isRunning ? .gray : .green, isDisabled: isRunning) {
                            // Check 1: Consents
                            if !trackingConsent {
                                showConsentAlert = true
                                return
                            }
                            // Check 2: Existence of reference session
                            if !activeReferenceExists(context: context) {
                                showReferenceAlert = true
                                return
                            }
                            // Check 3: Distance of reference session
                            if generalManager.isTooFarFromReference() {
                                showTooFarAlert = true
                                return
                            }
                            startTracker()

                            if let session = currentSession {
                                generalManager.startDriftRecording(driftSession: session)
                            } else {
                                print("Errore: currentSession è nil")
                            }
                        }
                        .disabled(isRunning)

                        // Consent Alert
                        .alert("Tracking Consent Required", isPresented: $showConsentAlert) {
                            Button("OK") { showConsentAlert = false }
                        } message: {
                            Text("You need to enable tracking to start a session.")
                        }

                        // Reference Missing Alert
                        .alert("No Reference Found", isPresented: $showReferenceAlert) {
                            Button("OK") { showReferenceAlert = false }
                        } message: {
                            Text("No reference session available. Please create a reference session first.")
                        }
                        .alert("Too Far From Reference", isPresented: $showTooFarAlert) {
                            Button("OK") { showTooFarAlert = false }
                        } message: {
                            Text("You are more than 50 meters away from the reference. Please move closer to start.")
                        }

                         TrackerButton(title: "STOP", color: isRunning ? .red : .gray, isDisabled: !isRunning) {
                            stopDriftRecording()
                            generalManager.stopDriftRecording()
                        }
                        .disabled(!isRunning)
                        .navigationDestination(isPresented: $navigateToCharts) {
                            SessionDetailView(session: sessionToPass)
                        }
                    }

                    // Reference Management Buttons
                    TrackerButton(
                        title: isRecordingReference ? "STOP REF" : "START REF",
                        color: isRecordingReference ? .red : .orange,
                        isDisabled: isRunning
                    ) {
                        if trackingConsent {
                            if isRecordingReference {
                                isRecordingReference = false
                                generalManager.stopReferenceRecording()
                                generalManager.loadActiveReferenceCoordinates()
                            } else {
                                isRecordingReference = true
                                generalManager.startReferenceRecording()
                            }
                        } else {
                            showConsentAlert = true
                        }
                    }
                    .padding(.bottom, 20)
                    Spacer()
                }
                .padding(.top, 5)
            }
            .onAppear {
                UINavigationBar.setCustomAppearance()
            }
        }
    }

    // MARK: - Tracker Logic
    /// Starts the drift tracker by initializing a new session and updating the state
    private func startTracker() {
        guard trackingConsent else {
            showConsentAlert = true
            return
        }
        guard !isRunning else { return }
        isRunning = true
        
        let session = DriftSession(context: context)
        session.startTime = Date()
        currentSession = session
        session.name = "Session \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
    }

    /// Stops the current drift recording and navigates to the charts view.
    private func stopDriftRecording() {
        guard isRunning else { return }
        isRunning = false

        currentSession?.endTime = Date()
        sessionToPass = currentSession

        do {
            try context.save()
            currentSession = nil
        } catch {
            print("Error saving session: \(error.localizedDescription)")
        }
        navigateToCharts = true
    }

    /// Updates the map's camera position based on the current location
    private func updateMapRegion(with location: CLLocation) {
        carAnnotation.coordinate = location.coordinate
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: location.coordinate,
                distance: 100,
                heading: 270,  // Mantieni la direzione verso ovest
                pitch: 0
            )
        )
    }}



/// View for speed and angle detail
struct StatCard: View {
    var title: String
    @Binding var value: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)

            Text(value)
                .font(.system(size: 35))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

// TrackerButton View
struct TrackerButton: View {
  var title: String
  var color: Color
  var isDisabled: Bool
  var action: () -> Void

  var body: some View {
      Button(action: action) {
          Text(title)
              .font(.system(size: 24, weight: .bold))
              .padding()
              .frame(width: 160, height: 60)
              .background(color)
              .foregroundColor(.white)
              .cornerRadius(10)
              .shadow(radius: 5)
      }
      .disabled(isDisabled)
      .animation(.easeInOut, value: isDisabled)
  }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
extension UINavigationBar {
    static func setCustomAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 47/255, green: 72/255, blue: 88/255, alpha: 1.0) // Sfondo personalizzato
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white] // Colore del testo
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white] // Colore del titolo grande
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

/// Checks if there is an active reference session in the Core Data store
func activeReferenceExists(context: NSManagedObjectContext) -> Bool {
    let fetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "isActive == true")
    fetchRequest.fetchLimit = 1
    
    do {
        let count = try context.count(for: fetchRequest)
        return count > 0
    } catch {
        print("Errore nel verificare l'esistenza di una ReferenceSession attiva: \(error.localizedDescription)")
        return false
    }
}
