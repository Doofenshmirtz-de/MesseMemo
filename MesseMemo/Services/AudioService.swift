//
//  AudioService.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import AVFoundation
import Combine

/// Service für Audio-Aufnahme und -Wiedergabe mittels AVFoundation
final class AudioService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var playbackTime: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var currentRecordingURL: URL?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Handling
    
    /// Prüft die Mikrofon-Berechtigung
    func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
        case .undetermined:
            requestPermission()
        @unknown default:
            permissionGranted = false
        }
    }
    
    /// Fordert die Mikrofon-Berechtigung an
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
    }
    
    // MARK: - Recording
    
    /// Startet eine neue Aufnahme
    /// - Parameter leadId: Die ID des zugehörigen Leads für den Dateinamen
    /// - Returns: Der relative Pfad zur Audiodatei
    @discardableResult
    func startRecording(for leadId: UUID) throws -> String {
        guard permissionGranted else {
            throw AudioError.permissionDenied
        }
        
        // Audio Session konfigurieren
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        
        // Datei-URL erstellen
        let fileName = "audio_\(leadId.uuidString).m4a"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(fileName)
        
        currentRecordingURL = audioURL
        
        // Recorder-Einstellungen
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Recorder initialisieren und starten
        audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
        isRecording = true
        recordingTime = 0
        startRecordingTimer()
        
        return fileName
    }
    
    /// Stoppt die aktuelle Aufnahme
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopRecordingTimer()
        
        // Audio Session deaktivieren
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    /// Löscht die letzte Aufnahme
    func deleteRecording(at path: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(path)
        
        try? FileManager.default.removeItem(at: audioURL)
    }
    
    // MARK: - Playback
    
    /// Spielt eine Audiodatei ab
    /// - Parameter path: Relativer Pfad zur Audiodatei
    func play(from path: String) throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(path)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AudioError.fileNotFound
        }
        
        // Audio Session für Wiedergabe konfigurieren
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        
        audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
        audioPlayer?.delegate = self
        playbackDuration = audioPlayer?.duration ?? 0
        playbackTime = 0
        audioPlayer?.play()
        
        isPlaying = true
        startPlaybackTimer()
    }
    
    /// Stoppt die Wiedergabe
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackTime = 0
        stopPlaybackTimer()
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    /// Pausiert oder setzt die Wiedergabe fort
    func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopPlaybackTimer()
        } else {
            player.play()
            isPlaying = true
            startPlaybackTimer()
        }
    }
    
    // MARK: - Timer Management
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.playbackTime = player.currentTime
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Utilities
    
    /// Formatiert Sekunden in MM:SS Format
    static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Gibt die Dauer einer Audiodatei zurück
    func getDuration(for path: String) -> TimeInterval? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(path)
        
        guard let player = try? AVAudioPlayer(contentsOf: audioURL) else {
            return nil
        }
        return player.duration
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.stopRecordingTimer()
            
            if !flag {
                self?.errorMessage = "Die Aufnahme konnte nicht gespeichert werden."
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.stopRecordingTimer()
            self?.errorMessage = error?.localizedDescription ?? "Ein Fehler ist bei der Aufnahme aufgetreten."
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playbackTime = 0
            self?.stopPlaybackTimer()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.stopPlaybackTimer()
            self?.errorMessage = error?.localizedDescription ?? "Ein Fehler ist bei der Wiedergabe aufgetreten."
        }
    }
}

// MARK: - Errors

enum AudioError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case fileNotFound
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Mikrofon-Zugriff wurde verweigert. Bitte aktiviere den Zugriff in den Einstellungen."
        case .recordingFailed:
            return "Die Aufnahme konnte nicht gestartet werden."
        case .fileNotFound:
            return "Die Audiodatei wurde nicht gefunden."
        case .playbackFailed:
            return "Die Wiedergabe konnte nicht gestartet werden."
        }
    }
}

