//
//  ConsentView.swift
//  DriftTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 12/10/24.
//

import SwiftUI
import UIKit

/// The `ConsentView` struct defines a SwiftUI view that allows the user to manage their tracking consent for the app
struct ConsentView: View {
    // A property stored in `AppStorage` to persist the user's tracking consent preference
    @AppStorage("trackingConsent") private var trackingConsent: Bool = UserDefaults.standard.bool(forKey: "trackingConsent")

    var body: some View {
        ZStack {
            Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 0)
                VStack {
                    Text("This app will use your phone sensors to capture speed and angle data.")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)

                    // Toggle to enable/disable tracking consent
                    Toggle(isOn: $trackingConsent) {
                        Text("Allow tracking of your device data")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding()
                    .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }

                // Button to open the app's settings page
                Button(action: openAppSettings) {
                    Text("Disable Position Consent")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Spacer()
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
        }
    }

    /// Opens the app's settings page to allow the user to modify their app permissions
    func openAppSettings() {
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }
}
