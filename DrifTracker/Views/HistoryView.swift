//
//  HistoryView.swift
//  DrifTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 03/11/24.
//

import SwiftUI

/// The `HistoryView` struct defines a SwiftUI view that allows the user to manage their old session recorded
struct HistoryView: View {
    // Fetch drift sessions sorted by start date in descending order
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DriftSession.startTime, ascending: false)],
        animation: .default
    ) private var sessions: FetchedResults<DriftSession>
    
    // Initialization of all parameters needed
    @Environment(\.managedObjectContext) private var context
    @State private var isEditing = false
    @State private var selectedSessions: Set<DriftSession> = []
    @State private var searchText: String = ""
    @State private var expandedDays: Set<Date> = []
    @State private var showRenameAlert = false
    @State private var sessionToRename: DriftSession?
    @State private var newSessionName: String = ""
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: DriftSession?


    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.dismissKeyboard()  // Dismiss keyboard when tapping outside for the searching view
                    }
                
                VStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 60)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.bottom, 10)
                    
                    HStack {
                        if !isEditing { // Show search bar only when not in edit mode
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)

                                TextField("Cerca", text: $searchText)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity)
                        }
                        Spacer()
                        // Edit and Delete buttons when is in edit mode
                        HStack(spacing: 10) {
                            Button(action: {
                                withAnimation {
                                    isEditing.toggle()
                                    if !isEditing {
                                        selectedSessions.removeAll()
                                    }
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                                    .font(.headline)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, maxHeight: 55)
                                    .background(isEditing ? Color.green : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            if isEditing {
                                Button(action: {
                                    exportSelectedSessionsToCSV()
                                }) {
                                    Text("Export")
                                        .font(.headline)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, maxHeight: 55)
                                        .background(selectedSessions.isEmpty ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(selectedSessions.isEmpty)
                                Button(action: {
                                    showDeleteAlert = true
                                }) {
                                    Text("Delete")
                                        .font(.headline)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, maxHeight: 55)
                                        .background(selectedSessions.isEmpty ? Color.gray : Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(selectedSessions.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal)
                   
                    // List of dates and sessions
                    List {
                        ForEach(filteredGroupedSessions(), id: \.0) { (day, dailySessions) in
                            Section(header: HStack {
                                Text(formattedDate(day))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                // Button to expand/collapse the day section
                                Button(action: {
                                    toggleExpansion(for: day)
                                }) {
                                    Image(systemName: expandedDays.contains(day) ? "chevron.down" : "chevron.right")
                                        .foregroundColor(.white)
                                }
                            }){
                                if expandedDays.contains(day) {
                                    if isEditing {
                                        HStack {
                                            Button(action: {
                                                toggleSelectAll(for: dailySessions)
                                            }) {
                                                Image(systemName: allSessionsSelected(dailySessions) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(allSessionsSelected(dailySessions) ? .orange : .gray)
                                            }
                                            Text("Select All Day Sessions")
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                        }
                                        .padding(.vertical, 5)
                                        .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                        .listRowBackground(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                    }
                                    if !isEditing {
                                        // Option to view daily stress analysis
                                        NavigationLink(destination: StressDayDetailView(day: day)){
                                            HStack {
                                                Image(systemName: "waveform.path.ecg")
                                                    .foregroundColor(.orange)
                                                Text("Day Stress Analysis")
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(.vertical, 5)
                                        }
                                        .listRowBackground(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                    }
                                    // List of sessions for the day
                                    ForEach(dailySessions, id: \.self) { session in
                                        HStack {
                                            if isEditing {
                                                Button(action: {
                                                    toggleSelection(for: session)
                                                }) {
                                                    Image(systemName: selectedSessions.contains(session) ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(selectedSessions.contains(session) ? .orange : .gray)
                                                }
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text(session.name ?? "Unnamed Session")
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                    
                                                    Text(formattedTime(session.startTime ?? Date()))
                                                        .font(.subheadline)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            if !isEditing{
                                                // Navigation link to session details
                                                NavigationLink(destination: SessionDetailView(session: session)) {
                                                    VStack(alignment: .leading, spacing: 5) {
                                                        Text(session.name ?? "Unnamed Session")
                                                            .font(.headline)
                                                            .foregroundColor(.white)
                                                        
                                                        Text(formattedTime(session.startTime ?? Date()))
                                                            .font(.subheadline)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                            Spacer()

                                            if !isEditing {
                                                // Options menu for session actions
                                                Menu {
                                                    Button("Rename") {
                                                        sessionToRename = session
                                                        newSessionName = session.name ?? ""
                                                        showRenameAlert = true
                                                    }
                                                    Button("Export in CSV") {
                                                        exportToCSV(session: session)
                                                    }
                                                    Button("Delete", role: .destructive) {
                                                        sessionToDelete = session
                                                    }
                                                }
                                                label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.title2)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .listRowBackground(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .alert("Delete selected sessions?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteSelectedSessions)
        }
        .alert(item: $sessionToDelete) { session in
            Alert(
                title: Text("Delete session?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteSession(session: session)
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Rename session", isPresented: $showRenameAlert) {
            VStack {
                TextField("New name", text: $newSessionName)
                    .padding()
            }
            Button("Save") {
                renameSession()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Toggles selection for a single session
    private func toggleSelection(for session: DriftSession) {
        if selectedSessions.contains(session) {
            selectedSessions.remove(session)
        } else {
            selectedSessions.insert(session)
        }
    }
    // MARK: - Select/Deselect all sessions for a specific day
    private func toggleSelectAll(for dailySessions: [DriftSession]) {
        if allSessionsSelected(dailySessions) {
            dailySessions.forEach { session in
                selectedSessions.remove(session)
            }
        } else {
            dailySessions.forEach { session in
                selectedSessions.insert(session)
            }
        }
    }
    /// Checks if all sessions for a given day are selected.
    private func allSessionsSelected(_ dailySessions: [DriftSession]) -> Bool {
        return dailySessions.allSatisfy { selectedSessions.contains($0) }
    }
    // MARK: - Export a single session to a CSV file
    private func exportToCSV(session: DriftSession) {
        var csvText = "Timestamp,Speed [Kmh],Angle [º]\n"
        
        for driftEntriesArray in session.driftEntriesArray {
            let timestamp = driftEntriesArray.timestamp ?? Date()
            let speed = driftEntriesArray.speed
            let angle = abs(driftEntriesArray.gyroZ)
            csvText += "\(formattedTime(timestamp)),\(String(format: "%.0f", speed)),\(String(format: "%.0f", angle))\n"
        }
        
        let fileName = "exported_session_\(DateFormatter.localizedString(from: session.startTime ?? Date(), dateStyle: .short, timeStyle: .short))"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .appending(".csv")
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
    // MARK: - Export all selected sessions to a single CSV file
    private func exportSelectedSessionsToCSV() {
        guard !selectedSessions.isEmpty else { return }

        var csvText = "Session Name,Timestamp,Speed [Kmh],Angle [º]\n"
        
        for session in selectedSessions {
            let sessionName = session.name?.replacingOccurrences(of: ",", with: " ") ?? "Unnamed Session"

            for driftEntry in session.driftEntriesArray {
                let timestamp = formattedTime(driftEntry.timestamp ?? Date())
                let speed = driftEntry.speed
                let angle = abs(driftEntry.gyroZ)
                
                csvText += "\(sessionName),\(timestamp),\(String(format: "%.0f", speed)),\(String(format: "%.0f", angle))\n"
            }
        }
        
        let fileName = "exported_sessions_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .appending(".csv")
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
    
    
    // MARK: - Save the Core Data context
    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Errore nel salvataggio del contesto: \(error.localizedDescription)")
        }
    }
    // MARK: - Delete all selected sessions
    private func deleteSelectedSessions() {
        for session in selectedSessions {
            context.delete(session)
        }
        saveContext()
        selectedSessions.removeAll()
    }

    // MARK: - Delete a specific session
    private func deleteSession(session: DriftSession) {
        context.delete(session)
        saveContext()
    }

    // MARK: - Rename a session
    private func renameSession() {
        guard let session = sessionToRename else { return }
        session.name = newSessionName
        saveContext()
    }

    // MARK: - Formatters for date and time
    private func formattedDate(_ date: Date) -> String {
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

    // MARK: - Group sessions by day
    private func groupSessionsByDay(sessions: FetchedResults<DriftSession>) -> [(Date, [DriftSession])] {
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            Calendar.current.startOfDay(for: session.startTime ?? Date())
        }
        return grouped.sorted { $0.key > $1.key }
    }
    // MARK: - Filter sessions based on search text and group them by day
    private func filteredGroupedSessions() -> [(Date, [DriftSession])] {
        let grouped = groupSessionsByDay(sessions: sessions)
        
        if searchText.isEmpty {
            return grouped
        }
        return grouped.map { (day, dailySessions) in
             (day, dailySessions.filter { session in
                 session.name?.localizedCaseInsensitiveContains(searchText) ?? false
             })
         }
         .filter { !$0.1.isEmpty }
     }
    // MARK: - Expand or collapse a specific day
    private func toggleExpansion(for day: Date) {
        if expandedDays.contains(day) {
            expandedDays.remove(day)
        } else {
            expandedDays.insert(day)
        }
    }
}
// MARK: - Extension to dismiss the keyboard
extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
