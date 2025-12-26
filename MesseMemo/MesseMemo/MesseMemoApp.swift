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
//  MULTI-TENANCY:
//  - Jeder Lead hat eine ownerId (Supabase User-ID)
//  - Bestehende Leads ohne ownerId werden beim Start migriert
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
                .task {
                    // Migration für bestehende Leads ohne ownerId
                    await migrateLeadsIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Deep Link Handler
    
    private func handleAuthCallback(url: URL) async {
        do {
            try await SupabaseManager.shared.client.auth.session(from: url)
            await SupabaseManager.shared.checkAuthState()
            
            // Nach Login: Bestehende "local_user" Leads dem neuen User zuweisen
            await migrateLocalUserLeads()
        } catch {
            print("Auth callback error: \(error)")
        }
    }
    
    // MARK: - Lead Migration (Multi-Tenancy)
    
    /// Migriert bestehende Leads ohne ownerId zum aktuellen User
    /// Wird beim App-Start und nach Login aufgerufen
    @MainActor
    private func migrateLeadsIfNeeded() async {
        // Warte kurz auf Auth-Status
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
        
        await migrateLocalUserLeads()
    }
    
    /// Weist Leads mit ownerId="local_user" dem aktuellen eingeloggten User zu
    @MainActor
    private func migrateLocalUserLeads() async {
        guard let userId = SupabaseManager.shared.currentUserId else {
            // Kein User eingeloggt - nichts zu migrieren
            return
        }
        
        let userIdString = userId.uuidString
        let context = sharedModelContainer.mainContext
        
        // Finde alle Leads mit ownerId = "local_user" oder leerem ownerId
        let descriptor = FetchDescriptor<Lead>(
            predicate: #Predicate<Lead> { lead in
                lead.ownerId == "local_user" || lead.ownerId == ""
            }
        )
        
        do {
            let leadsToMigrate = try context.fetch(descriptor)
            
            if !leadsToMigrate.isEmpty {
                print("MesseMemoApp: Migriere \(leadsToMigrate.count) Leads zu User \(userIdString)")
                
                for lead in leadsToMigrate {
                    lead.ownerId = userIdString
                    lead.updatedAt = Date()
                }
                
                try context.save()
                print("MesseMemoApp: Migration erfolgreich abgeschlossen")
            }
        } catch {
            print("MesseMemoApp: Migration fehlgeschlagen - \(error.localizedDescription)")
        }
    }
}
