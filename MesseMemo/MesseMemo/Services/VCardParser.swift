//
//  VCardParser.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 26.12.24.
//  Parser für vCard-Format (Version 3.0/4.0) aus QR-Codes
//

import Foundation

/// Parser für vCard-Daten aus QR-Codes
/// Unterstützt vCard 2.1, 3.0 und 4.0 Formate
final class VCardParser {
    
    // MARK: - Parsed Result
    
    /// Struktur für geparste vCard-Daten
    struct VCardContact {
        var name: String = ""
        var company: String = ""
        var email: String = ""
        var phone: String = ""
        var url: String = ""
        var address: String = ""
        var title: String = ""
        
        /// Prüft ob die vCard nützliche Daten enthält
        var hasData: Bool {
            !name.isEmpty || !email.isEmpty || !phone.isEmpty || !company.isEmpty
        }
    }
    
    // MARK: - Parsing
    
    /// Parst einen vCard-String und extrahiert Kontaktdaten
    /// - Parameter vCardString: Der rohe vCard-String (BEGIN:VCARD ... END:VCARD)
    /// - Returns: Extrahierte Kontaktdaten
    func parse(_ vCardString: String) -> VCardContact {
        var contact = VCardContact()
        
        // Normalisiere Zeilenumbrüche (vCards können \r\n, \n oder \r verwenden)
        let normalizedString = vCardString
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        // Handle "Folded Lines" (Zeilen, die mit Leerzeichen beginnen, gehören zur vorherigen)
        let unfoldedString = unfoldLines(normalizedString)
        
        let lines = unfoldedString.components(separatedBy: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Trenne Property von Value (Format: PROPERTY:VALUE oder PROPERTY;PARAMS:VALUE)
            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                let propertyPart = String(trimmedLine[..<colonIndex]).uppercased()
                let valuePart = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Property kann Parameter haben (z.B. TEL;TYPE=CELL:+49123...)
                let propertyName = extractPropertyName(from: propertyPart)
                let propertyParams = extractPropertyParams(from: propertyPart)
                
                switch propertyName {
                case "FN":
                    // FN = Formatted Name (bevorzugt)
                    contact.name = decodeVCardValue(valuePart)
                    
                case "N":
                    // N = Strukturierter Name (Fallback wenn FN fehlt)
                    // Format: Nachname;Vorname;Weitere Vornamen;Prefix;Suffix
                    if contact.name.isEmpty {
                        contact.name = parseStructuredName(valuePart)
                    }
                    
                case "ORG":
                    // ORG = Organisation
                    // Format: Firma;Abteilung (wir nehmen nur die Firma)
                    let orgParts = valuePart.components(separatedBy: ";")
                    contact.company = decodeVCardValue(orgParts.first ?? "")
                    
                case "EMAIL":
                    // Erste E-Mail nehmen
                    if contact.email.isEmpty {
                        contact.email = decodeVCardValue(valuePart).lowercased()
                    }
                    
                case "TEL":
                    // Bevorzuge Mobilnummern, sonst erste Nummer
                    let phone = decodeVCardValue(valuePart)
                    if contact.phone.isEmpty || isMobilePhone(propertyParams) {
                        contact.phone = cleanPhoneNumber(phone)
                    }
                    
                case "URL":
                    // URL (könnte LinkedIn, Website etc. sein)
                    if contact.url.isEmpty {
                        contact.url = decodeVCardValue(valuePart)
                    }
                    
                case "ADR":
                    // Adresse (Format: PO Box;Ext Addr;Street;City;Region;Postal;Country)
                    if contact.address.isEmpty {
                        contact.address = parseAddress(valuePart)
                    }
                    
                case "TITLE":
                    // Jobtitel
                    contact.title = decodeVCardValue(valuePart)
                    
                default:
                    break
                }
            }
        }
        
