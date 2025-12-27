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
    private let vCardParser = VCardParser()
    private let imageStorageService = ImageStorageService.shared
    let audioService = AudioService()
    
    // MARK: - QR Code State
    
    @Published var qrCodeDetected = false
    @Published var qrCodeURL: String?
    
    // MARK: - Lead ID (für Audio-Dateinamen)
    
    let leadId = UUID()
    
    // MARK: - Image Processing (OCR + QR-Code)
    
    /// Verarbeitet ein aufgenommenes Bild und extrahiert Kontaktdaten
    /// Nutzt sowohl OCR als auch QR-Code-Erkennung, wobei QR-Daten priorisiert werden
    func processImage(_ image: UIImage) async {
        isProcessingImage = true
        qrCodeDetected = false
        qrCodeURL = nil
        
        do {
            // Bild-Verarbeitung: Nur Orientierung korrigieren
            let finalImage = image.prepareForOCR()
            
            print("NewLeadViewModel: Bild verarbeitet - Original: \(image.size), Final: \(finalImage.size)")
            
            // 1. Finales Bild speichern (für Fallback bei OCR-Fehlern)
            do {
                let filename = try imageStorageService.saveImage(finalImage, for: leadId)
                originalImageFilename = filename
            } catch {
                print("NewLeadViewModel: Warnung - Bild konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
            
            // 2. Parallel: OCR und QR-Code-Erkennung mit finalem Bild starten
            async let ocrTask = ocrService.recognizeText(from: finalImage)
            async let qrTask = ocrService.extractQRCode(from: finalImage)
            
            let (recognizedLines, qrContent) = try await (ocrTask, qrTask)
            
            // 3. Ergebnisse verarbeiten
            var ocrContact = ParsedContact()
            var qrContact: VCardParser.VCardContact?
            
            // OCR-Daten parsen
            if !recognizedLines.isEmpty {
                ocrContact = ocrService.parseContactInfo(from: recognizedLines)
            }
            
            // QR-Code-Daten parsen (falls vorhanden)
            if let content = qrContent {
                qrCodeDetected = true
                
                // Sofortiges haptisches Feedback bei QR-Code-Erkennung
                // Gibt dem Nutzer Sicherheit, dass der Code erkannt wurde
                let qrFeedback = UINotificationFeedbackGenerator()
                qrFeedback.notificationOccurred(.success)
                
                if ocrService.isVCard(content) {
                    // vCard parsen
                    qrContact = vCardParser.parse(content)
                    print("NewLeadViewModel: vCard erkannt - \(qrContact?.name ?? "Kein Name")")
                } else if ocrService.isURL(content) {
                    // URL gefunden (z.B. LinkedIn)
                    let urlContact = vCardParser.parseURL(content)
                    qrContact = urlContact
                    qrCodeURL = content
                    print("NewLeadViewModel: URL erkannt - \(content)")
                } else {
                    // Unbekanntes Format - als Notiz speichern
                    print("NewLeadViewModel: QR-Code mit unbekanntem Format: \(content.prefix(100))")
                }
            }
            
            // 4. Daten zusammenführen (QR hat Priorität über OCR)
            let mergedContact = mergeContacts(ocr: ocrContact, qr: qrContact)
            
            // 5. Prüfen ob relevante Daten gefunden wurden
            let hasAnyData = !mergedContact.name.isEmpty || 
                             !mergedContact.company.isEmpty || 
                             !mergedContact.email.isEmpty || 
                             !mergedContact.phone.isEmpty
            
            if !hasAnyData {
                throw OCRError.noContactDataFound
            }
            
            // 6. Formularfelder aktualisieren
            let fieldsUpdated = updateFormFields(with: mergedContact, url: qrContact?.url)
            
            // 7. Erfolgsanimation triggern
            if fieldsUpdated > 0 {
                showOCRSuccessAnimation = true
                
                // Haptic Feedback (stärker wenn QR-Code erkannt)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(qrCodeDetected ? .success : .success)
                
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showOCRSuccessAnimation = false
                }
            }
            
        } catch let error as OCRError {
            errorMessage = error.userFriendlyMessage
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
        } catch {
            errorMessage = "Texterkennung fehlgeschlagen. Bitte gib die Daten manuell ein."
            showError = true
        }
        
        isProcessingImage = false
    }
    
    /// Führt OCR- und QR-Code-Daten zusammen
    /// QR-Daten haben Priorität, da sie zuverlässiger sind
    private func mergeContacts(ocr: ParsedContact, qr: VCardParser.VCardContact?) -> ParsedContact {
        guard let qrData = qr, qrData.hasData else {
            // Kein QR-Code - nur OCR-Daten verwenden
            return ocr
        }
        
        var merged = ParsedContact()
        
        // Name: QR > OCR
        merged.name = !qrData.name.isEmpty ? qrData.name : ocr.name
        
        // Firma: QR > OCR
        merged.company = !qrData.company.isEmpty ? qrData.company : ocr.company
        
        // E-Mail: QR > OCR
        merged.email = !qrData.email.isEmpty ? qrData.email : ocr.email
        
        // Telefon: QR > OCR
        merged.phone = !qrData.phone.isEmpty ? qrData.phone : ocr.phone
        
        return merged
    }
    
    /// Aktualisiert die Formularfelder mit geparsten Daten
    /// - Parameters:
    ///   - contact: Die geparsten Kontaktdaten
    ///   - url: Optionale URL (z.B. LinkedIn) aus QR-Code
    /// - Returns: Anzahl der aktualisierten Felder
    private func updateFormFields(with contact: ParsedContact, url: String? = nil) -> Int {
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
        
        // URL in Notizen speichern (falls vorhanden und Notizen leer)
        if let urlString = url, !urlString.isEmpty, notes.isEmpty {
            notes = "🔗 \(urlString)"
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
    /// Setzt automatisch die ownerId auf den aktuellen Supabase-User
    func saveLead(context: ModelContext) -> Bool {
        guard isValid else {
            errorMessage = "Bitte fülle mindestens ein Kontaktfeld aus."
            showError = true
            return false
        }
        
        isSaving = true
        
        // Owner ID: Supabase User-ID oder Fallback "local_user"
        let currentOwnerId = SupabaseManager.shared.currentUserId?.uuidString ?? "local_user"
        
        let lead = Lead(
            id: leadId,
            ownerId: currentOwnerId,
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

