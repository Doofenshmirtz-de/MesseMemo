//
//  AudioRecorderView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import AVFoundation

/// View für die Audio-Aufnahme und -Wiedergabe
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
            if audioFilePath != nil {
                // Aufnahme vorhanden - Wiedergabe-UI
                playbackView
            } else if audioService.isRecording {
                // Aufnahme läuft
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
            HStack {
                Image(systemName: "mic.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sprachnotiz aufnehmen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Tippen zum Starten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(!audioService.permissionGranted)
        .overlay {
            if !audioService.permissionGranted {
                permissionHint
            }
        }
    }
    
    // MARK: - Recording View
    
    private var recordingView: some View {
        HStack {
            // Pulsierende Aufnahme-Anzeige
            ZStack {
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(1.2)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: audioService.isRecording
                    )
                
                Circle()
                    .fill(.red)
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Aufnahme läuft...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                
                Text(AudioService.formatTime(audioService.recordingTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: stopRecording) {
                Image(systemName: "stop.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Playback View
    
    private var playbackView: some View {
        HStack {
            // Play/Stop Button
            Button(action: togglePlayback) {
                Image(systemName: audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sprachnotiz")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if audioService.isPlaying {
                    // Fortschrittsanzeige
                    ProgressView(
                        value: audioService.playbackTime,
                        total: max(audioService.playbackDuration, 1)
                    )
                    .tint(Color.accentColor)
                    
                    Text("\(AudioService.formatTime(audioService.playbackTime)) / \(AudioService.formatTime(audioService.playbackDuration))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text(formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Waveform Animation
            if audioService.isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        MiniWaveformBar(index: index)
                    }
                }
                .frame(width: 24, height: 16)
            }
            
            // Löschen Button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red)
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
        .padding(.vertical, 4)
    }
    
    // MARK: - Permission Hint
    
    private var permissionHint: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: openSettings) {
                    Text("Mikrofon-Zugriff erforderlich")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        guard let path = audioFilePath,
              let duration = audioService.getDuration(for: path) else {
            return "Unbekannte Dauer"
        }
        return "Dauer: \(AudioService.formatTime(duration))"
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        onStartRecording()
    }
    
    private func stopRecording() {
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

// MARK: - Mini Waveform Bar

struct MiniWaveformBar: View {
    let index: Int
    @State private var animating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(width: 3, height: animating ? CGFloat.random(in: 4...16) : 4)
            .animation(
                .easeInOut(duration: 0.25)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.08),
                value: animating
            )
            .onAppear {
                animating = true
            }
    }
}

// MARK: - Preview

#Preview {
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

