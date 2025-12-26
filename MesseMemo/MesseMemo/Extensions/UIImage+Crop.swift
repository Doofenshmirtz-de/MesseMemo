//
//  UIImage+Crop.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 26.12.24.
//
//  Extension zum Zuschneiden von Bildern auf ein bestimmtes Seitenverhältnis.
//  Löst das "Zoom-Effekt" Problem: Die Kamera-Vorschau nutzt resizeAspectFill,
//  aber das Foto ist das volle 4:3 Sensorbild. Durch Center-Crop wird
//  "What you see is what you get" erreicht.
//

import UIKit

extension UIImage {
    
    /// Schneidet das Bild auf ein bestimmtes Seitenverhältnis zu (Center Crop)
    /// - Parameter ratio: Gewünschtes Seitenverhältnis (Breite / Höhe)
    /// - Returns: Zugeschnittenes UIImage oder nil bei Fehler
    func crop(toAspectRatio ratio: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let imageRatio = imageWidth / imageHeight
        
        var cropRect: CGRect
        
        if imageRatio > ratio {
            // Bild ist breiter als gewünscht -> links und rechts abschneiden
            let newWidth = imageHeight * ratio
            let xOffset = (imageWidth - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageHeight)
        } else {
            // Bild ist höher als gewünscht -> oben und unten abschneiden
            let newHeight = imageWidth / ratio
            let yOffset = (imageHeight - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageWidth, height: newHeight)
        }
        
        // Croppen
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        
        // Neues UIImage mit korrekter Orientierung erstellen
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    /// Schneidet das Bild auf das Seitenverhältnis des Bildschirms zu
    /// Nützlich für "What you see is what you get" bei Kamera-Apps
    /// - Returns: Zugeschnittenes UIImage oder das Original bei Fehler
    func cropToScreenAspectRatio() -> UIImage {
        let screenBounds = UIScreen.main.bounds
        let screenRatio = screenBounds.width / screenBounds.height
        return crop(toAspectRatio: screenRatio) ?? self
    }
    
    /// Schneidet das Bild auf ein 3:4 Portrait-Verhältnis zu (typisch für Visitenkarten)
    /// - Returns: Zugeschnittenes UIImage oder das Original bei Fehler
    func cropToPortrait3x4() -> UIImage {
        return crop(toAspectRatio: 3.0 / 4.0) ?? self
    }
    
    /// Schneidet das Bild auf ein 16:9 Verhältnis zu
    /// - Returns: Zugeschnittenes UIImage oder das Original bei Fehler
    func cropTo16x9() -> UIImage {
        return crop(toAspectRatio: 16.0 / 9.0) ?? self
    }
}

