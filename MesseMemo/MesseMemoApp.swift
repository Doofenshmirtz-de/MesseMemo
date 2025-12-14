//
//  MesseMemoApp.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  ARCHITEKTUR:
//  - Leads werden lokal via SwiftData gespeichert
//  - CloudKit synchronisiert automatisch über alle Geräte
//  - Supabase nur für Auth & KI-Funktionen
//

import SwiftUI
import SwiftData
import Supabase

@main
struct MesseMemoApp: App {
    
    // MARK: - Model Container (mit CloudKit Sync)
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Lead.self,
        ])
        
        // ModelConfiguration mit CloudKit
        // WICHTIG: CloudKit sync passiert automatisch wenn:
        // 1. iCloud Capability aktiviert ist
        // 2. CloudKit Container konfiguriert ist
        // 3. User bei iCloud eingeloggt ist
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            // CloudKit wird automatisch verwendet wenn die Capability aktiviert ist
            // Für explizite Kontrolle: cloudKitDatabase: .automatic
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // In Production: Crashlytics/Sentry Logging
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }()

    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    Task {
                        await handleAuthCallback(url: url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Deep Link Handler
    
    private func handleAuthCallback(url: URL) async {
        do {
            try await SupabaseManager.shared.client.auth.session(from: url)
            await SupabaseManager.shared.checkAuthState()
        } catch {
            print("Auth callback error: \(error)")
        }
    }
}
