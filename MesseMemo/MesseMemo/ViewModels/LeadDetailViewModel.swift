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
import Contacts
import ContactsUI

/// ViewModel für die Detailansicht eines Leads
@MainActor
final class LeadDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let lead: Lead
    let audioService = AudioService()
    let transcriptionManager = TranscriptionManager()
    private let imageStorageService = ImageStorageService.shared
    
    // MARK: - Published Properties
    
    @Published var isEditing = false
    @Published var showDeleteConfirmation = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showMailComposer = false
    @Published var isTranscribing = false
    @Published var showTranscriptionSuccess = false
    
    // AI Email Generation
    @Published var isGeneratingEmail = false
    @Published var showAIMailComposer = false
    @Published var generatedAIEmail: GeneratedEmail?
    
    // Original Image
    @Published var originalImage: UIImage?
    @Published var isLoadingImage = false
    @Published var showOriginalImageFullscreen = false
    
    // Audio Recording (Binding für AudioRecorderView)
    @Published var audioFilePath: String? {
        didSet {
            // Synchronisiere mit Lead
            lead.audioFilePath = audioFilePath
            lead.updatedAt = Date()
        }
    }
    
    // MARK: - Edit Mode Properties
    
    @Published var editName = ""
    @Published var editCompany = ""
    @Published var editEmail = ""
    @Published var editPhone = ""
    @Published var editNotes = ""
    @Published var editTranscript = ""
    
    // MARK: - Initialization
    
    init(lead: Lead) {
        self.lead = lead
        self.audioFilePath = lead.audioFilePath // Initialisiere mit aktuellem Wert
        loadEditFields()
        
        // Originalbild laden (asynchron)
        Task {
            await loadOriginalImage()
        }
    }
    
    // MARK: - Edit Mode
    
    /// Lädt die aktuellen Werte in die Bearbeitungsfelder
    func loadEditFields() {
        editName = lead.name
        editCompany = lead.company
        editEmail = lead.email
        editPhone = lead.phone
        editNotes = lead.notes
        editTranscript = lead.transcript ?? ""
    }
    
    /// Speichert die Änderungen
    func saveChanges() {
        lead.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.company = editCompany.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.email = editEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lead.phone = editPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        lead.transcript = editTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    // MARK: - Audio Recording (für bestehende Kontakte)
    
    /// Temporärer Dateiname während der Aufnahme
    private var pendingAudioFilename: String?
    
    /// Startet eine neue Audioaufnahme für diesen Lead
    func startRecording() {
        do {
            // Starte Aufnahme und speichere Dateinamen temporär
            let filename = try audioService.startRecording(for: lead.id)
            pendingAudioFilename = filename
            
            // Haptic Feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    /// Stoppt die aktuelle Aufnahme
    func stopRecording() {
        audioService.stopRecording()
        
        // Setze den Dateipfad erst NACH dem Stoppen (Datei existiert jetzt)
        if let filename = pendingAudioFilename {
            audioFilePath = filename
            pendingAudioFilename = nil
        }
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Audio Delete
    
    /// Löscht die Audio-Notiz des Leads
    func deleteAudio() {
        guard let audioPath = audioFilePath else { return }
        
        // Stoppe eventuelle Wiedergabe
        audioService.stopPlayback()
        
        // Datei physisch löschen
        audioService.deleteRecording(at: audioPath)
        
        // Binding und Lead aktualisieren (didSet synchronisiert mit Lead)
        audioFilePath = nil
        lead.transcript = nil
        
        // Edit-Felder aktualisieren
        editTranscript = ""
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
    
    // MARK: - Transcription
    
    /// Startet die Transkription der Audio-Notiz
    func transcribeAudio() async {
        guard let audioPath = lead.audioFilePath else {
            errorMessage = "Keine Audio-Notiz vorhanden."
            showError = true
            return
        }
        
        isTranscribing = true
        
        do {
            let transcript = try await transcriptionManager.transcribe(audioPath: audioPath)
            lead.transcript = transcript
            lead.updatedAt = Date()
            editTranscript = transcript
            showTranscriptionSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isTranscribing = false
    }
    
    // MARK: - Actions
    
    /// Öffnet die E-Mail-App (einfaches mailto:)
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
    
    /// Öffnet LinkedIn-Suche für diesen Kontakt
    func openLinkedIn() {
        guard let url = lead.linkedInSearchURL else {
            errorMessage = "Kein Name oder Firma vorhanden für die LinkedIn-Suche."
            showError = true
            return
        }
        UIApplication.shared.open(url)
    }
    
    /// Kopiert alle Kontaktdaten in die Zwischenablage
    func copyToClipboard() {
        var text = ""
        if !lead.name.isEmpty { text += "Name: \(lead.name)\n" }
        if !lead.company.isEmpty { text += "Firma: \(lead.company)\n" }
        if !lead.email.isEmpty { text += "E-Mail: \(lead.email)\n" }
        if !lead.phone.isEmpty { text += "Telefon: \(lead.phone)\n" }
        if !lead.notes.isEmpty { text += "Notizen: \(lead.notes)\n" }
        if let transcript = lead.transcript, !transcript.isEmpty {
            text += "Transkript: \(transcript)"
        }
        
        UIPasteboard.general.string = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Mail Composer
    
    /// Generiert die Follow-Up Mail Daten
    var followUpMailData: (recipients: [String], subject: String, body: String) {
        let mail = FollowUpMailGenerator.generateFollowUpMail(for: lead)
        let recipients = lead.email.isEmpty ? [] : [lead.email]
        return (recipients, mail.subject, mail.body)
    }
    
    /// Prüft ob Mail-Composer verfügbar ist
    var canSendMail: Bool {
        MailComposerView.canSendMail
    }
    
    // MARK: - AI Email Generation
    
    /// Generiert eine KI-basierte Follow-Up E-Mail
    /// Verbraucht 1 Credit lokal bei Erfolg
    func generateAIEmail() async {
        isGeneratingEmail = true
        
        // Haptic Feedback für Start
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Credit prüfen und verbrauchen
        guard SubscriptionManager.shared.useCredit() else {
            errorMessage = "Kein Guthaben mehr. Bitte lade dein Konto auf, um weitere Mails zu generieren."
            showError = true
            isGeneratingEmail = false
            return
        }
        
        do {
            // Generiere E-Mail via Supabase Edge Function
            let email = try await SupabaseManager.shared.generateEmail(
                name: lead.name,
                company: lead.company,
                transcript: lead.transcript ?? lead.notes
            )
            
            generatedAIEmail = email
            showAIMailComposer = true
            
            // Erfolgs-Feedback
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            
        } catch {
            // Credit zurückgeben bei Fehler
            SubscriptionManager.shared.addCredits(1)
            
            // Error-Feedback
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            
            // Benutzerfreundliche Fehlermeldung
            if let supabaseError = error as? SupabaseError {
                switch supabaseError {
                case .emailGenerationFailed(let reason):
                    errorMessage = "E-Mail konnte nicht generiert werden: \(reason)"
                case .networkError:
                    errorMessage = "Keine Internetverbindung. KI-Funktionen benötigen eine aktive Verbindung."
                }
            } else if error.localizedDescription.lowercased().contains("network") ||
                      error.localizedDescription.lowercased().contains("internet") ||
                      error.localizedDescription.lowercased().contains("offline") {
                errorMessage = "Keine Internetverbindung. KI-Funktionen benötigen eine aktive Verbindung."
            } else {
                errorMessage = "Die E-Mail konnte nicht generiert werden. Bitte versuche es später erneut."
            }
            showError = true
        }
        
        isGeneratingEmail = false
    }
    
    // MARK: - Original Image
    
    /// Lädt das Originalbild der Visitenkarte asynchron
    func loadOriginalImage() async {
        guard let filename = lead.originalImageFilename else {
            return
        }
        
        isLoadingImage = true
        
        if let image = await imageStorageService.loadImage(filename: filename) {
            originalImage = image
        }
        
        isLoadingImage = false
    }
    
    /// Löscht das Originalbild
    func deleteOriginalImage() {
        guard let filename = lead.originalImageFilename else { return }
        
        imageStorageService.deleteImage(filename: filename)
        lead.originalImageFilename = nil
        lead.updatedAt = Date()
        originalImage = nil
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - iOS Contacts Integration
    
    /// Erstellt ein CNMutableContact aus den Lead-Daten
    func createContact() -> CNMutableContact {
        let contact = CNMutableContact()
        
        // Name aufteilen (Vorname Nachname)
        let nameParts = lead.name.split(separator: " ", maxSplits: 1)
        if nameParts.count >= 2 {
            contact.givenName = String(nameParts[0])
            contact.familyName = String(nameParts[1])
        } else if !lead.name.isEmpty {
            contact.givenName = lead.name
        }
        
        // Firma
        if !lead.company.isEmpty {
            contact.organizationName = lead.company
        }
        
        // E-Mail
        if !lead.email.isEmpty {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: lead.email as NSString)
            ]
        }
        
        // Telefon
        if !lead.phone.isEmpty {
            contact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: lead.phone))
            ]
        }
        
        // Website
        if !lead.website.isEmpty {
            contact.urlAddresses = [
                CNLabeledValue(label: CNLabelWork, value: lead.website as NSString)
            ]
        }
        
        // Notizen
        if !lead.notes.isEmpty {
            contact.note = lead.notes
        }
        
        // Bild (falls vorhanden)
        if let image = originalImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            contact.imageData = imageData
        }
        
        return contact
    }
    
    /// Speichert den Lead direkt als iOS-Kontakt
    func saveAsContact() -> Bool {
        let contact = createContact()
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        
        do {
            let store = CNContactStore()
            try store.execute(saveRequest)
            
            // Erfolgs-Feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            return true
        } catch {
            errorMessage = "Kontakt konnte nicht gespeichert werden: \(error.localizedDescription)"
            showError = true
            return false
        }
    }
    
    /// Prüft ob Kontakte-Zugriff erlaubt ist
    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        
        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted
        } catch {
            return false
        }
    }
}
