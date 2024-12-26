//
//  StressDetailView.swift
//  DriftTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 01/12/24.
//

import SwiftUI
import Charts
import CoreData

/// A detailed view for analyzing stress levels on a specific day
/// Displays HRV data in a graphical format and lists related sessions. Includes functionality to export data
struct StressDayDetailView: View {
    @StateObject private var healthManager = HealthManager()
    var day: Date

    @FetchRequest var sessions: FetchedResults<DriftSession>
    @State private var showInfoAlert = false // boolean for info alert
    @State private var selectedSession: DriftSession?

    /// Initializes the view and sets up the fetch request for sessions on the selected day
    /// - Parameter day: The day to analyze.
    init(day: Date) {
        self.day = day
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        _sessions = FetchRequest(
            sortDescriptors: [SortDescriptor(\.startTime, order: .forward)],
            predicate: NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfDay as NSDate, endOfDay as NSDate)
        )
    }

    /// Find date and time of the first session of the day
    private var startOfDay: Date {
        sessions.min(by: { $0.startTime ?? Date.distantFuture < $1.startTime ?? Date.distantFuture })?.startTime ?? Date()
    }
    
    /// Find date and time of the last session of the day
    private var endOfDay: Date {
        sessions.max(by: { $0.startTime ?? Date.distantPast < $1.startTime ?? Date.distantPast })?.startTime ?? Date()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack{
                    Text("Stress Level [ms]")
                        .font(.headline)
                        .foregroundColor(.white)
                    Menu{
                        Button("Export in CSV") {
                            exportDayStressToCSV()
                        }
                    }
                    label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                // Stress Charts
                Chart {
                    // Low HRV - High Stress
                    RectangleMark(xStart: .value("Start", startOfDay),
                                  xEnd: .value("End", endOfDay),
                                  yStart: .value("Low Threshold", 0),
                                  yEnd: .value("High Threshold", 30))
                        .foregroundStyle(.red.opacity(0.2))
                    
                    // Medium HRV - Medium Stress
                    RectangleMark(xStart: .value("Start", startOfDay),
                                  xEnd: .value("End", endOfDay),
                                  yStart: .value("Low Threshold", 30),
                                  yEnd: .value("High Threshold", 60))
                        .foregroundStyle(.yellow.opacity(0.2))
                    
                    // High HRV - Low Stress
                    RectangleMark(xStart: .value("Start", startOfDay),
                                  xEnd: .value("End", endOfDay),
                                  yStart: .value("Low Threshold", 60),
                                  yEnd: .value("High Threshold", 100))
                        .foregroundStyle(.green.opacity(0.2))
                    
                    // Display all the sessions' HRV levels on the chart.
                    ForEach(sessionTimes(), id: \.self) { sessionTime in
                        let closestHRV = healthManager.hrvData.min { a, b in
                            abs(a.timestamp.timeIntervalSince(sessionTime)) < abs(b.timestamp.timeIntervalSince(sessionTime))
                        }
                        let hrvValue = closestHRV?.hrv ?? 0
                        PointMark(
                            x: .value("Time", sessionTime),
                            y: .value("HRV", hrvValue)
                        )
                        .foregroundStyle(
                            sessionTime == selectedSession?.startTime ? .blue : // Blue for the selected session
                                (hrvValue <= 30 ? .red : (hrvValue <= 60 ? .yellow : .green))
                        )
                        .symbolSize(sessionTime == selectedSession?.startTime ? 30 : 25) // Enlarge the point if selected
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 300)
                .padding()
                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                .cornerRadius(15)
                .shadow(radius: 5)
                .padding(.horizontal)

                // Legend
                HStack {
                    LegendItem(color: .red, text: "High Stress")
                    LegendItem(color: .yellow, text: "Medium Stress")
                    LegendItem(color: .green, text: "Low Stress")
                }
                .padding(.bottom)

                // Drift Session List
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(session.name ?? "Unnamed Session")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                // Show HRV value near the name
                                if let hrvValue = healthManager.hrvData.min(by: { abs($0.timestamp.timeIntervalSince(session.startTime ?? Date())) < abs($1.timestamp.timeIntervalSince(session.startTime ?? Date())) })?.hrv {
                                    Text("\(String(format: "%.0f", hrvValue)) ms")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("N/A")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            Text(formattedTime(session.startTime ?? Date()))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selectedSession == session ? Color.blue.opacity(0.3) : Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .onTapGesture {
                            selectedSession = session
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255))
        .navigationTitle("\(formattedDay(day))")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showInfoAlert.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                }
                .alert(isPresented: $showInfoAlert) {
                    // Alert shown when the info button is tapped, explaining the need for smartwatch data
                    Alert(
                        title: Text("Information"),
                        message: Text("If no values are shown (N/A), please connect a smartwatch to capture HRV data."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .onAppear {
            // Fetch HRV data for the specified day and updates the health manager's data
            healthManager.fetchHRVData(for: startOfDay, to: endOfDay) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let hrvData):
                        healthManager.hrvData = hrvData.map { ($0.timestamp, $0.value) }
                    case .failure(let error):
                        print("Errore nel caricamento dei dati HRV: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Returns the start times of all sessions for the selected day.
    private func sessionTimes() -> [Date] {
        sessions.compactMap { $0.startTime }
    }

    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Exports the day's stress analysis data (HRV levels) to a CSV file
    /// The CSV file includes session names, timestamps, and HRV values for each session
    /// The file is saved temporarily and presented to the user via a document picker for export
    private func exportDayStressToCSV() {
        let fileName = "day_stress_analysis_\(dayFormatted()).csv"
        
        // Column Header
        var csvText = "Session Name,Timestamp,HRV (ms)\n"
        
        for session in sessions {
            let sessionName = session.name?.replacingOccurrences(of: ",", with: " ") ?? "Unnamed Session" // Rimuove virgole dai nomi
            let timestamp = formattedTime(session.startTime ?? Date())
            let hrv = healthManager.hrvData.min(by: {
                abs($0.timestamp.timeIntervalSince(session.startTime ?? Date())) <
                abs($1.timestamp.timeIntervalSince(session.startTime ?? Date()))
            })?.hrv ?? 0
            
            // Add row to CSV
            csvText.append("\"\(sessionName)\",\(timestamp),\(String(format: "%.0f", hrv))\n")
        }
        
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvText.write(to: temporaryURL, atomically: true, encoding: .utf8)
            let documentPicker = UIDocumentPickerViewController(forExporting: [temporaryURL])
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(documentPicker, animated: true)
            }
        } catch {
            print("Errore nel salvataggio del CSV: \(error)")
        }
    }

    private func dayFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }
}


/// A view that represents a single legend item with a colored rectangle and descriptive text
/// Useful for explaining the meaning of different color bands in the chart, related to stress levels
struct LegendItem: View {
    var color: Color
    var text: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 10)
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
