//
//  SessionDetailView.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 27/10/24.
//

import SwiftUI
import CoreData
import Charts

/// The `SessionDetailView` struct defines a SwiftUI view that allows the user to see the detail of each specific session
struct SessionDetailView: View {
    var session: DriftSession? // Drift session to be displayed

    @State private var selectedTab: DetailTab = .chart // Default selected tab is "Charts"
    @StateObject private var healthManager = HealthManager()

    var body: some View {
        ZStack {
            Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    if let session = session {
                        Spacer(minLength: 10)
                        HStack {
                            VStack {
                                Text("START session")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.white)
                                Text("\(formattedDate(session.startTime ?? Date()))")
                                    .foregroundColor(Color.white)
                            }
                            Divider()
                                //.frame(height: 60)
                                .background(Color.white.opacity(0.3))
                            VStack {
                                Text("END session")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.white)
                                Text("\(formattedDate(session.endTime ?? Date()))")
                                    .foregroundColor(Color.white)
                            }
                        }
                        Divider()
                            .background(Color.white.opacity(0.3))
                        // Buttons to switch between tabs (Charts and Metrics)
                        HStack(spacing: 20) {
                            Button(action: {
                                selectedTab = .chart
                            }) {
                                Text("Charts")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedTab == .chart ? Color.gray : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            // Display content based on selected tab
                            Button(action: {
                                selectedTab = .index
                            }) {
                                Text("Metrics")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectedTab == .index ? Color.gray : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        .padding()
                        if selectedTab == .chart {
                            ChartView(session: session)
                        } else if selectedTab == .index {
                            IndexView(session: session)
                        }
                        
                    } else {
                        Text("Nessuna sessione disponibile.")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    /// Format date for display
    private func formattedDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy HH:mm"
        return dateFormatter.string(from: date)
    }
}

// Enum for active tab selection
enum DetailTab {
    case chart
    case index
}

// View for displaying session charts
struct ChartView: View {
    var session: DriftSession

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                // Chart for Angle
                Text("ANGLE")
                    .font(.system(size: 20))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Chart {
                    ForEach(session.driftEntriesArray, id: \.timestamp) { entry in
                        LineMark(
                            x: .value("Time", entry.timestamp ?? Date()),
                            y: .value("Angle", abs(entry.gyroZ))
                        )
                        .foregroundStyle(Gradient(colors: [.orange, .yellow]))
                        .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Max Angle", session.driftEntriesArray.map { $0.gyroZ }.max() ?? 0.0))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Max Angle")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(4)
                                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                .cornerRadius(4)
                        }
                }
                .frame(height: 300)
                .padding()
                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                .cornerRadius(10)
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white)
                        AxisValueLabel()
                            .foregroundStyle(.white)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white)
                        AxisValueLabel()
                            .foregroundStyle(.white)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.5))
            // Chart for Speed
            VStack {
                Text("SPEED")
                    .font(.system(size: 20))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Chart {
                    ForEach(session.driftEntriesArray, id: \.timestamp) { entry in
                        LineMark(
                            x: .value("Time", entry.timestamp ?? Date()),
                            y: .value("Speed", entry.speed)
                        )
                        .foregroundStyle(Gradient(colors: [.blue, .purple]))
                        .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Max Speed", session.driftEntriesArray.map { $0.speed }.max() ?? 0.0))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Max Speed")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(4)
                                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                .cornerRadius(4)
                        }
                }
                .frame(height: 300)
                .padding()
                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                .cornerRadius(10)
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white)
                        AxisValueLabel()
                            .foregroundStyle(.white)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(.white)
                        AxisValueLabel()
                            .foregroundStyle(.white)
                    }
                }
            }

        }
        .padding()
    }
}
// View for displaying session metrics
struct IndexView: View {
    var session: DriftSession
    @StateObject private var healthManager = HealthManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Calculate metrics
                let maxSpeed = session.driftEntriesArray.map { $0.speed }.max() ?? 0.0
                let maxAngle = session.driftEntriesArray.map { $0.gyroZ }.max() ?? 0.0
                let avgSpeed = session.driftEntriesArray.map { $0.speed }.average()
                let avgAngle = session.driftEntriesArray.map { $0.gyroZ }.average()
                let entriesAtMaxAngle = session.driftEntriesArray.filter { $0.gyroZ == maxAngle }
                let speedsAtMaxAngle = entriesAtMaxAngle.compactMap { driftEntry -> Double? in
                    let timestamp = driftEntry.timestamp ?? Date()
                    let closestGPSEntry = session.driftEntriesArray.min(by: {
                        abs($0.timestamp?.timeIntervalSince(timestamp) ?? .infinity) <
                        abs($1.timestamp?.timeIntervalSince(timestamp) ?? .infinity)
                    })
                    return closestGPSEntry?.speed
                }
                let speedAtMaxAngle = speedsAtMaxAngle.max() ?? 0.0
                VStack(spacing: 20) {
                    MetricRow(
                        iconName: "speedometer",
                        title: "Max Speed",
                        value: "\(String(format: "%.0f", maxSpeed)) Km/h",
                        color: .orange
                    )
                    
                    MetricRow(
                        iconName: "gauge.high",
                        title: "Max Angle",
                        value: "\(String(format: "%.0f", maxAngle)) º",
                        color: .orange
                    )
                    
                    MetricRow(
                        iconName: "arrow.up.arrow.down",
                        title: "Average Speed",
                        value: "\(String(format: "%.0f", avgSpeed)) Km/h",
                        color: .orange
                    )
                    
                    MetricRow(
                        iconName: "angle",
                        title: "Average Angle",
                        value: "\(String(format: "%.0f", abs(avgAngle))) º",
                        color: .orange
                    )
                    
                    MetricRow(
                        iconName: "speedometer",
                        title: "Max Speed at Max Angle",
                        value: "\(String(format: "%.0f", speedAtMaxAngle)) Km/h",
                        color: .orange
                    )
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(15)
                .shadow(radius: 5)
                
                Spacer()
            }
            .padding()
        }
    }
}

// View for displaying a single metric
struct MetricRow: View {
    var iconName: String
    var title: String
    var value: String
    var color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.largeTitle)
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

/// Generate time ticks for charts
func generateTimeTicks(from entries: [DriftEntry], interval: Int) -> [Date] {
    guard let start = entries.first?.timestamp, let end = entries.last?.timestamp else {
        return []
    }

    var ticks: [Date] = []
    var current = start

    while current <= end {
        ticks.append(current)
        current = Calendar.current.date(byAdding: .second, value: interval, to: current) ?? current
    }

    return ticks
}

// Extensions for Core Data and Array utilities
extension DriftSession {
    var driftEntriesArray: [DriftEntry] {
        guard let entries = driftEntries as? Set<DriftEntry> else {
            print("No entries found for DriftSession: \(self.name ?? "Unnamed Session")")
            return []
        }
        // Sort entries by timestamp and normalize angles
        let sortedEntries = entries.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        sortedEntries.forEach { $0.gyroZ = abs($0.gyroZ).truncatingRemainder(dividingBy: 360) } //funcion for truncate the 0-360 degree angle
        return sortedEntries
    }
}

extension Array where Element: BinaryFloatingPoint {
    func average() -> Element {
        guard !isEmpty else { return 0 }
        let sum = reduce(0, +)
        return sum / Element(count)
    }
}
