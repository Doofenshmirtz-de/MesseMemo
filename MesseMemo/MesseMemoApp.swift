//
//  MesseMemoApp.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import SwiftData

@main
struct MesseMemoApp: App {
    
    // MARK: - Model Container
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Lead.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
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
            DashboardView()
        }
        .modelContainer(sharedModelContainer)
    }
}
