//
//  NewLeadViewModel.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  LOCAL-ONLY APP:
//  Keine ownerId mehr - alle Leads gehören dem Gerät
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
    @Published var website = ""
    @Published var notes = ""
    @Published var audioFilePath: String?
    @Published var originalImageFilename: String?
    
    // MARK: - UI State
    
    @Published var showCamera = false
    @Published var isProcessingImage = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isSaving = false
    @Published var isCloudOCRRunning = false
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
    func processImage(_ image: UIImage) async {
        isProcessingImage = true
        isCloudOCRRunning = UserDefaults.standard.bool(forKey: "useCloudOCR")
        qrCodeDetected = false
        qrCodeURL = nil
        
        do {
            // Bild-Verarbeitung
            let finalImage = image.prepareForOCR()
            
            print("NewLeadViewModel: Bild verarbeitet - Original: \(image.size), Final: \(finalImage.size)")
            
            // 1. Finales Bild speichern (für Fallback bei OCR-Fehlern)
            do {
                let filename = try imageStorageService.saveImage(finalImage, for: leadId)
                originalImageFilename = filename
            } catch {
                print("NewLeadViewModel: Warnung - Bild konnte nicht gespeichert werden: \(error.localizedDescription)")
            }
            
            // 2. Parallel: OCR und QR-Code-Erkennung starten
            async let ocrTask = ocrService.recognizeText(from: finalImage)
            async let qrTask = ocrService.extractQRCode(from: finalImage)
            
            let (recognizedLines, qrContent) = try await (ocrTask, qrTask)
            
            // 3. Ergebnisse verarbeiten
            var ocrContact = ParsedContact()
            var qrContact: VCardParser.VCardContact?
            
            // OCR-Daten parsen
            if !recognizedLines.isEmpty {
                ocrContact = await ocrService.analyzeContact(from: recognizedLines)
            }
            
            // QR-Code-Daten parsen (falls vorhanden)
            if let content = qrContent {
                qrCodeDetected = true
                
                // Haptisches Feedback bei QR-Code-Erkennung
                let qrFeedback = UINotificationFeedbackGenerator()
                qrFeedback.notificationOccurred(.success)
                
                if ocrService.isVCard(content) {
                    qrContact = vCardParser.parse(content)
                    print("NewLeadViewModel: vCard erkannt - \(qrContact?.name ?? "Kein Name")")
                } else if ocrService.isURL(content) {
                    let urlContact = vCardParser.parseURL(content)
                    qrContact = urlContact
                    qrCodeURL = content
                    print("NewLeadViewModel: URL erkannt - \(content)")
                } else {
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
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(qrCodeDetected ? .success : .success)
                
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showOCRSuccessAnimation = false
                }
            }
            
            isCloudOCRRunning = false
            
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
    private func mergeContacts(ocr: ParsedContact, qr: VCardParser.VCardContact?) -> ParsedContact {
        guard let qrData = qr, qrData.hasData else {
            return ocr
        }
        
        var merged = ParsedContact()
        
        merged.name = !qrData.name.isEmpty ? qrData.name : ocr.name
        merged.company = !qrData.company.isEmpty ? qrData.company : ocr.company
        merged.email = !qrData.email.isEmpty ? qrData.email : ocr.email
        merged.phone = !qrData.phone.isEmpty ? qrData.phone : ocr.phone
        
        return merged
    }
    
    /// Aktualisiert die Formularfelder mit geparsten Daten
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
        
        // URL im Website-Feld speichern
        if let urlString = url, !urlString.isEmpty, website.isEmpty {
            website = urlString
            updatedCount += 1
        }
        
        return updatedCount
    }
    
    // MARK: - Audio Recording
    
    func startRecording() {
        do {
            audioFilePath = try audioService.startRecording(for: leadId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func stopRecording() {
        audioService.stopRecording()
    }
    
    func deleteRecording() {
        if let path = audioFilePath {
            audioService.deleteRecording(at: path)
            audioFilePath = nil
        }
    }
    
    // MARK: - Validation
    
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
            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            audioFilePath: audioFilePath,
            originalImageFilename: originalImageFilename
        )
        
        context.insert(lead)
        
        isSaving = false
        return true
    }
    
    // MARK: - Reset
    
    func reset() {
        name = ""
        company = ""
        email = ""
        phone = ""
        website = ""
        notes = ""
        
        deleteRecording()
        deleteImage()
    }
    
    func deleteImage() {
        if let filename = originalImageFilename {
            imageStorageService.deleteImage(filename: filename)
            originalImageFilename = nil
        }
    }
}
