//
//  CSVExportService.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation

/// Service für den CSV-Export von Leads
final class CSVExportService {
    
    /// Exportiert ein Array von Leads als CSV-String
    /// - Parameter leads: Die zu exportierenden Leads
    /// - Returns: CSV formatierter String
    func exportToCSV(leads: [Lead]) -> String {
        var csv = ""
        
        // Header-Zeile
        let headers = [
            "Name",
            "Firma",
            "E-Mail",
            "Telefon",
            "Notizen",
            "Hat Audio-Notiz",
            "Erfasst am"
        ]
        csv += headers.joined(separator: ";") + "\n"
        
        // Daten-Zeilen
        for lead in leads {
            let row = [
                escapeCSV(lead.name),
                escapeCSV(lead.company),
                escapeCSV(lead.email),
                escapeCSV(lead.phone),
                escapeCSV(lead.notes),
                lead.hasAudioNote ? "Ja" : "Nein",
                formatDate(lead.createdAt)
            ]
            csv += row.joined(separator: ";") + "\n"
        }
        
        return csv
    }
    
    /// Erstellt eine temporäre CSV-Datei für den Export
    /// - Parameter leads: Die zu exportierenden Leads
    /// - Returns: URL zur temporären CSV-Datei
    func createCSVFile(from leads: [Lead]) throws -> URL {
        let csvString = exportToCSV(leads: leads)
        
        // Temporäre Datei erstellen
        let fileName = "MesseMemo_Export_\(formatDateForFileName(Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Mit UTF-8 BOM für bessere Excel-Kompatibilität
        let bom = "\u{FEFF}"
        let dataString = bom + csvString
        
        guard let data = dataString.data(using: .utf8) else {
            throw CSVExportError.encodingFailed
        }
        
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Private Helpers
    
    /// Escaped einen String für CSV (Anführungszeichen und Semikolons)
    private func escapeCSV(_ value: String) -> String {
        var escaped = value
        
        // Zeilenumbrüche durch Leerzeichen ersetzen
        escaped = escaped.replacingOccurrences(of: "\n", with: " ")
        escaped = escaped.replacingOccurrences(of: "\r", with: " ")
        
        // Wenn der String Semikolons, Anführungszeichen oder Kommas enthält, in Anführungszeichen setzen
        if escaped.contains(";") || escaped.contains("\"") || escaped.contains(",") {
            // Anführungszeichen verdoppeln
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
            escaped = "\"\(escaped)\""
        }
        
        return escaped
    }
    
    /// Formatiert ein Datum für den CSV-Export
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
    
    /// Formatiert ein Datum für den Dateinamen
    private func formatDateForFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum CSVExportError: Error, LocalizedError {
    case encodingFailed
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Die Daten konnten nicht codiert werden."
        case .writeFailed:
            return "Die CSV-Datei konnte nicht erstellt werden."
        }
    }
}

