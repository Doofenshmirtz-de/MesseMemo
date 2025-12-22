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
    @Published var originalImageFilename: String?
    
    // MARK: - UI State
    
    @Published var showCamera = false
    @Published var isProcessingImage = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isSaving = false
    @Published var showOCRSuccessAnimation = false
    
    // MARK: - Services
    
    private let ocrService = OCRService()
    private let imageStorageService = ImageStorageService.shared
    let audioService = AudioService()
    
    // MARK: - Lead ID (für Audio-Dateinamen)
    
    let leadId = UUID()
    
    // MARK: - OCR Processing
    
    /// Verarbeitet ein aufgenommenes Bild und extrahiert Kontaktdaten
    func processImage(_ image: UIImage) async {
        isProcessingImage = true
        
        do {
            // 1. Originalbild speichern (für Fallback bei OCR-Fehlern)
            do {
                let filename = try imageStorageService.saveImage(image, for: leadId)
                originalImageFilename = filename
            } catch {
                print("NewLeadViewModel: Warnung - Bild konnte nicht gespeichert werden: \(error.localizedDescription)")
                // Wir fahren trotzdem mit OCR fort
            }
            
            // 2. Text erkennen
            let recognizedLines = try await ocrService.recognizeText(from: image)
            
            // 3. Prüfen ob überhaupt Text erkannt wurde
            guard !recognizedLines.isEmpty else {
                throw OCRError.noTextFound
            }
            
            // 4. Kontaktdaten parsen
            let parsedContact = ocrService.parseContactInfo(from: recognizedLines)
            
            // 5. Prüfen ob relevante Daten gefunden wurden
            let hasAnyData = !parsedContact.name.isEmpty || 
                             !parsedContact.company.isEmpty || 
                             !parsedContact.email.isEmpty || 
                             !parsedContact.phone.isEmpty
            
            if !hasAnyData {
                throw OCRError.noContactDataFound
            }
            
            // 6. Formularfelder aktualisieren (nur leere Felder überschreiben)
            let fieldsUpdated = updateFormFields(with: parsedContact)
            
            // 7. Erfolgsanimation triggern
            if fieldsUpdated > 0 {
                showOCRSuccessAnimation = true
                
                // Haptic Feedback für Erfolg
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Animation nach kurzer Zeit zurücksetzen
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 Sekunden
                    showOCRSuccessAnimation = false
                }
            }
            
        } catch let error as OCRError {
            // Benutzerfreundliche OCR-Fehlermeldungen
            errorMessage = error.userFriendlyMessage
            showError = true
            
            // Haptic Feedback für Fehler
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
        } catch {
            errorMessage = "Texterkennung fehlgeschlagen. Bitte gib die Daten manuell ein."
            showError = true
        }
        
        isProcessingImage = false
    }
    
    /// Aktualisiert die Formularfelder mit geparsten Daten
    /// - Returns: Anzahl der aktualisierten Felder
    private func updateFormFields(with contact: ParsedContact) -> Int {
        var updatedCount = 0
        
        if name.isEmpty && !contact.name.isEmpty { 
            name = contact.name 
            updatedCount += 1
        }
        if company.isEmpty && !contact.company.isEmpty { 
            company = contact.company 
            updatedCount += 1
        }
        if email.isEmpty && !contact.email.isEmpty { 
            email = contact.email 
            updatedCount += 1
        }
        if phone.isEmpty && !contact.phone.isEmpty { 
            phone = contact.phone 
            updatedCount += 1
        }
        
        return updatedCount
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
            audioFilePath: audioFilePath,
            originalImageFilename: originalImageFilename
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
        
        // Bild löschen falls vorhanden
        deleteImage()
    }
    
    /// Löscht das gespeicherte Bild
    func deleteImage() {
        if let filename = originalImageFilename {
            imageStorageService.deleteImage(filename: filename)
            originalImageFilename = nil
        }
    }
}

