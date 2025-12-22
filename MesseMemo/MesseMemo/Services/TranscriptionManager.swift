//
//  TranscriptionManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import Speech
import AVFoundation
import Observation

/// Manager für Speech-to-Text Transkription mittels Apple's SFSpeechRecognizer
@Observable
final class TranscriptionManager {
    
    // MARK: - Properties
    
    var isTranscribing = false
    var transcriptionProgress: Double = 0
    var permissionGranted = false
    var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Initialization
    
    init() {
        // Deutsch als primäre Sprache, Fallback auf Englisch
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        checkPermission()
    }
    
    // MARK: - Permission Handling
    
    /// Prüft die Spracherkennungs-Berechtigung
    func checkPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            permissionGranted = true
        case .denied, .restricted:
            permissionGranted = false
        case .notDetermined:
            requestPermission()
        @unknown default:
            permissionGranted = false
        }
    }
    
    /// Fordert die Spracherkennungs-Berechtigung an
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = (status == .authorized)
            }
        }
    }
    
    // MARK: - Transcription
    
    /// Transkribiert eine Audio-Datei zu Text
    /// - Parameter audioPath: Relativer Pfad zur Audio-Datei im Documents-Verzeichnis
    /// - Returns: Der transkribierte Text
    @MainActor
    func transcribe(audioPath: String) async throws -> String {
        guard permissionGranted else {
            throw TranscriptionError.permissionDenied
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        
        // Audio-URL erstellen
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(audioPath)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        isTranscribing = true
        transcriptionProgress = 0
        errorMessage = nil
        
        defer {
            isTranscribing = false
            transcriptionProgress = 1.0
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.addsPunctuation = true
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.recognitionTask = nil
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let result = result else {
                        self?.recognitionTask = nil
                        continuation.resume(throwing: TranscriptionError.noResult)
                        return
                    }
                    
                    // Progress simulieren (da SFSpeechRecognizer keinen echten Progress liefert)
                    self?.transcriptionProgress = result.isFinal ? 1.0 : 0.5
                    
                    if result.isFinal {
                        self?.recognitionTask = nil
                        let transcript = result.bestTranscription.formattedString
                        continuation.resume(returning: transcript)
                    }
                }
            }
        }
    }
    
    /// Bricht die laufende Transkription ab
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
        transcriptionProgress = 0
    }
}

// MARK: - Errors

enum TranscriptionError: Error, LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case fileNotFound
    case transcriptionFailed(String)
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Spracherkennung nicht erlaubt. Bitte aktiviere den Zugriff in den Einstellungen."
        case .recognizerUnavailable:
            return "Spracherkennung ist derzeit nicht verfügbar."
        case .fileNotFound:
            return "Die Audio-Datei wurde nicht gefunden."
        case .transcriptionFailed(let reason):
            return "Transkription fehlgeschlagen: \(reason)"
        case .noResult:
            return "Kein Text erkannt. Bitte versuche es mit einer deutlicheren Aufnahme."
        }
    }
}
