//
//  Lead.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import SwiftData

/// Das Hauptdatenmodell für einen erfassten Lead/Kontakt
@Model
final class Lead {
    /// Eindeutige ID des Leads
    var id: UUID
    
    /// Vollständiger Name des Kontakts
    var name: String
    
    /// Firmenname
    var company: String
    
    /// E-Mail-Adresse
    var email: String
    
    /// Telefonnummer
    var phone: String
    
    /// Zusätzliche Notizen (Text)
    var notes: String
    
    /// Pfad zur Audio-Notiz Datei (relativ zum Documents Verzeichnis)
    var audioFilePath: String?
    
    /// Zeitpunkt der Erfassung
    var createdAt: Date
    
    /// Zeitpunkt der letzten Änderung
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        notes: String = "",
        audioFilePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.email = email
        self.phone = phone
        self.notes = notes
        self.audioFilePath = audioFilePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Gibt die vollständige URL zur Audio-Datei zurück
    var audioFileURL: URL? {
        guard let audioFilePath = audioFilePath else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(audioFilePath)
    }
    
    /// Prüft ob eine Audio-Notiz existiert
    var hasAudioNote: Bool {
        guard let url = audioFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Formatiertes Erstellungsdatum
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: createdAt)
    }
    
    /// Gibt einen Display-Namen zurück (Name oder "Unbekannt")
    var displayName: String {
        name.isEmpty ? "Unbekannter Kontakt" : name
    }
    
    /// Prüft ob der Lead minimal ausgefüllt ist
    var isValid: Bool {
        !name.isEmpty || !email.isEmpty || !phone.isEmpty || !company.isEmpty
    }
}

