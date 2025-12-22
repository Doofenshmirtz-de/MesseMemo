//
//  AudioRecorderView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import AVFoundation

/// WhatsApp-ähnliche View für die Audio-Aufnahme und -Wiedergabe
struct AudioRecorderView: View {
    
    // MARK: - Properties
    
    @ObservedObject var audioService: AudioService
    @Binding var audioFilePath: String?
    let leadId: UUID
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onDeleteRecording: () -> Void
    
    // MARK: - State
    
    @State private var showDeleteConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            if audioFilePath != nil && !audioService.isRecording {
                // Aufnahme vorhanden - Wiedergabe-UI
                playbackView
            } else if audioService.isRecording {
                // Aufnahme läuft - WhatsApp-Style
                recordingView
            } else {
                // Keine Aufnahme - Start-UI
                startRecordingView
            }
        }
    }
    
    // MARK: - Start Recording View
    
    private var startRecordingView: some View {
        Button(action: startRecording) {
            HStack(spacing: 16) {
                // Mikrofon-Icon mit Hintergrund
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red, .red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sprachnotiz aufnehmen")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Tippen zum Starten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!audioService.permissionGranted)
        .overlay {
            if !audioService.permissionGranted {
                permissionHint
            }
        }
    }
    
    // MARK: - Recording View (WhatsApp-Style)
    
    private var recordingView: some View {
        VStack(spacing: 16) {
            // Timer und Status
            HStack {
                // Pulsierender roter Punkt
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.8)
                    )
                    .modifier(PulseAnimation())
                
                // Live Timer
                Text(AudioService.formatTime(audioService.recordingTime))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red)
                
                Spacer()
                
                // Stop Button
                Button(action: stopRecording) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 56, height: 56)
                            .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Hinweis
            Text("Tippe auf Stop um die Aufnahme zu beenden")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .onAppear {
            playStartSound()
        }
    }
    
    // MARK: - Playback View
    
    private var playbackView: some View {
        VStack(spacing: 12) {
            HStack {
                // Play/Pause Button
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .offset(x: audioService.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Hintergrund
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 4)
                            
                            // Fortschritt
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(
                                    width: geometry.size.width * progressPercentage,
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                    
                    // Zeit-Anzeige
                    HStack {
                        Text(AudioService.formatTime(audioService.isPlaying ? audioService.playbackTime : 0))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(formattedDuration)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Löschen Button
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash.fill")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Sprachnotiz löschen?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Löschen", role: .destructive) {
                        deleteRecording()
                    }
                    Button("Abbrechen", role: .cancel) { }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Permission Hint
    
    private var permissionHint: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: openSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Mikrofon-Zugriff erforderlich")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.orange.opacity(0.15)))
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        guard let path = audioFilePath,
              let duration = audioService.getDuration(for: path) else {
            return "0:00"
        }
        return AudioService.formatTime(duration)
    }
    
    private var progressPercentage: CGFloat {
        guard audioService.playbackDuration > 0 else { return 0 }
        return CGFloat(audioService.playbackTime / audioService.playbackDuration)
    }
    
    // MARK: - Sound Effects
    
    private func playStartSound() {
        // System Sound für Aufnahmestart
        AudioServicesPlaySystemSound(1113) // Aufnahme-Start-Sound
    }
    
    private func playStopSound() {
        AudioServicesPlaySystemSound(1114) // Aufnahme-Stop-Sound
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        onStartRecording()
    }
    
    private func stopRecording() {
        playStopSound()
        onStopRecording()
    }
    
    private func togglePlayback() {
        guard let path = audioFilePath else { return }
        
        if audioService.isPlaying {
            audioService.stopPlayback()
        } else {
            try? audioService.play(from: path)
        }
    }
    
    private func deleteRecording() {
        audioService.stopPlayback()
        onDeleteRecording()
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preview

#Preview("Idle State") {
    Form {
        Section("Sprachnotiz") {
            AudioRecorderView(
                audioService: AudioService(),
                audioFilePath: .constant(nil),
                leadId: UUID(),
                onStartRecording: { },
                onStopRecording: { },
                onDeleteRecording: { }
            )
        }
    }
}

#Preview("With Recording") {
    Form {
        Section("Sprachnotiz") {
            AudioRecorderView(
                audioService: AudioService(),
                audioFilePath: .constant("test.m4a"),
                leadId: UUID(),
                onStartRecording: { },
                onStopRecording: { },
                onDeleteRecording: { }
            )
        }
    }
}
