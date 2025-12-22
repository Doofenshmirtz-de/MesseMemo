//
//  BusinessCardFullscreenView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 22.12.25.
//

import SwiftUI

/// Vollbildansicht für die Original-Visitenkarte
/// Ermöglicht Zoomen und Pinch-Gesten zur besseren Lesbarkeit
struct BusinessCardFullscreenView: View {
    
    // MARK: - Properties
    
    let image: UIImage?
    let onDismiss: () -> Void
    
    // MARK: - State
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Dunkler Hintergrund
            Color.black
                .ignoresSafeArea()
            
            if let image = image {
                // Bild mit Zoom-Funktionalität
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        // Zoom Gesture
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 5) // Limit: 1x - 5x
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        // Drag Gesture (nur wenn gezoomt)
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .gesture(
                        // Double Tap to Reset/Zoom
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring()) {
                                    if scale > 1 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.0
                                    }
                                }
                            }
                    )
            } else {
                // Fallback wenn kein Bild
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Bild nicht verfügbar")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            )
                    }
                    .padding()
                }
                
                Spacer()
                
                // Zoom-Hinweis
                if image != nil {
                    VStack(spacing: 4) {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.pinch")
                                Text("Zoomen")
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap")
                                Text("2× Tippen")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BusinessCardFullscreenView(
        image: UIImage(systemName: "person.crop.rectangle"),
        onDismiss: { }
    )
}

