//
//  SettingsView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var isLoggingOut = false
    @State private var showPaywall = false
    @State private var authProvider: AuthProvider = .unknown
    
    // Cloud KI Settings
    @AppStorage("useCloudOCR") private var useCloudOCR = false
    @State private var showCloudPrivacyAlert = false
    
    // Legal Sheets
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Premium Banner
                premiumSection
                
                // MARK: - Account Section
                accountSection
                
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
            .alert("Abmelden", isPresented: $showLogoutAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Abmelden", role: .destructive) {
                    Task { await logout() }
                }
            } message: {
                Text("Möchtest du dich wirklich abmelden?")
            }
            .alert("Account löschen", isPresented: $showDeleteAccountAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Löschen", role: .destructive) {
                    // TODO: Account löschen implementieren
                }
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden gelöscht.")
            }
            .alert("Cloud KI Unterstützung", isPresented: $showCloudPrivacyAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Aktivieren") {
                    useCloudOCR = true
                }
            } message: {
                Text("Durch das Aktivieren der Cloud KI Unterstützung werden die Texte deiner Visitenkarten zur Analyse an Google (Gemini) gesendet. Dies kann die Erkennungsrate deutlich verbessern. Deine Daten werden dabei gemäß den Datenschutzbestimmungen verarbeitet.")
            }
            .task {
                // Auth Provider beim Laden der View ermitteln
                authProvider = await supabase.getAuthProvider()
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack {
                    ScrollView {
                        Text("Datenschutzerklärung: Die App nutzt Google Gemini für die Textanalyse. Deine Daten werden sicher verarbeitet...")
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
        }
    }
    
    // MARK: - Credits Section
    
    private var premiumSection: some View {
        Section {
            // Credit Balance Card (Soft Launch)
            creditsCardView
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Credits Card View
    
    private var creditsCardView: some View {
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
                Text("Dein Tagesguthaben")
                    .font(.headline)
                
                Text("\(subscriptionManager.credits) / 20 Credits")
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
    }
    
    // Credit-Farbe basierend auf Anzahl
    private var creditColor: Color {
        let credits = subscriptionManager.credits
        if credits > 10 { return .green }
        if credits > 3 { return .orange }
        return .red
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
    
    // MARK: - Upgrade Button View
    
    private var upgradeButtonView: some View {
        VStack(spacing: 12) {
            // Features Liste
            VStack(alignment: .leading, spacing: 6) {
                Label("Unbegrenzte Zauber-Mails", systemImage: "sparkles")
                Label("Unbegrenzte Leads", systemImage: "infinity")
                Label("Prioritäts-Support", systemImage: "star")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Upgrade Button
            Button {
                showPaywall = true
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Auf Pro upgraden")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Credits kaufen Link
            Button {
                showPaywall = true
            } label: {
                Text("Oder Credits nachkaufen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            // User Info
            if let profile = supabase.userProfile {
                HStack(spacing: 12) {
                    Image(systemName: isAppleSignIn ? "apple.logo" : "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(isAppleSignIn ? Color.primary : Color.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName ?? "MesseMemo User")
                            .font(.headline)
                        
                        if let email = profile.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: profile.isPremium ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundStyle(profile.isPremium ? .yellow : .secondary)
                            
                            Text(profile.isPremium ? "Pro" : "Free")
                                .font(.caption)
                                .foregroundStyle(profile.isPremium ? .yellow : .secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            } else if let userId = supabase.currentUserId {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MesseMemo User")
                            .font(.headline)
                        
                        Text("ID: \(userId.uuidString.prefix(8))...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Account-Status: Warnhinweis oder Bestätigung
            if isAppleSignIn {
                appleIdLinkedView
            } else if authProvider == .email {
                localDataWarningView
            }
            
            // Logout Button
            Button {
                showLogoutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                    Text("Abmelden")
                        .foregroundStyle(.red)
                }
            }
            .disabled(isLoggingOut)
        }
    }
    
    // MARK: - Auth Provider Check
    
    /// Prüft ob der User mit Apple Sign In eingeloggt ist
    private var isAppleSignIn: Bool {
        authProvider == .apple
    }
    
    // MARK: - Account Status Views
    
    /// Warnhinweis für E-Mail-User (kein iCloud-Sync)
    private var localDataWarningView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("⚠️ Lokale Daten")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Du bist per E-Mail eingeloggt. Deine Leads sind an dieses Gerät gebunden. Bitte mache regelmäßige Exporte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.orange.opacity(0.1))
    }
    
    /// Bestätigung für Apple-User (CloudKit-Sync aktiv)
    private var appleIdLinkedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.title2)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("✅ Mit Apple ID verknüpft")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Deine Leads werden automatisch über iCloud synchronisiert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.green.opacity(0.1))
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section("App") {
            NavigationLink {
                Text("Sprache")
            } label: {
                Label("Sprache", systemImage: "globe")
            }
            
            Divider()
            
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
                if let url = URL(string: "mailto:support@messememo.app") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Feedback senden", systemImage: "envelope")
            }
            
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
            Button {
                showDeleteAccountAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                    Text("Account löschen")
                        .foregroundStyle(.red)
                }
            }
        } footer: {
            Text("Wenn du deinen Account löschst, werden alle deine Daten unwiderruflich gelöscht.")
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
        } footer: {
            Text("MesseMemo \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Actions
    
    private func logout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        
        do {
            try await supabase.signOut()
            dismiss()
        } catch {
            print("Logout error: \(error)")
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

