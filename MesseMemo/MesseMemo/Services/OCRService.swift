//
//  OCRService.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//  Verbesserte Version mit NSDataDetector und intelligenter Parsing-Logik
//

import Foundation
import Vision
import UIKit

/// Service für die Texterkennung auf Visitenkarten mittels Vision Framework
/// Nutzt NSDataDetector für zuverlässigere Erkennung von E-Mails und Telefonnummern
final class OCRService {
    
    // MARK: - Configuration
    
    /// Akademische Titel, die vor Namen stehen können
    private let academicTitles = [
        "Dr.", "Prof.", "Prof. Dr.", "Dr.-Ing.", "Dipl.-Ing.", "Dipl.-Kfm.",
        "Dr. med.", "Dr. jur.", "Dr. rer. nat.", "Dr. phil.", "MBA", "M.Sc.", "B.Sc.",
        "Mag.", "DI", "Ing.", "RA", "StB", "WP"
    ]
    
    /// Job-Titel, die auf Visitenkarten erscheinen (diese Zeilen sind KEINE Namen)
    private let jobTitles = [
        "CEO", "CTO", "CFO", "COO", "CMO", "CIO",
        "Geschäftsführer", "Geschäftsführerin", "Managing Director",
        "Vorstand", "Vorstandsvorsitzender", "Vorstandsvorsitzende",
        "Director", "Manager", "Senior Manager", "Partner",
        "Head of", "Leiter", "Leiterin", "Abteilungsleiter",
        "Sales", "Marketing", "Vertrieb", "Account", "Berater", "Consultant",
        "Engineer", "Developer", "Designer", "Architect",
        "Assistant", "Assistentin", "Sekretär", "Sekretärin",
        "Projektleiter", "Projektmanager", "Team Lead"
    ]
    
    /// Firmen-Suffixe für zuverlässige Firmenerkennung
    private let companySuffixes = [
        // Deutsch
        "GmbH", "GmbH & Co. KG", "GmbH & Co. KGaA", "AG", "SE", "KG", "OHG", "e.V.", "e.G.",
        "mbH", "UG", "UG (haftungsbeschränkt)", "KGaA", "PartG", "PartGmbB",
        // International
        "Inc.", "Inc", "Corp.", "Corp", "Corporation", "Ltd.", "Ltd", "Limited",
        "LLC", "LLP", "Co.", "Co", "& Co.", "& Co", "PLC", "S.A.", "S.L.", "B.V.", "N.V.",
        "Pty Ltd", "Pty", "SRL", "SpA", "SARL", "SAS"
    ]
    
    /// Wörter, die auf Adressen hindeuten
    private let addressIndicators = [
        "Straße", "Str.", "Strasse", "Weg", "Platz", "Allee", "Ring", "Gasse",
        "Street", "St.", "Road", "Rd.", "Avenue", "Ave.", "Boulevard", "Blvd.",
        "PLZ", "Postfach", "PO Box"
    ]
    
    // MARK: - Data Detectors
    
    private lazy var emailDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()
    
