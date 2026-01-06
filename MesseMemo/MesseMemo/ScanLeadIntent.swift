//
//  ScanLeadIntent.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 06.01.26.
//
//  App Intent für Action Button (iPhone 15/16)
//  Ermöglicht das direkte Starten des Scanners über den Action Button
//

import AppIntents

/// App Intent zum Scannen einer Visitenkarte
/// Kann dem Action Button zugewiesen werden
struct ScanLeadIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Visitenkarte scannen"
    static var description = IntentDescription("Öffnet MesseMemo und startet den Scanner für eine neue Visitenkarte.")
    
    // Öffnet die App beim Ausführen
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // App öffnet sich automatisch (openAppWhenRun = true)
        // Der DeepLink "messememo://scan" wird in RootView behandelt
        
        // Alternativ: Notification posten, die von der App empfangen wird
        NotificationCenter.default.post(
            name: .openScanner,
            object: nil
        )
        
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct MesseMemoShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanLeadIntent(),
            phrases: [
                "Scanne eine Visitenkarte mit \(.applicationName)",
                "Visitenkarte scannen mit \(.applicationName)",
                "Neuen Kontakt erfassen mit \(.applicationName)",
                "Lead scannen mit \(.applicationName)"
            ],
            shortTitle: "Visitenkarte scannen",
            systemImageName: "viewfinder"
        )
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let openScanner = Notification.Name("openScanner")
}

