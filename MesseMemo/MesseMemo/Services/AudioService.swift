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
        setupAudioSession()
        checkPermission()
    }
    
    // MARK: - Audio Session Setup
    
    /// Konfiguriert die Audio-Session für Aufnahme und Wiedergabe
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Kategorie für Aufnahme und Wiedergabe setzen
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
        } catch {
            print("AudioService: Fehler beim Setup der Audio-Session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Permission Handling
    
    /// Prüft die Mikrofon-Berechtigung
    func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            DispatchQueue.main.async {
                self.permissionGranted = true
            }
        case .denied:
            DispatchQueue.main.async {
                self.permissionGranted = false
            }
        case .undetermined:
            requestPermission()
        @unknown default:
            DispatchQueue.main.async {
                self.permissionGranted = false
            }
        }
    }
    
    /// Fordert die Mikrofon-Berechtigung an
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted {
                    self?.setupAudioSession()
                }
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
        
        // Stoppe eventuelle laufende Wiedergabe
        if isPlaying {
            stopPlayback()
        }
        
        // Audio Session aktivieren
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioService: Fehler beim Aktivieren der Session: \(error.localizedDescription)")
            throw AudioError.recordingFailed
        }
        
        // Datei-URL erstellen
        let fileName = "audio_\(leadId.uuidString).m4a"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(fileName)
        
        // Lösche existierende Datei falls vorhanden
        if FileManager.default.fileExists(atPath: audioURL.path) {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        currentRecordingURL = audioURL
        
        // Recorder-Einstellungen (optimiert für Sprachaufnahme)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,  // Reduziert für Sprache
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000
        ]
        
        do {
            // Recorder initialisieren
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Vorbereiten und starten
            if audioRecorder?.prepareToRecord() == true {
                if audioRecorder?.record() == true {
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.recordingTime = 0
                        self.startRecordingTimer()
                    }
                    return fileName
                } else {
                    throw AudioError.recordingFailed
                }
            } else {
                throw AudioError.recordingFailed
            }
        } catch {
            print("AudioService: Fehler beim Starten der Aufnahme: \(error.localizedDescription)")
            throw AudioError.recordingFailed
        }
    }
    
    /// Stoppt die aktuelle Aufnahme
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingTimer()
        }
        
        // Audio Session deaktivieren
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioService: Fehler beim Deaktivieren der Session: \(error.localizedDescription)")
        }
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
        // Stoppe eventuelle laufende Aufnahme
        if isRecording {
            stopRecording()
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent(path)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AudioError.fileNotFound
        }
        
        // Audio Session für Wiedergabe konfigurieren
        let session = AVAudioSession.sharedInstance()
        do {
            // Verwende playAndRecord mit defaultToSpeaker für laute Wiedergabe
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioService: Fehler beim Aktivieren der Playback-Session: \(error.localizedDescription)")
            throw AudioError.playbackFailed
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            DispatchQueue.main.async {
                self.playbackDuration = self.audioPlayer?.duration ?? 0
                self.playbackTime = 0
            }
            
            if audioPlayer?.play() == true {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.startPlaybackTimer()
                }
            } else {
                throw AudioError.playbackFailed
            }
        } catch {
            print("AudioService: Fehler beim Starten der Wiedergabe: \(error.localizedDescription)")
            throw AudioError.playbackFailed
        }
    }
    
    /// Stoppt die Wiedergabe
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTime = 0
            self.stopPlaybackTimer()
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioService: Fehler beim Deaktivieren der Session: \(error.localizedDescription)")
        }
    }
    
    /// Pausiert oder setzt die Wiedergabe fort
    func togglePlayback() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            DispatchQueue.main.async {
                self.isPlaying = false
                self.stopPlaybackTimer()
            }
        } else {
            player.play()
            DispatchQueue.main.async {
                self.isPlaying = true
                self.startPlaybackTimer()
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.recordingTime += 0.1
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            DispatchQueue.main.async {
                self.playbackTime = player.currentTime
            }
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
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            return nil
        }
        
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
