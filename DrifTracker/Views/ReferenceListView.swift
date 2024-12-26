//
//  ReferenceListView.swift
//  DriftTracker
//
//  Created by Erika Scaltrito and Sabrina Vinco on 01/12/24.
//

import SwiftUI
import CoreData

/// A view displaying the list of reference sessions with search functionality and interactive options
struct ReferenceListView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        fetchRequest: ReferenceSession.fetchRequestSortedByStartTime()
    ) private var referenceSessions: FetchedResults<ReferenceSession>
    
    @EnvironmentObject var generalManager: GeneralManager
    @State private var searchText: String = "" // search text
    @State private var showInfoAlert = false // boolean for info alert

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 47 / 255, green: 72 / 255, blue: 88 / 255)
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.dismissKeyboard()
                    }
                VStack {
                    // Logo
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 60)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.bottom, 10)
                    
                    HStack{
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                            TextField("Cerca", text: $searchText)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .frame(maxWidth: 300)

                        Button(action: {
                            showInfoAlert.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .alert(isPresented: $showInfoAlert) {
                            Alert(
                                title: Text("Information"),
                                message: Text("To select the reference you want to use, click on the reference name."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    }
                    // Reference session list
                    List {
                        ForEach(referenceSessions.filter { session in
                            searchText.isEmpty || (session.name?.lowercased().contains(searchText.lowercased()) ?? false)
                        }) { session in
                            ReferenceSessionRow(session: session)
                                .listRowInsets(EdgeInsets())
                                .background(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                        }
                    }
                    .listRowBackground(Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
                    .background(Color.clear)
                    .onAppear {
                        generalManager.context = context
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
}

// MARK: - Reference Session Row
/// A view representing a single reference session with actions to rename or delete the session
struct ReferenceSessionRow: View {
    @ObservedObject var session: ReferenceSession
    @EnvironmentObject var generalManager: GeneralManager
    @Environment(\.managedObjectContext) private var context
    @State private var showRenameAlert = false
    @State private var referenceToRename: ReferenceSession? // Sessione da rinominare
    @State private var newReferenceName: String = ""

    var body: some View {
        HStack {
            Button(action: {
                generalManager.setActiveReferenceSession(referenceSession: session)
                try? context.save()
            }) {
                VStack(alignment: .leading) {
                    Text(session.name ?? "Reference \(formattedDate(session.startTime))")
                        .font(.headline)
                        .foregroundColor(session.isActive ? .white : .white)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack {
                        Text(session.location ?? "Location not available")
                            .font(.subheadline)
                            .foregroundColor(session.isActive ? .white : .gray)
                        Text(formattedDate(session.startTime))
                            .font(.subheadline)
                            .foregroundColor(session.isActive ? .white : .gray)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Operations Menu
            Menu {
                Button("Rename") {
                    referenceToRename = session
                    newReferenceName = session.name ?? ""
                    showRenameAlert = true
                }
                Button("Delete", role: .destructive) {
                    deleteReference(session)
                    try? context.save()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(session.isActive ? .white : .gray)
            }
        }
        .padding()
        .alert("Rename session", isPresented: $showRenameAlert) {
            VStack {
                TextField("New name", text: $newReferenceName)
                    .padding()
            }
            Button("Save") {
                renameSession()
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(session.isActive ? Color.orange : Color(red: 31 / 255, green: 48 / 255, blue: 59 / 255))
    }

    private func renameSession() {
        guard let session = referenceToRename else { return }
        session.name = newReferenceName
        saveContext()
    }
    

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("Errore nel salvataggio del contesto: \(error.localizedDescription)")
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Deletes the specified reference session and updates the active session if needed
    private func deleteReference(_ session: ReferenceSession) {
        let wasActive = session.isActive
        context.delete(session)
       
        do {
            try context.save()
            if wasActive {
                let fetchRequest: NSFetchRequest<ReferenceSession> = ReferenceSession.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
               
                do {
                    let sessions = try context.fetch(fetchRequest)
                    if let newSessionToActivate = sessions.first {
                        newSessionToActivate.isActive = true
                        try context.save()
                    } else {
                        print("Nessuna sessione di riferimento rimasta dopo l'eliminazione.")
                    }
                } catch {
                    print("Errore nel recuperare le sessioni da database: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Errore durante l'eliminazione della sessione: \(error.localizedDescription)")
        }
    }
}

extension ReferenceSession {
    /// Fetch request for retrieving reference sessions sorted by start time
    static func fetchRequestSortedByStartTime() -> NSFetchRequest<ReferenceSession> {
        let request = ReferenceSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }
}
