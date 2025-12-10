//
//  OCRService.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import Vision
import UIKit

/// Service für die Texterkennung auf Visitenkarten mittels Vision Framework
final class OCRService {
    
    /// Führt die Texterkennung auf einem Bild durch
    /// - Parameter image: Das zu analysierende Bild
    /// - Returns: Array von erkannten Textzeilen
    func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings)
            }
            
            // Konfiguration für beste Ergebnisse
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    
    /// Analysiert den erkannten Text und extrahiert strukturierte Kontaktdaten
    /// - Parameter lines: Array von erkannten Textzeilen
    /// - Returns: Extrahierte Kontaktdaten als Tuple
    func parseContactInfo(from lines: [String]) -> ParsedContact {
        var contact = ParsedContact()
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // E-Mail erkennen
            if contact.email.isEmpty, let email = extractEmail(from: trimmedLine) {
                contact.email = email
                continue
            }
            
            // Telefonnummer erkennen
            if contact.phone.isEmpty, let phone = extractPhone(from: trimmedLine) {
                contact.phone = phone
                continue
            }
            
            // Website-Zeilen überspringen (enthalten oft Firmennamen, aber sind keine Namen)
            if isWebsite(trimmedLine) {
                continue
            }
            
            // Name erkennen (erste Zeile die wie ein Name aussieht)
            if contact.name.isEmpty && looksLikeName(trimmedLine) {
                contact.name = trimmedLine
                continue
            }
            
            // Firma erkennen (oft in Großbuchstaben oder mit typischen Suffixen)
            if contact.company.isEmpty && looksLikeCompany(trimmedLine) {
                contact.company = trimmedLine
                continue
            }
        }
        
        return contact
    }
    
    // MARK: - Private Hilfsmethoden
    
    private func extractEmail(from text: String) -> String? {
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    private func extractPhone(from text: String) -> String? {
        // Verschiedene Telefonnummern-Formate
        let phonePatterns = [
            #"\+?[\d\s\-\(\)]{10,}"#,  // Internationale und nationale Formate
            #"(?:Tel|Phone|Fon|Mobil|Mobile|Handy)[:\s]*[\d\s\-\(\)\+]+"#  // Mit Präfix
        ]
        
        for pattern in phonePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                var phoneNumber = String(text[Range(match.range, in: text)!])
                // Präfix entfernen falls vorhanden
                phoneNumber = phoneNumber.replacingOccurrences(of: #"(?:Tel|Phone|Fon|Mobil|Mobile|Handy)[:\s]*"#, with: "", options: .regularExpression)
                return phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
    
    private func isWebsite(_ text: String) -> Bool {
        let websitePattern = #"(?:www\.|https?://|\.com|\.de|\.org|\.net)"#
        guard let regex = try? NSRegularExpression(pattern: websitePattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    private func looksLikeName(_ text: String) -> Bool {
        // Ein Name besteht typischerweise aus 2-4 Wörtern, jedes mit Großbuchstaben am Anfang
        let words = text.split(separator: " ")
        
        guard words.count >= 2 && words.count <= 5 else { return false }
        
        // Prüfen ob es wie ein Name aussieht (keine Sonderzeichen außer Bindestriche)
        let namePattern = #"^[A-ZÄÖÜ][a-zäöüß]+(?:\s+[A-ZÄÖÜ][a-zäöüß]+)+$"#
        guard let regex = try? NSRegularExpression(pattern: namePattern, options: []) else {
            return false
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    private func looksLikeCompany(_ text: String) -> Bool {
        // Typische Firmen-Suffixe
        let companySuffixes = ["GmbH", "AG", "SE", "KG", "OHG", "e.V.", "Inc.", "Corp.", "Ltd.", "LLC", "Co.", "& Co"]
        
        for suffix in companySuffixes {
            if text.localizedCaseInsensitiveContains(suffix) {
                return true
            }
        }
        
        // Komplett in Großbuchstaben (oft Logos/Firmennamen)
        if text.count > 3 && text == text.uppercased() && text.rangeOfCharacter(from: .letters) != nil {
            return true
        }
        
        return false
    }
}

// MARK: - Datenstrukturen

/// Struktur für geparste Kontaktdaten
struct ParsedContact {
    var name: String = ""
    var company: String = ""
    var email: String = ""
    var phone: String = ""
}

/// Fehlertypen für OCR
enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Das Bild konnte nicht verarbeitet werden."
        case .recognitionFailed(let reason):
            return "Texterkennung fehlgeschlagen: \(reason)"
        }
    }
}