    private lazy var phoneDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    }()
    
    // MARK: - Text Recognition
    
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
                
                // Sortiere nach Y-Position (oben nach unten)
                let sortedObservations = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                
                let recognizedStrings = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings)
            }
            
            // Optimierte Konfiguration für Visitenkarten
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US", "fr-FR"]
            request.usesLanguageCorrection = true
            request.revision = VNRecognizeTextRequestRevision3 // Neueste Version
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Contact Parsing
    
    /// Analysiert den erkannten Text und extrahiert strukturierte Kontaktdaten
    /// Verbesserte Version mit NSDataDetector und Positionsanalyse
    /// - Parameter lines: Array von erkannten Textzeilen
    /// - Returns: Extrahierte Kontaktdaten
    func parseContactInfo(from lines: [String]) -> ParsedContact {
        var contact = ParsedContact()
        
        // Sammle alle Kandidaten
        var emailCandidates: [String] = []
        var phoneCandidates: [String] = []
        var nameCandidates: [(text: String, score: Int, position: Int)] = []
        var companyCandidates: [(text: String, score: Int)] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // 1. E-Mails extrahieren (NSDataDetector + Fallback Regex)
            let emails = extractEmails(from: trimmedLine)
            emailCandidates.append(contentsOf: emails)
            
            // 2. Telefonnummern extrahieren (NSDataDetector + Fallback Regex)
            let phones = extractPhoneNumbers(from: trimmedLine)
            phoneCandidates.append(contentsOf: phones)
            
            // 3. Überspringen wenn Zeile eine URL, Adresse oder E-Mail/Telefon enthält
            if isWebsite(trimmedLine) || isAddress(trimmedLine) {
                continue
            }
            if !emails.isEmpty || !phones.isEmpty {
                continue
            }
            
            // 4. Firmen erkennen
            let companyScore = calculateCompanyScore(trimmedLine)
            if companyScore > 0 {
                companyCandidates.append((trimmedLine, companyScore))
            }
            
            // 5. Namen erkennen
            let nameScore = calculateNameScore(trimmedLine, position: index)
            if nameScore > 0 && !isJobTitle(trimmedLine) {
                nameCandidates.append((trimmedLine, nameScore, index))
            }
        }
        
        // Wähle die besten Kandidaten aus
        
        // E-Mail: Erste gefundene (meist die Haupt-E-Mail)
        if let email = emailCandidates.first {
            contact.email = email.lowercased()
        }
        
        // Telefon: Bevorzuge Mobilnummern
        contact.phone = selectBestPhone(from: phoneCandidates)
        
        // Name: Höchster Score, bevorzuge obere Position
        if let bestName = nameCandidates.sorted(by: { 
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.position < $1.position
        }).first {
            contact.name = cleanupName(bestName.text)
        }
        
        // Firma: Höchster Score
        if let bestCompany = companyCandidates.sorted(by: { $0.score > $1.score }).first {
            contact.company = bestCompany.text
        }
        
        return contact
    }
    
    // MARK: - Email Extraction
    
    /// Extrahiert E-Mail-Adressen aus Text
    private func extractEmails(from text: String) -> [String] {
        var emails: [String] = []
        
        // Methode 1: NSDataDetector (für mailto: Links)
        if let detector = emailDetector {
            let range = NSRange(text.startIndex..., in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, let url = match.url, url.scheme == "mailto" {
                    let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    emails.append(email)
                }
            }
        }
        
        // Methode 2: Regex Fallback (für reine E-Mail-Adressen)
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, let matchRange = Range(match.range, in: text) {
                    let email = String(text[matchRange])
                    if !emails.contains(email.lowercased()) {
                        emails.append(email)
                    }
                }
            }
        }
        
        return emails
    }
    
    // MARK: - Phone Extraction
    
    /// Extrahiert Telefonnummern aus Text
    private func extractPhoneNumbers(from text: String) -> [String] {
        var phones: [String] = []
        
        // Methode 1: NSDataDetector
        if let detector = phoneDetector {
            let range = NSRange(text.startIndex..., in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, let phoneNumber = match.phoneNumber {
                    phones.append(phoneNumber)
                }
            }
        }
        
        // Methode 2: Regex Fallback für deutsche/internationale Formate
        if phones.isEmpty {
            let phonePatterns = [
                // Internationale Formate
                #"\+\d{1,3}[\s\-]?\d{2,4}[\s\-]?\d{3,4}[\s\-]?\d{2,4}"#,
                // Deutsche Formate
                #"0\d{2,4}[\s\-/]?\d{3,8}"#,
                // Mit Klammern
                #"\(\d{2,5}\)[\s\-]?\d{3,10}"#,
                // Einfache Zahlenfolge (mindestens 8 Ziffern)
                #"(?:Tel|Phone|Fon|Mobil|Mobile|Handy|Telefon)[:\s]*[\d\s\-\(\)\+/]{8,}"#
            ]
            
            for pattern in phonePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..., in: text)
                    if let match = regex.firstMatch(in: text, options: [], range: range),
                       let matchRange = Range(match.range, in: text) {
                        var phone = String(text[matchRange])
                        // Präfix entfernen
                        phone = phone.replacingOccurrences(
                            of: #"(?:Tel|Phone|Fon|Mobil|Mobile|Handy|Telefon)[:\s]*"#,
                            with: "",
                            options: .regularExpression
                        )
                        phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !phone.isEmpty && phone.filter({ $0.isNumber }).count >= 8 {
                            phones.append(phone)
                        }
                    }
                }
            }
        }
        
        return phones
    }
    
    /// Wählt die beste Telefonnummer aus (bevorzugt Mobilnummern)
    private func selectBestPhone(from phones: [String]) -> String {
        // Bevorzuge Mobilnummern (beginnen mit +49 1 oder 01)
        for phone in phones {
            let digits = phone.filter { $0.isNumber }
            if digits.hasPrefix("491") || digits.hasPrefix("01") {
                return phone
            }
        }
        
        // Sonst erste Nummer
        return phones.first ?? ""
    }
    
    // MARK: - Name Detection
    
    /// Berechnet einen Score, wie wahrscheinlich der Text ein Name ist
    private func calculateNameScore(_ text: String, position: Int) -> Int {
        var score = 0
        let words = text.split(separator: " ").map(String.init)
        
        // Keine Namen: zu kurz oder zu lang
        guard words.count >= 2 && words.count <= 6 else { return 0 }
        
        // Keine Namen: enthält Zahlen
        if text.rangeOfCharacter(from: .decimalDigits) != nil { return 0 }
        
        // Keine Namen: zu viele Sonderzeichen
        let specialChars = text.filter { !$0.isLetter && !$0.isWhitespace && $0 != "-" && $0 != "." }
        if specialChars.count > 2 { return 0 }
        
        // Bonus: Enthält akademischen Titel
        for title in academicTitles {
            if text.contains(title) {
                score += 30
                break
            }
        }
        
        // Bonus: Jedes Wort beginnt mit Großbuchstaben (CamelCase)
        let capitalizedWords = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase
        }
        if capitalizedWords.count == words.count {
            score += 20
        }
        
        // Bonus: Position im oberen Drittel der Visitenkarte
        if position < 3 {
            score += 15
        }
        
        // Bonus: Typische Namenslänge (2-3 Wörter)
        if words.count >= 2 && words.count <= 3 {
            score += 10
        }
        
        // Bonus: Enthält Bindestrich (Doppelnamen)
        if text.contains("-") {
            score += 5
        }
        
        // Malus: Enthält typische Nicht-Name-Wörter
        let lowercaseText = text.lowercased()
        let nonNameWords = ["straße", "str.", "platz", "gmbh", "ag", "ug", "tel", "fax", "www", "http"]
        for word in nonNameWords {
            if lowercaseText.contains(word) {
                return 0
            }
        }
        
        // Mindest-Score für gültige Namen
        return score >= 15 ? score : 0
    }
    
    /// Bereinigt erkannte Namen (entfernt Titel am Ende etc.)
    private func cleanupName(_ name: String) -> String {
        var cleanName = name
        
        // Entferne Jobtitel am Ende
        for title in jobTitles {
            if cleanName.hasSuffix(title) || cleanName.hasSuffix(", \(title)") {
                cleanName = cleanName.replacingOccurrences(of: ", \(title)", with: "")
                cleanName = cleanName.replacingOccurrences(of: " \(title)", with: "")
            }
        }
        
        return cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Prüft ob der Text ein Jobtitel ist
    private func isJobTitle(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        for title in jobTitles {
            if lowercaseText.contains(title.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Company Detection
    
    /// Berechnet einen Score, wie wahrscheinlich der Text ein Firmenname ist
    private func calculateCompanyScore(_ text: String) -> Int {
        var score = 0
        
        // Bonus: Enthält Firmen-Suffix
        for suffix in companySuffixes {
            if text.localizedCaseInsensitiveContains(suffix) {
                score += 50
                break
            }
        }
        
        // Bonus: Komplett in Großbuchstaben (oft Logos)
        if text.count > 3 && text == text.uppercased() && text.rangeOfCharacter(from: .letters) != nil {
            score += 25
        }
        
        // Bonus: Enthält & oder + (oft in Firmennamen)
        if text.contains("&") || text.contains("+") {
            score += 10
        }
        
        // Malus: Sieht aus wie ein Name
        let nameScore = calculateNameScore(text, position: 99)
        if nameScore > 20 && score < 40 {
            score = 0
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    /// Prüft ob der Text eine URL/Website ist
    private func isWebsite(_ text: String) -> Bool {
        let websitePatterns = [
            #"(?:www\.)"#,
            #"(?:https?://)"#,
            #"(?:\.[a-z]{2,4}(?:/|$))"#  // .de, .com etc.
        ]
        
        for pattern in websitePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Prüft ob der Text eine Adresse ist
    private func isAddress(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        for indicator in addressIndicators {
            if lowercaseText.contains(indicator.lowercased()) {
                return true
            }
        }
        
        // Enthält PLZ-Format (5 Ziffern gefolgt von Stadt)
        let plzPattern = #"\d{5}\s+[A-ZÄÖÜ]"#
        if let regex = try? NSRegularExpression(pattern: plzPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
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
    case noTextFound
    case noContactDataFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Das Bild konnte nicht verarbeitet werden."
        case .recognitionFailed(let reason):
            return "Texterkennung fehlgeschlagen: \(reason)"
        case .noTextFound:
            return "Kein Text erkannt."
        case .noContactDataFound:
            return "Keine Kontaktdaten erkannt."
        }
    }
    
    /// Benutzerfreundliche Fehlermeldung für UI
    var userFriendlyMessage: String {
        switch self {
        case .invalidImage:
            return "Das Bild konnte nicht verarbeitet werden. Bitte versuche es erneut."
        case .recognitionFailed:
            return "Die Texterkennung ist fehlgeschlagen. Bitte versuche es erneut oder gib die Daten manuell ein."
        case .noTextFound:
            return "Kein Text auf der Visitenkarte erkannt. Bitte versuche es erneut mit besserer Beleuchtung oder gib die Daten manuell ein."
        case .noContactDataFound:
            return "Es konnten keine Kontaktdaten (Name, E-Mail, Telefon) erkannt werden. Bitte gib die Daten manuell ein."
        }
    }
}
