//
//  UIImage+Crop.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 26.12.24.
//
//  Einfacher Zoom für Kamera-Bilder.
//  Schneidet die Ränder ab = Bild wirkt "rangezoomt".
//

import UIKit

extension UIImage {
    
    /// Zoomt in die Mitte des Bildes (schneidet Ränder ab)
    /// - Parameter zoomPercent: Wie viel Prozent reinzoomen (z.B. 30 = 30% Zoom)
    /// - Returns: Gezoomtes Bild
    func zoom(percent zoomPercent: CGFloat) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        guard zoomPercent > 0 && zoomPercent < 100 else { return self }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Scale berechnen: 50% Zoom = 50% des Bildes behalten
        let scale = 1.0 - (zoomPercent / 100.0)
        
        let newWidth = width * scale
        let newHeight = height * scale
        let xOffset = (width - newWidth) / 2
        let yOffset = (height - newHeight) / 2
        
        let cropRect = CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return self }
        
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    /// Bereitet das Bild für OCR vor
    /// Zoomt 50% rein (schneidet Ränder ab)
    func prepareForOCR() -> UIImage {
        return zoom(percent: 50)
    }
}
