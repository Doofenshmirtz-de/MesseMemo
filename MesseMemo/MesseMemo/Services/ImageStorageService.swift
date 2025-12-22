//
//  ImageStorageService.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 22.12.25.
//

import Foundation
import UIKit

/// Service für die Speicherung und das Laden von Bildern im Documents Directory
final class ImageStorageService {
    
    // MARK: - Singleton
    
    static let shared = ImageStorageService()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Unterordner für Visitenkarten-Fotos
    private let imageFolder = "BusinessCardImages"
    
    /// JPEG-Komprimierungsqualität (0.0 - 1.0)
    private let compressionQuality: CGFloat = 0.7
    
    // MARK: - Directory Management
    
    /// Gibt die URL zum Bilder-Ordner zurück und erstellt ihn falls nötig
    private var imagesDirectoryURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesURL = documentsURL.appendingPathComponent(imageFolder)
        
        // Ordner erstellen falls nicht vorhanden
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        }
        
        return imagesURL
    }
    
    // MARK: - Save Image
    
    /// Speichert ein UIImage als JPEG im Documents Directory
    /// - Parameters:
    ///   - image: Das zu speichernde Bild
    ///   - leadId: Die ID des zugehörigen Leads (für eindeutigen Dateinamen)
    /// - Returns: Der Dateiname (relativ zum Documents Directory)
    func saveImage(_ image: UIImage, for leadId: UUID) throws -> String {
        // Bild komprimieren
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw ImageStorageError.compressionFailed
        }
        
        // Eindeutigen Dateinamen generieren
        let filename = "\(imageFolder)/card_\(leadId.uuidString).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        // Sicherstellen, dass der Ordner existiert
        _ = imagesDirectoryURL
        
        // Bild speichern
        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            throw ImageStorageError.saveFailed(error)
        }
    }
    
    // MARK: - Load Image
    
    /// Lädt ein Bild asynchron aus dem Documents Directory
    /// - Parameter filename: Der Dateiname (relativ zum Documents Directory)
    /// - Returns: Das geladene UIImage oder nil
    func loadImage(filename: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsURL.appendingPathComponent(filename)
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let data = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    /// Lädt ein Bild synchron aus dem Documents Directory
    /// - Parameter filename: Der Dateiname (relativ zum Documents Directory)
    /// - Returns: Das geladene UIImage oder nil
    func loadImageSync(filename: String) -> UIImage? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    // MARK: - Delete Image
    
    /// Löscht ein Bild aus dem Documents Directory
    /// - Parameter filename: Der Dateiname (relativ zum Documents Directory)
    /// - Returns: true wenn erfolgreich gelöscht, false sonst
    @discardableResult
    func deleteImage(filename: String) -> Bool {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("ImageStorageService: Fehler beim Löschen: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Check Image Exists
    
    /// Prüft ob ein Bild existiert
    /// - Parameter filename: Der Dateiname (relativ zum Documents Directory)
    /// - Returns: true wenn das Bild existiert
    func imageExists(filename: String) -> Bool {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Cleanup
    
    /// Löscht alle Bilder, die keinem Lead mehr zugeordnet sind
    /// - Parameter activeFilenames: Liste der aktuell genutzten Dateinamen
    func cleanupOrphanedImages(activeFilenames: Set<String>) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagesURL = documentsURL.appendingPathComponent(imageFolder)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in files {
            let relativePath = "\(imageFolder)/\(fileURL.lastPathComponent)"
            if !activeFilenames.contains(relativePath) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

// MARK: - Errors

enum ImageStorageError: Error, LocalizedError {
    case compressionFailed
    case saveFailed(Error)
    case loadFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Das Bild konnte nicht komprimiert werden."
        case .saveFailed(let error):
            return "Das Bild konnte nicht gespeichert werden: \(error.localizedDescription)"
        case .loadFailed:
            return "Das Bild konnte nicht geladen werden."
        case .notFound:
            return "Das Bild wurde nicht gefunden."
        }
    }
}

