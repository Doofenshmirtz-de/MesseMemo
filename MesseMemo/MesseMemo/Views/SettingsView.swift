//
//  SettingsView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  LOCAL-ONLY APP:
//  Keine Account-Section, keine Auth-Features
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var leads: [Lead]
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var viewModel = LeadsViewModel()
    
    @State private var showPaywall = false
    
    // Cloud KI Settings
    @AppStorage("useCloudOCR") private var useCloudOCR = false
    @State private var showCloudPrivacyAlert = false
    
    // Legal Sheets
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    
    // Delete All Alert
    @State private var showDeleteAllAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Credits Section
                creditsSection
                
                // MARK: - Export Section
                exportSection
                
                // MARK: - App Settings
                appSettingsSection
                
                // MARK: - Support Section
                supportSection
                
                // MARK: - Legal Section
                legalSection
                
                // MARK: - Danger Zone
                dangerZoneSection
                
                // MARK: - App Info
                appInfoSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .alert("Cloud KI Unterstützung", isPresented: $showCloudPrivacyAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Aktivieren") {
                    useCloudOCR = true
                }
            } message: {
                Text("Durch das Aktivieren der Cloud KI Unterstützung werden die Texte deiner Visitenkarten zur Analyse an Google (Gemini) gesendet. Dies kann die Erkennungsrate deutlich verbessern.")
            }
            .alert("Alle Daten löschen?", isPresented: $showDeleteAllAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Alle löschen", role: .destructive) {
                    deleteAllLeads()
                }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle \(leads.count) Kontakte werden unwiderruflich gelöscht.")
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack {
                    ScrollView {
                        Text("Datenschutzerklärung: Die App speichert alle Daten lokal auf deinem Gerät. Bei aktivierter Cloud KI werden Texte zur Analyse an Google (Gemini) gesendet.")
                            .padding()
                    }
                    .navigationTitle("Datenschutz")
                    .toolbar {
                        Button("Fertig") { showPrivacySheet = false }
                    }
                }
            }
            .sheet(isPresented: $showTermsSheet) {
                NavigationStack {
                    ScrollView {
                        Text("Nutzungsbedingungen: Durch die Nutzung dieser App stimmst du zu...")
                            .padding()
                    }
                    .navigationTitle("AGB")
                    .toolbar {
                        Button("Fertig") { showTermsSheet = false }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - Credits Section
    
    private var creditsSection: some View {
        Section {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dein Guthaben")
                        .font(.headline)
                    
                    Text("\(subscriptionManager.credits) KI-Credits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Credit Badge
                Text("\(subscriptionManager.credits)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(creditColor)
            }
            .padding(.vertical, 4)
            
            // Info Text
            Text("Credits werden für KI-Funktionen wie Zauber-Mail und Cloud OCR verwendet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var creditColor: Color {
        let credits = subscriptionManager.credits
        if credits > 10 { return .green }
        if credits > 3 { return .orange }
        return .red
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section("Daten") {
            Button {
                viewModel.exportLeads(leads)
            } label: {
                HStack {
                    Label("Alle Leads als CSV exportieren", systemImage: "square.and.arrow.up")
                    Spacer()
                    Text("\(leads.count)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(leads.isEmpty)
            
            // Statistik
            HStack {
                Label("Gespeicherte Kontakte", systemImage: "person.2")
                Spacer()
                Text("\(leads.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // Binding für Cloud KI mit Alert-Logik
    private var cloudOCRBinding: Binding<Bool> {
        Binding(
            get: { useCloudOCR },
            set: { newValue in
                if newValue {
                    showCloudPrivacyAlert = true
                } else {
                    useCloudOCR = false
                }
            }
        )
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section("KI-Einstellungen") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: cloudOCRBinding) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud KI Unterstützung")
                            Text("Bessere Erkennung via Gemini")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section("Support") {
            Button {
                // TODO: App Store Review
            } label: {
                Label {
                    Text("App bewerten")
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        Section("Rechtliches") {
            Button {
                showPrivacySheet = true
            } label: {
                Label("Datenschutzerklärung", systemImage: "hand.raised")
                    .foregroundStyle(.primary)
            }
            
            Button {
                showTermsSheet = true
            } label: {
                Label("Nutzungsbedingungen", systemImage: "doc.text")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAllAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Alle Daten löschen")
                }
            }
            .disabled(leads.isEmpty)
        } footer: {
            Text("Löscht alle gespeicherten Kontakte unwiderruflich.")
        }
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
            
            // Lokale Daten Info
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lokale App")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Alle Daten werden auf diesem Gerät gespeichert. Mache regelmäßige CSV-Exports als Backup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 8)
        } footer: {
            Text("MesseMemo \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    
    private func deleteAllLeads() {
        for lead in leads {
            // Audio löschen
            if let audioPath = lead.audioFilePath {
                AudioService().deleteRecording(at: audioPath)
            }
            // Bild löschen
            if let imageFilename = lead.originalImageFilename {
                ImageStorageService.shared.deleteImage(filename: imageFilename)
            }
            modelContext.delete(lead)
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}

