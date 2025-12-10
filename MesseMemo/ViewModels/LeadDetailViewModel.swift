//
//  LeadDetailViewModel.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel für die Detailansicht eines Leads
@MainActor
final class LeadDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let lead: Lead
    let audioService = AudioService()
    
    // MARK: - Published Properties
    
    @Published var isEditing = false
    @Published var showDeleteConfirmation = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Edit Mode Properties
    
    @Published var editName = ""
    @Published var editCompany = ""
    @Published var editEmail = ""
    @Published var editPhone = ""
    @Published var editNotes = ""
    
    // MARK: - Initialization
    
    init(lead: Lead) {
        self.lead = lead
        loadEditFields()
    }
    
    // MARK: - Edit Mode
    
    /// Lädt die aktuellen Werte in die Bearbeitungsfelder
    func loadEditFields() {
        editName = lead.name
        editCompany = lead.company
        editEmail = lead.email
        editPhone = lead.phone
        editNotes = lead.notes
    }
    
    /// Speichert die Änderungen
    func saveChanges() {
        lead.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.company = editCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.email = editEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lead.phone = editPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.updatedAt = Date()
        
        isEditing = false
    }
    
    /// Bricht die Bearbeitung ab
    func cancelEditing() {
        loadEditFields()
        isEditing = false
    }
    
    // MARK: - Audio Playback
    
    /// Spielt die Audio-Notiz ab oder stoppt sie
    func toggleAudioPlayback() {
        guard let audioPath = lead.audioFilePath else { return }
        
        if audioService.isPlaying {
            audioService.stopPlayback()
        } else {
            do {
                try audioService.play(from: audioPath)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    /// Stoppt die Wiedergabe
    func stopPlayback() {
        audioService.stopPlayback()
    }
    
    // MARK: - Audio Duration
    
    /// Gibt die formatierte Dauer der Audioaufnahme zurück
    var audioDuration: String? {
        guard let path = lead.audioFilePath,
              let duration = audioService.getDuration(for: path) else {
            return nil
        }
        return AudioService.formatTime(duration)
    }
    
    // MARK: - Actions
    
    /// Öffnet die E-Mail-App
    func openMail() {
        guard !lead.email.isEmpty,
              let url = URL(string: "mailto:\(lead.email)") else { return }
        UIApplication.shared.open(url)
    }
    
    /// Öffnet die Telefon-App
    func callPhone() {
        let cleanedPhone = lead.phone.replacingOccurrences(of: " ", with: "")
        guard !cleanedPhone.isEmpty,
              let url = URL(string: "tel:\(cleanedPhone)") else { return }
        UIApplication.shared.open(url)
    }
    
    /// Kopiert alle Kontaktdaten in die Zwischenablage
    func copyToClipboard() {
        var text = ""
        if !lead.name.isEmpty { text += "Name: \(lead.name)\n" }
        if !lead.company.isEmpty { text += "Firma: \(lead.company)\n" }
        if !lead.email.isEmpty { text += "E-Mail: \(lead.email)\n" }
        if !lead.phone.isEmpty { text += "Telefon: \(lead.phone)\n" }
        if !lead.notes.isEmpty { text += "Notizen: \(lead.notes)" }
        
        UIPasteboard.general.string = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

