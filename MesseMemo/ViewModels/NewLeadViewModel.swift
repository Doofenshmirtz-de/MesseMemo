//
//  NewLeadViewModel.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel für das Erstellen eines neuen Leads
@MainActor
final class NewLeadViewModel: ObservableObject {
    
    // MARK: - Published Properties (Formularfelder)
    
    @Published var name = ""
    @Published var company = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var notes = ""
    @Published var audioFilePath: String?
    
    // MARK: - UI State
    
    @Published var showCamera = false
    @Published var isProcessingImage = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isSaving = false
    
    // MARK: - Services
    
    private let ocrService = OCRService()
    let audioService = AudioService()
    
    // MARK: - Lead ID (für Audio-Dateinamen)
    
    let leadId = UUID()
    
    // MARK: - OCR Processing
    
    /// Verarbeitet ein aufgenommenes Bild und extrahiert Kontaktdaten
    func processImage(_ image: UIImage) async {
        isProcessingImage = true
        
        do {
            // Text erkennen
            let recognizedLines = try await ocrService.recognizeText(from: image)
            
            // Kontaktdaten parsen
            let parsedContact = ocrService.parseContactInfo(from: recognizedLines)
            
            // Formularfelder aktualisieren (nur leere Felder überschreiben)
            if name.isEmpty { name = parsedContact.name }
            if company.isEmpty { company = parsedContact.company }
            if email.isEmpty { email = parsedContact.email }
            if phone.isEmpty { phone = parsedContact.phone }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isProcessingImage = false
    }
    
    // MARK: - Audio Recording
    
    /// Startet die Audioaufnahme
    func startRecording() {
        do {
            audioFilePath = try audioService.startRecording(for: leadId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// Stoppt die Audioaufnahme
    func stopRecording() {
        audioService.stopRecording()
    }
    
    /// Löscht die aktuelle Aufnahme
    func deleteRecording() {
        if let path = audioFilePath {
            audioService.deleteRecording(at: path)
            audioFilePath = nil
        }
    }
    
    // MARK: - Validation
    
    /// Prüft ob das Formular valide ist
    var isValid: Bool {
        !name.isEmpty || !email.isEmpty || !phone.isEmpty || !company.isEmpty
    }
    
    // MARK: - Save
    
    /// Speichert den Lead in der Datenbank
    func saveLead(context: ModelContext) -> Bool {
        guard isValid else {
            errorMessage = "Bitte fülle mindestens ein Kontaktfeld aus."
            showError = true
            return false
        }
        
        isSaving = true
        
        let lead = Lead(
            id: leadId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            company: company.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            audioFilePath: audioFilePath
        )
        
        context.insert(lead)
        
        isSaving = false
        return true
    }
    
    // MARK: - Reset
    
    /// Setzt alle Formularfelder zurück
    func reset() {
        name = ""
        company = ""
        email = ""
        phone = ""
        notes = ""
        
        // Audio löschen falls vorhanden
        deleteRecording()
    }
}

