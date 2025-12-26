//
//  Lead.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  HINWEIS: CloudKit erfordert Default-Werte für alle non-optional Attribute!
//
//  MULTI-TENANCY:
//  Das Feld `ownerId` speichert die Supabase User-ID, um sicherzustellen,
//  dass jeder User nur seine eigenen Leads sieht. Dies ist wichtig für
//  Datenschutz und wenn mehrere Accounts auf einem Gerät verwendet werden.
//

import Foundation
import SwiftData

/// Das Hauptdatenmodell für einen erfassten Lead/Kontakt
/// CloudKit-kompatibel: Alle Felder haben Default-Werte
@Model
final class Lead {
    
    // ============================================
    // MARK: - Properties (mit Default-Werten für CloudKit)
    // ============================================
    
    /// Eindeutige ID des Leads
    var id: UUID = UUID()
    
    /// Owner ID (Supabase User-ID) für Multi-Tenancy
    /// Stellt sicher, dass jeder User nur seine eigenen Leads sieht
    /// Default: "local_user" für Offline-Erstellung (wird bei Login migriert)
    var ownerId: String = "local_user"
    
    /// Vollständiger Name des Kontakts
    var name: String = ""
    
    /// Firmenname
    var company: String = ""
    
    /// E-Mail-Adresse
    var email: String = ""
    
    /// Telefonnummer
    var phone: String = ""
    
    /// Zusätzliche Notizen (Text)
    var notes: String = ""
    
    /// Pfad zur Audio-Notiz Datei (relativ zum Documents Verzeichnis)
    var audioFilePath: String?
    
    /// Transkript der Sprachnotiz (Speech-to-Text)
    var transcript: String?
    
    /// Dateiname des Original-Fotos der Visitenkarte (für Fallback bei OCR-Fehlern)
    var originalImageFilename: String?
    
    /// Zeitpunkt der Erfassung
    var createdAt: Date = Date()
    
    /// Zeitpunkt der letzten Änderung
    var updatedAt: Date = Date()
    
    // ============================================
    // MARK: - Initialization
    // ============================================
    
    init(
        id: UUID = UUID(),
        ownerId: String = "local_user",
        name: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        notes: String = "",
        audioFilePath: String? = nil,
        transcript: String? = nil,
        originalImageFilename: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.company = company
        self.email = email
        self.phone = phone
        self.notes = notes
        self.audioFilePath = audioFilePath
        self.transcript = transcript
        self.originalImageFilename = originalImageFilename
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // ============================================
    // MARK: - Computed Properties
    // ============================================
    
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
    
    /// Prüft ob ein Transkript vorhanden ist
    var hasTranscript: Bool {
        guard let transcript = transcript else { return false }
        return !transcript.isEmpty
    }
    
    /// Gibt die vollständige URL zum Originalbild zurück
    var originalImageURL: URL? {
        guard let filename = originalImageFilename else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(filename)
    }
    
    /// Prüft ob ein Originalbild existiert
    var hasOriginalImage: Bool {
        guard let url = originalImageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Generiert die LinkedIn-Such-URL für diesen Kontakt
    var linkedInSearchURL: URL? {
        var searchTerms: [String] = []
        if !name.isEmpty { searchTerms.append(name) }
        if !company.isEmpty { searchTerms.append(company) }
        
        guard !searchTerms.isEmpty else { return nil }
        
        let keywords = searchTerms.joined(separator: " ")
        guard let encoded = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        
        return URL(string: "https://www.linkedin.com/search/results/all/?keywords=\(encoded)")
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
