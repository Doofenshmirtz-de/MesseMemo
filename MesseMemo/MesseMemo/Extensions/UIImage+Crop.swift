//
//  UIImage+Crop.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 26.12.24.
//
//  Robuste Extension zum Zuschneiden von Kamera-Bildern.
//
//  PROBLEM:
//  - Kamera-Sensor nimmt 4:3 auf
//  - Screen ist ~19.5:9 (iPhone)
//  - Vorschau nutzt AspectFill → zeigt nur Ausschnitt
//  - Gespeichertes Foto zeigt mehr als die Vorschau
//
//  LÖSUNG:
//  1. fixOrientation() - Bild physisch rotieren (CGImage braucht korrekte Orientierung)
//  2. cropToAspectRatio() - Auf Bildschirm-Ratio zuschneiden
//  3. cropToCenter() - Optional: Nur den mittleren Bereich (z.B. das Scan-Rechteck)
//

import UIKit

extension UIImage {
    
    // MARK: - Fix Orientation
    
    /// Dreht das Bild physisch in die korrekte Ausrichtung (Up)
    /// Wichtig für CoreGraphics-basierte Operationen, da CGImage keine Orientierung kennt
    /// - Returns: Neu gezeichnetes Bild mit Orientierung .up
    func fixOrientation() -> UIImage {
        // Bereits korrekt orientiert
        if imageOrientation == .up {
            return self
        }
        
        // Neue Größe basierend auf Orientierung berechnen
        var transform = CGAffineTransform.identity
        let size = self.size
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
            
        default:
            break
        }
        
        // Spiegelung behandeln
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        // Bild neu zeichnen mit korrekter Orientierung
        guard let cgImage = self.cgImage else { return self }
        
        let contextSize: CGSize
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            contextSize = CGSize(width: size.height, height: size.width)
        default:
            contextSize = size
        }
        
        let renderer = UIGraphicsImageRenderer(size: contextSize)
        let fixedImage = renderer.image { context in
            context.cgContext.concatenate(transform)
            
            let drawRect: CGRect
            switch imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                drawRect = CGRect(x: 0, y: 0, width: size.height, height: size.width)
            default:
                drawRect = CGRect(origin: .zero, size: size)
            }
            
            context.cgContext.draw(cgImage, in: drawRect)
        }
        
        return fixedImage
    }
    
    // MARK: - Crop to Aspect Ratio
    
    /// Schneidet das Bild auf ein bestimmtes Seitenverhältnis zu (Center Crop)
    /// Behält die volle Auflösung und nutzt UIGraphicsImageRenderer für stabiles Speicher-Management
    /// - Parameter ratio: Gewünschtes Seitenverhältnis (Breite / Höhe), z.B. 9/19.5 für iPhone
    /// - Returns: Zugeschnittenes UIImage oder nil bei Fehler
    func cropToAspectRatio(_ ratio: CGFloat) -> UIImage? {
        // Berechne neue Maße basierend auf der VOLLEN Bildgröße, nicht dem Screen
        let originalWidth = self.size.width
        let originalHeight = self.size.height
        
        // Sicherheitsprüfungen
        guard originalWidth > 0, originalHeight > 0, ratio > 0 else {
            print("UIImage+Crop: Ungültige Bildmaße oder Ratio")
            return nil
        }
        
        let targetHeight = originalWidth / ratio
        
        // Prüfen ob wir schneiden müssen
        if targetHeight > originalHeight {
            // Bild ist schon "zu kurz", wir müssten Breite schneiden
            // In diesem Fall das Original zurückgeben
            print("UIImage+Crop: Bild bereits passend, kein Crop nötig")
            return self
        }
        
        let cropRect = CGRect(
            x: 0,
            y: (originalHeight - targetHeight) / 2,
            width: originalWidth,
            height: targetHeight
        )
        
        // Nutze Renderer für sauberes Speicher-Management
        let renderer = UIGraphicsImageRenderer(size: cropRect.size)
        let croppedImage = renderer.image { _ in
            // Zeichne das Bild verschoben, sodass nur der Ausschnitt sichtbar ist
            self.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
        
        print("UIImage+Crop: Erfolgreich gecroppt von \(originalWidth)x\(originalHeight) auf \(cropRect.size.width)x\(cropRect.size.height)")
        return croppedImage
    }
    
    // MARK: - Crop to Center
    
    /// Schneidet prozentual in die Mitte des Bildes
    /// Nützlich um nur den Bereich des Scan-Rechtecks zu erfassen
    /// - Parameter scale: Prozentsatz der Originalgröße (0.0-1.0), z.B. 0.7 = 70% in der Mitte
    /// - Returns: Zugeschnittenes UIImage (oder Original bei ungültigen Werten)
    func cropToCenter(scale: CGFloat) -> UIImage {
        guard let cgImage = self.cgImage else { 
            print("UIImage+Crop: cropToCenter - kein CGImage vorhanden")
            return self 
        }
        
        // Ungültige scale-Werte → Original zurückgeben
        guard scale > 0 else {
            print("UIImage+Crop: cropToCenter - ungültiger scale-Wert: \(scale)")
            return self
        }
        
        // Bei scale >= 1.0 nichts ändern (kein Crop nötig)
        if scale >= 1.0 {
            return self
        }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Sicherstellen, dass das Bild groß genug ist
        guard imageWidth > 10 && imageHeight > 10 else {
            print("UIImage+Crop: cropToCenter - Bild zu klein: \(imageWidth)x\(imageHeight)")
            return self
        }
        
        let newWidth = imageWidth * scale
        let newHeight = imageHeight * scale
        
        let xOffset = (imageWidth - newWidth) / 2
        let yOffset = (imageHeight - newHeight) / 2
        
        let cropRect = CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return self }
        
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: .up)
    }
    
    // MARK: - Convenience Methods
    
    /// Schneidet das Bild auf das Seitenverhältnis des Bildschirms zu
    /// Kombiniert fixOrientation() und cropToAspectRatio()
    /// - Returns: Zugeschnittenes UIImage passend zur Bildschirm-Vorschau (oder Original bei Fehler)
    func cropToScreenAspectRatio() -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenRatio = screenBounds.width / screenBounds.height
        
        // Erst Orientierung fixen, dann croppen
        let fixed = self.fixOrientation()
        return fixed.cropToAspectRatio(screenRatio) ?? fixed
    }
    
    /// Vollständiger Crop-Workflow für Kamera-Bilder
    /// 1. Orientierung fixen
    /// 2. Auf Screen-Ratio croppen
    /// 3. Optional: Auf mittleren Bereich zoomen
    /// - Parameter centerScale: Optional: Zusätzlicher Center-Crop (0.0-1.0)
    /// - Returns: Fertig zugeschnittenes UIImage (oder Original bei Fehler)
    func prepareForOCR(centerScale: CGFloat? = nil) -> UIImage {
        // 1. Orientierung fixen
        let fixed = self.fixOrientation()
        
        // 2. Auf Screen-Ratio croppen (mit Fallback)
        let screenBounds = UIScreen.main.bounds
        let screenRatio = screenBounds.width / screenBounds.height
        let screenCropped = fixed.cropToAspectRatio(screenRatio) ?? fixed
        
        // 3. Optional: Center-Crop
        if let scale = centerScale, scale < 1.0 {
            return screenCropped.cropToCenter(scale: scale)
        }
        
        return screenCropped
    }
}
