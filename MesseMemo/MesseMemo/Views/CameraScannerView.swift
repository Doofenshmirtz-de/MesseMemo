//
//  CameraScannerView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import AVFoundation
import Combine

/// View für die Kamera zum Scannen von Visitenkarten
struct CameraScannerView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let onImageCaptured: (UIImage) -> Void
    
    // MARK: - State
    
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showPreview = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Kamera-Preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                // Header
                headerView
                
                Spacer()
                
                // Scan-Rahmen
                scanFrameView
                
                Spacer()
                
                // Capture Button
                captureButton
            }
            
            // Vorschau nach Aufnahme
            if showPreview, let image = capturedImage {
                previewView(image: image)
            }
            
            // Berechtigung verweigert
            if cameraManager.permissionDenied {
                permissionDeniedView
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button("Abbrechen") {
                dismiss()
            }
            .foregroundStyle(.white)
            .padding()
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Scan Frame
    
    private var scanFrameView: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 300, height: 180)
                .overlay {
                    // Eck-Markierungen
                    GeometryReader { geometry in
                        let cornerLength: CGFloat = 30
                        let lineWidth: CGFloat = 4
                        
                        Group {
                            // Oben links
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: cornerLength))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: cornerLength, y: 0))
                            }
                            .stroke(Color.accentColor, lineWidth: lineWidth)
                            
                            // Oben rechts
                            Path { path in
                                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: 0))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: cornerLength))
                            }
                            .stroke(Color.accentColor, lineWidth: lineWidth)
                            
                            // Unten links
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: geometry.size.height - cornerLength))
                                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: cornerLength, y: geometry.size.height))
                            }
                            .stroke(Color.accentColor, lineWidth: lineWidth)
                            
                            // Unten rechts
                            Path { path in
                                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - cornerLength))
                            }
                            .stroke(Color.accentColor, lineWidth: lineWidth)
                        }
                    }
                }
            
            Text("Visitenkarte im Rahmen positionieren")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Capture Button
    
    private var captureButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
            }
        }
        .padding(.bottom, 40)
        .disabled(!cameraManager.isSessionRunning)
    }
    
    // MARK: - Preview View
    
    private func previewView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
                
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: retakePhoto) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Wiederholen")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                    }
                    
                    Button(action: usePhoto) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                            Text("Verwenden")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Permission Denied View
    
    private var permissionDeniedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("Kamera-Zugriff erforderlich")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Bitte aktiviere den Kamera-Zugriff in den Einstellungen, um Visitenkarten zu scannen.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                HStack(spacing: 20) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Button("Einstellungen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            capturedImage = image
            showPreview = true
        }
    }
    
    private func retakePhoto() {
        capturedImage = nil
        showPreview = false
        cameraManager.startSession()
    }
    
    private func usePhoto() {
        guard let image = capturedImage else { return }
        onImageCaptured(image)
        dismiss()
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Camera Manager

final class CameraManager: NSObject, ObservableObject {
    
    @Published var isSessionRunning = false
    @Published var permissionDenied = false
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage) -> Void)?
    
    override init() {
        super.init()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.permissionDenied = true
            }
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        startSession()
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.stopSession()
            self?.captureCompletion?(image)
        }
    }
}

// MARK: - Preview

#Preview {
    CameraScannerView { _ in }
}

