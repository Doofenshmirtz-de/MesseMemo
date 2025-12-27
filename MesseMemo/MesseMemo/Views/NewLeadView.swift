//
//  NewLeadView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import SwiftData

/// View zum Erstellen eines neuen Leads
struct NewLeadView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @StateObject private var viewModel = NewLeadViewModel()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Kamera-Sektion
                cameraSection
                
                // Kontaktdaten
                contactSection
                
                // Audio-Notiz
                audioSection
                
                // Textnotizen
                notesSection
            }
            .navigationTitle("Neuer Kontakt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        viewModel.reset()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        if viewModel.saveLead(context: modelContext) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                CameraScannerView { image in
                    Task {
                        await viewModel.processImage(image)
                    }
                }
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay {
                if viewModel.isProcessingImage {
                    processingOverlay
                }
            }
        }
    }
    
    // MARK: - Camera Section
    
    private var cameraSection: some View {
        Section {
            Button(action: { viewModel.showCamera = true }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Visitenkarte scannen")
                            .font(.headline)
                        Text("Kontaktdaten automatisch erfassen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } footer: {
            Text("Halte die Kamera über eine Visitenkarte, um die Kontaktdaten automatisch zu erkennen.")
        }
    }
    
    // MARK: - Contact Section
    
    private var contactSection: some View {
        Section("Kontaktdaten") {
            HStack {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
            }
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Firma", text: $viewModel.company)
                    .textContentType(.organizationName)
                    .textInputAutocapitalization(.words)
            }
            
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("E-Mail", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Image(systemName: "phone")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Telefon", text: $viewModel.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            }
        }
    }
    
    // MARK: - Audio Section
    
    private var audioSection: some View {
        Section {
            AudioRecorderView(
                audioService: viewModel.audioService,
                audioFilePath: $viewModel.audioFilePath,
                leadId: viewModel.leadId,
                onStartRecording: viewModel.startRecording,
                onStopRecording: viewModel.stopRecording,
                onDeleteRecording: viewModel.deleteRecording
            )
        } header: {
            Text("Sprachnotiz")
        } footer: {
            Text("Nimm eine kurze Sprachnotiz auf, um den Kontext des Gesprächs festzuhalten.")
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section("Notizen") {
            TextEditor(text: $viewModel.notes)
                .frame(minHeight: 100)
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(viewModel.isCloudOCRRunning ? "KI-Analyse (Gemini)..." : "Visitenkarte wird analysiert...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Preview

#Preview {
    NewLeadView()
        .modelContainer(for: Lead.self, inMemory: true)
}

