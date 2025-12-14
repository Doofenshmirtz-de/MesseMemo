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
                
                // MARK: - Danger Zone
                dangerZoneSection
                
                // MARK: - App Info
                appInfoSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
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
        }
    }
    
    // MARK: - Premium Section
    
    private var premiumSection: some View {
        Section {
            if subscriptionManager.isPremium {
                // User ist Premium
                premiumActiveView
            } else {
                // User ist Free - zeige Upgrade Banner
                premiumUpgradeView
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Premium Active View
    
    private var premiumActiveView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("MesseMemo Pro")
                    .font(.headline)
                
                Text("Alle Premium-Features aktiv")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Premium Upgrade View
    
    private var premiumUpgradeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MesseMemo Pro")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("KI-generierte Follow-up Mails", systemImage: "sparkles")
                        Label("Unbegrenzte Leads", systemImage: "infinity")
                        Label("Cloud-Sync", systemImage: "icloud")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Decorative circles
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .offset(x: 10, y: -10)
                    
                    Circle()
                        .fill(.purple.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .offset(x: -15, y: 15)
                    
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundStyle(.yellow)
                }
            }
            
            Button {
                showPaywall = true
                // Haptic Feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                Text("Jetzt upgraden")
                    .font(.headline)
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
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            // User Info
            if let profile = supabase.userProfile {
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    
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
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section("App") {
            NavigationLink {
                Text("Benachrichtigungen")
            } label: {
                Label("Benachrichtigungen", systemImage: "bell.badge")
            }
            
            NavigationLink {
                Text("Erscheinungsbild")
            } label: {
                Label("Erscheinungsbild", systemImage: "paintbrush")
            }
            
            NavigationLink {
                Text("Sprache")
            } label: {
                Label("Sprache", systemImage: "globe")
            }
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
            
            NavigationLink {
                Text("Datenschutzerklärung")
            } label: {
                Label("Datenschutz", systemImage: "hand.raised")
            }
            
            NavigationLink {
                Text("Nutzungsbedingungen")
            } label: {
                Label("Nutzungsbedingungen", systemImage: "doc.text")
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

