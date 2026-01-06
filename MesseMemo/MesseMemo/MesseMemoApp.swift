//
//  MesseMemoApp.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  LOCAL-ONLY APP:
//  - Leads werden lokal via SwiftData gespeichert
//  - Kein CloudKit Sync
//  - Kein Login erforderlich
//

import SwiftUI
import SwiftData

@main
struct MesseMemoApp: App {
    
    // MARK: - Model Container (Lokal, ohne CloudKit)
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Lead.self,
        ])
        
        // ModelConfiguration OHNE CloudKit
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Kein CloudKit Sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }()

    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