        return contact
    }
    
    /// Parst eine URL und extrahiert mögliche Kontaktinformationen
    /// - Parameter urlString: Die URL (z.B. LinkedIn-Profil)
    /// - Returns: Kontaktdaten mit URL und ggf. Domain als Firma
    func parseURL(_ urlString: String) -> VCardContact {
        var contact = VCardContact()
        contact.url = urlString
        
        // Versuche die Domain als "Firma" zu extrahieren (Fallback)
        if let url = URL(string: urlString), let host = url.host {
            // Entferne www. Prefix
            var domain = host.lowercased()
            if domain.hasPrefix("www.") {
                domain = String(domain.dropFirst(4))
            }
            
            // Bekannte Domains nicht als Firma verwenden
            let knownDomains = ["linkedin.com", "xing.com", "facebook.com", "twitter.com", "instagram.com"]
            if !knownDomains.contains(domain) {
                // Kapitalisiere ersten Buchstaben
                if let firstLetter = domain.first {
                    contact.company = String(firstLetter).uppercased() + String(domain.dropFirst())
                }
            }
        }
        
        return contact
    }
    
    // MARK: - Private Helpers
    
    /// Entfaltet "gefaltete" vCard-Zeilen (Zeilen die mit Whitespace beginnen)
    private func unfoldLines(_ text: String) -> String {
        // vCard-Folding: Lange Zeilen werden mit \n gefolgt von Whitespace umgebrochen
        var result = text
        result = result.replacingOccurrences(of: "\n ", with: "")
        result = result.replacingOccurrences(of: "\n\t", with: "")
        return result
    }
    
    /// Extrahiert den Property-Namen ohne Parameter
    private func extractPropertyName(from propertyPart: String) -> String {
        // Format: PROPERTY oder PROPERTY;PARAM1=VALUE1;PARAM2=VALUE2
        if let semicolonIndex = propertyPart.firstIndex(of: ";") {
            return String(propertyPart[..<semicolonIndex])
        }
        return propertyPart
    }
    
    /// Extrahiert die Property-Parameter
    private func extractPropertyParams(from propertyPart: String) -> [String: String] {
        var params: [String: String] = [:]
        
        guard let semicolonIndex = propertyPart.firstIndex(of: ";") else {
            return params
        }
        
        let paramsPart = String(propertyPart[propertyPart.index(after: semicolonIndex)...])
        let paramPairs = paramsPart.components(separatedBy: ";")
        
        for pair in paramPairs {
            if let equalIndex = pair.firstIndex(of: "=") {
                let key = String(pair[..<equalIndex])
                let value = String(pair[pair.index(after: equalIndex)...])
                params[key] = value
            } else {
                // Manche vCards haben nur den Typ ohne "TYPE=" (z.B. TEL;CELL:...)
                params["TYPE"] = pair
            }
        }
        
        return params
    }
    
    /// Dekodiert vCard-Escape-Sequenzen
    private func decodeVCardValue(_ value: String) -> String {
        var decoded = value
        
        // vCard Escape-Sequenzen
        decoded = decoded.replacingOccurrences(of: "\\n", with: "\n")
        decoded = decoded.replacingOccurrences(of: "\\N", with: "\n")
        decoded = decoded.replacingOccurrences(of: "\\,", with: ",")
        decoded = decoded.replacingOccurrences(of: "\\;", with: ";")
        decoded = decoded.replacingOccurrences(of: "\\:", with: ":")
        decoded = decoded.replacingOccurrences(of: "\\\\", with: "\\")
        
        // Quoted-Printable dekodieren falls vorhanden
        if decoded.contains("=") {
            decoded = decodeQuotedPrintable(decoded)
        }
        
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Dekodiert Quoted-Printable Encoding
    private func decodeQuotedPrintable(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            if char == "=" && text.distance(from: i, to: text.endIndex) >= 3 {
                let nextIndex = text.index(i, offsetBy: 1)
                let endIndex = text.index(i, offsetBy: 3)
                let hex = String(text[nextIndex..<endIndex])
                
                if let byte = UInt8(hex, radix: 16) {
                    result.append(Character(UnicodeScalar(byte)))
                    i = endIndex
                    continue
                }
            }
            
            result.append(char)
            i = text.index(after: i)
        }
        
        return result
    }
    
    /// Parst den strukturierten Namen (N-Property)
    /// Format: Nachname;Vorname;Weitere Vornamen;Prefix;Suffix
    private func parseStructuredName(_ value: String) -> String {
        let parts = value.components(separatedBy: ";").map { 
            decodeVCardValue($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !parts.isEmpty else { return "" }
        
        var nameParts: [String] = []
        
        // Vorname (Index 1) + Nachname (Index 0)
        if parts.count > 1 && !parts[1].isEmpty {
            nameParts.append(parts[1]) // Vorname
        }
        if !parts[0].isEmpty {
            nameParts.append(parts[0]) // Nachname
        }
        
        return nameParts.joined(separator: " ")
    }
    
    /// Parst eine vCard-Adresse
    /// Format: PO Box;Ext Addr;Street;City;Region;Postal;Country
    private func parseAddress(_ value: String) -> String {
        let parts = value.components(separatedBy: ";").map {
            decodeVCardValue($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var addressParts: [String] = []
        
        // Street (Index 2)
        if parts.count > 2 && !parts[2].isEmpty {
            addressParts.append(parts[2])
        }
        
        // PLZ (Index 5) + City (Index 3)
        var cityLine = ""
        if parts.count > 5 && !parts[5].isEmpty {
            cityLine = parts[5]
        }
        if parts.count > 3 && !parts[3].isEmpty {
            cityLine += cityLine.isEmpty ? parts[3] : " " + parts[3]
        }
        if !cityLine.isEmpty {
            addressParts.append(cityLine)
        }
        
        // Country (Index 6)
        if parts.count > 6 && !parts[6].isEmpty {
            addressParts.append(parts[6])
        }
        
        return addressParts.joined(separator: ", ")
    }
    
    /// Prüft ob die Telefonnummer eine Mobilnummer ist (basierend auf vCard-Parametern)
    private func isMobilePhone(_ params: [String: String]) -> Bool {
        guard let type = params["TYPE"]?.uppercased() else { return false }
        return type.contains("CELL") || type.contains("MOBILE")
    }
    
    /// Bereinigt eine Telefonnummer (entfernt Leerzeichen und Sonderzeichen)
    private func cleanPhoneNumber(_ phone: String) -> String {
        // Behalte nur Ziffern, +, und -
        let allowed = CharacterSet(charactersIn: "0123456789+-() ")
        let cleaned = phone.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(cleaned))
    }
}

// MARK: - Convenience Extension

extension VCardParser.VCardContact {
    /// Konvertiert vCard-Daten zu ParsedContact (für Integration mit OCR)
    func toParsedContact() -> ParsedContact {
        return ParsedContact(
            name: name,
            company: company,
            email: email,
            phone: phone
        )
    }
}

