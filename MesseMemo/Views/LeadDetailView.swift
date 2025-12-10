//
//  LeadDetailView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import SwiftData

/// Detailansicht eines Leads
struct LeadDetailView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @StateObject private var viewModel: LeadDetailViewModel
    
    // MARK: - Initialization
    
    init(lead: Lead) {
        _viewModel = StateObject(wrappedValue: LeadDetailViewModel(lead: lead))
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Header mit Avatar
            headerSection
            
            // Kontaktdaten
            if viewModel.isEditing {
                editContactSection
            } else {
                contactSection
            }
            
            // Audio-Notiz & Transkript
            if viewModel.lead.hasAudioNote || viewModel.lead.hasTranscript {
                audioAndTranscriptSection
            }
            
            // Notizen
            notesSection
            
            // Quick Actions (LinkedIn, Mail etc.)
            if !viewModel.isEditing {
                quickActionsSection
            }
            
            // Weitere Aktionen
            if !viewModel.isEditing {
                actionsSection
            }
            
            // Meta-Informationen
            metaSection
        }
        .navigationTitle(viewModel.isEditing ? "Bearbeiten" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .alert("Kontakt löschen?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                modelContext.delete(viewModel.lead)
                dismiss()
            }
        } message: {
            Text("Dieser Kontakt wird unwiderruflich gelöscht.")
        }
        .alert("Fehler", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Transkription erfolgreich", isPresented: $viewModel.showTranscriptionSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Die Sprachnotiz wurde erfolgreich in Text umgewandelt.")
        }
        .sheet(isPresented: $viewModel.showMailComposer) {
            if viewModel.canSendMail {
                let mailData = viewModel.followUpMailData
                MailComposerView(
                    recipients: mailData.recipients,
                    subject: mailData.subject,
                    body: mailData.body
                )
            }
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Section {
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Text(viewModel.lead.displayName.prefix(1).uppercased())
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    VStack(spacing: 4) {
                        Text(viewModel.lead.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !viewModel.lead.company.isEmpty {
                            Text(viewModel.lead.company)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Contact Section (View Mode)
    
    private var contactSection: some View {
        Section("Kontakt") {
            if !viewModel.lead.email.isEmpty {
                Button(action: viewModel.openMail) {
                    HStack {
                        Label(viewModel.lead.email, systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }
            
            if !viewModel.lead.phone.isEmpty {
                Button(action: viewModel.callPhone) {
                    HStack {
                        Label(viewModel.lead.phone, systemImage: "phone")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }
            
            if viewModel.lead.email.isEmpty && viewModel.lead.phone.isEmpty {
                Text("Keine Kontaktdaten vorhanden")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Contact Section (Edit Mode)
    
    private var editContactSection: some View {
        Section("Kontaktdaten bearbeiten") {
            HStack {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Name", text: $viewModel.editName)
            }
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Firma", text: $viewModel.editCompany)
            }
            
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("E-Mail", text: $viewModel.editEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Image(systemName: "phone")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                TextField("Telefon", text: $viewModel.editPhone)
                    .keyboardType(.phonePad)
            }
        }
    }
    
    // MARK: - Audio & Transcript Section
    
    private var audioAndTranscriptSection: some View {
        Section("Sprachnotiz") {
            // Audio Player
            if viewModel.lead.hasAudioNote {
                HStack {
                    Button(action: viewModel.toggleAudioPlayback) {
                        Image(systemName: viewModel.audioService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio-Notiz")
                            .font(.headline)
                        
                        if viewModel.audioService.isPlaying {
                            Text(AudioService.formatTime(viewModel.audioService.playbackTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else if let duration = viewModel.audioDuration {
                            Text("Dauer: \(duration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.audioService.isPlaying {
                        // Waveform Animation
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                WaveformBar(index: index)
                            }
                        }
                        .frame(width: 30, height: 20)
                    }
                }
                .padding(.vertical, 4)
                
                // Transkription Button
                if !viewModel.lead.hasTranscript {
                    Button(action: {
                        Task {
                            await viewModel.transcribeAudio()
                        }
                    }) {
                        HStack {
                            if viewModel.isTranscribing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Transkribiere...")
                            } else {
                                Image(systemName: "text.bubble")
                                Text("In Text umwandeln")
                            }
                        }
                    }
                    .disabled(viewModel.isTranscribing)
                }
            }
            
            // Transkript anzeigen
            if viewModel.lead.hasTranscript {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundStyle(.secondary)
                        Text("Transkript")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    if viewModel.isEditing {
                        TextEditor(text: $viewModel.editTranscript)
                            .frame(minHeight: 80)
                    } else {
                        Text(viewModel.lead.transcript ?? "")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section("Notizen") {
            if viewModel.isEditing {
                TextEditor(text: $viewModel.editNotes)
                    .frame(minHeight: 100)
            } else if viewModel.lead.notes.isEmpty {
                Text("Keine Notizen vorhanden")
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.lead.notes)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        Section("Schnellaktionen") {
            // LinkedIn Button
            Button(action: viewModel.openLinkedIn) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                    Text("Auf LinkedIn suchen")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .disabled(viewModel.lead.name.isEmpty && viewModel.lead.company.isEmpty)
            
            // Follow-Up Mail Button
            if viewModel.canSendMail {
                Button(action: { viewModel.showMailComposer = true }) {
                    HStack {
                        Image(systemName: "envelope.badge")
                            .foregroundStyle(.orange)
                        Text("Follow-Up E-Mail senden")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button(action: viewModel.copyToClipboard) {
                Label("In Zwischenablage kopieren", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive, action: { viewModel.showDeleteConfirmation = true }) {
                Label("Kontakt löschen", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Meta Section
    
    private var metaSection: some View {
        Section {
            LabeledContent("Erfasst am", value: viewModel.lead.formattedDate)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") {
                    viewModel.cancelEditing()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    viewModel.saveChanges()
                }
                .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") {
                    viewModel.isEditing = true
                }
            }
        }
    }
}

// MARK: - Waveform Animation

struct WaveformBar: View {
    let index: Int
    @State private var animating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(width: 3, height: animating ? CGFloat.random(in: 5...20) : 5)
            .animation(
                .easeInOut(duration: 0.3)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
                value: animating
            )
            .onAppear {
                animating = true
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeadDetailView(lead: Lead(
            name: "Max Mustermann",
            company: "Beispiel GmbH",
            email: "max@beispiel.de",
            phone: "+49 123 456789",
            notes: "Interessiert an unserem Premium-Paket. Rückruf nächste Woche vereinbart.",
            transcript: "Das war ein sehr interessantes Gespräch über die neuen Produkte."
        ))
    }
    .modelContainer(for: Lead.self, inMemory: true)
}
