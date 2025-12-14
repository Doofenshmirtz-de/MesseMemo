//
//  SupabaseManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import Foundation
import Combine
import Supabase
import Auth

// ============================================
// MARK: - Supabase Configuration
// ============================================

/// Konfiguration für Supabase
enum SupabaseConfig {
    /// Deine Supabase Project URL
    static let url = "https://vdbdawqkdwbnlytddfpp.supabase.co"
    
    /// Dein Supabase Anon Key
    static let anonKey = "sb_publishable_vJaMIqZRk3bxFJmHGpDJzg_l004-Vgd"
}

// ============================================
// MARK: - SupabaseManager
// ============================================

/// Singleton Manager für alle Supabase-Operationen
final class SupabaseManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SupabaseManager()
    
    // MARK: - Supabase Client
    
    let client: SupabaseClient
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        // Auth State beim Start prüfen
        Task { @MainActor in
            await checkAuthState()
        }
    }
    
    // MARK: - Auth State
    
    /// Prüft den aktuellen Auth-Status
    @MainActor
    func checkAuthState() async {
        do {
            let session = try await client.auth.session
            self.currentUserId = session.user.id
            self.isAuthenticated = true
            await loadUserProfile()
        } catch {
            self.isAuthenticated = false
            self.currentUserId = nil
            self.userProfile = nil
        }
    }
    
    // MARK: - Authentication
    
    /// Registriert einen neuen User
    @MainActor
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            // Session vorhanden = User ist eingeloggt
            if let session = response.session {
                self.currentUserId = session.user.id
                self.isAuthenticated = true
                await loadUserProfile()
            }
            // Ohne Session = Email-Bestätigung erforderlich (normal bei Registrierung)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    /// Loggt einen User ein
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            self.currentUserId = session.user.id
            self.isAuthenticated = true
            await loadUserProfile()
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    /// Loggt den User aus
    @MainActor
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await client.auth.signOut()
        self.currentUserId = nil
        self.userProfile = nil
        self.isAuthenticated = false
    }
    
    /// Passwort zurücksetzen
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    /// Sign in with Apple
    @MainActor
    func signInWithApple(idToken: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            self.currentUserId = session.user.id
            self.isAuthenticated = true
            await loadUserProfile()
        } catch {
            errorMessage = "Apple Sign In fehlgeschlagen."
            throw error
        }
    }
    
    // MARK: - User Profile
    
    /// Lädt das User-Profil
    @MainActor
    func loadUserProfile() async {
        guard let userId = currentUserId else { return }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(UserProfile.self, from: response.data)
            self.userProfile = profile
        } catch {
            print("Error loading profile: \(error)")
        }
    }
    
    // MARK: - Leads CRUD
    
    /// Lädt alle Leads des Users
    func fetchLeads() async throws -> [SupabaseLead] {
        let response = try await client
            .from("leads")
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let leads = try JSONDecoder().decode([SupabaseLead].self, from: response.data)
        return leads
    }
    
    /// Erstellt einen neuen Lead
    func createLead(_ lead: SupabaseLead) async throws -> SupabaseLead {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        var newLead = lead
        newLead.userId = userId
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(newLead)
        
        let response = try await client
            .from("leads")
            .insert(data)
            .select()
            .single()
            .execute()
        
        let createdLead = try JSONDecoder().decode(SupabaseLead.self, from: response.data)
        return createdLead
    }
    
    /// Aktualisiert einen Lead
    func updateLead(_ lead: SupabaseLead) async throws {
        guard let id = lead.id else { return }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(lead)
        
        try await client
            .from("leads")
            .update(data)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Löscht einen Lead
    func deleteLead(id: UUID) async throws {
        try await client
            .from("leads")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Audio Storage
    
    /// Lädt eine Audio-Datei hoch
    func uploadAudio(data: Data, fileName: String) async throws -> String {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        let path = "\(userId.uuidString)/\(fileName)"
        
        try await client.storage
            .from("voice-memos")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "audio/m4a")
            )
        
        return path
    }
    
    /// Holt die signierte URL einer Audio-Datei
    func getAudioURL(path: String) async throws -> URL {
        try await client.storage
            .from("voice-memos")
            .createSignedURL(path: path, expiresIn: 3600)
    }
    
    /// Löscht eine Audio-Datei
    func deleteAudio(path: String) async throws {
        try await client.storage
            .from("voice-memos")
            .remove(paths: [path])
    }
    
    // MARK: - AI Email Generation
    
    /// Generiert eine Follow-Up E-Mail via Edge Function
    /// Hinweis: Edge Function muss erst deployed werden!
    func generateEmail(name: String, company: String, transcript: String, leadId: UUID? = nil) async throws -> GeneratedEmail {
        guard isAuthenticated else {
            throw SupabaseError.notAuthenticated
        }
        
        // Request Body erstellen
        let requestBody: [String: String] = [
            "name": name,
            "company": company,
            "transcript": transcript,
            "leadId": leadId?.uuidString ?? ""
        ]
        
        // Edge Function aufrufen
        let response: GenerateEmailResponse = try await client.functions.invoke(
            "generate-email",
            options: FunctionInvokeOptions(body: requestBody)
        )
        
        if response.success, let email = response.email, let subject = response.subject {
            return GeneratedEmail(subject: subject, body: email)
        } else {
            throw SupabaseError.emailGenerationFailed(response.error ?? "Unbekannter Fehler")
        }
    }
    
    // MARK: - Helper
    
    private func mapAuthError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid login") || errorString.contains("invalid credentials") {
            return "E-Mail oder Passwort ist falsch."
        } else if errorString.contains("email not confirmed") {
            return "Bitte bestätige zuerst deine E-Mail-Adresse."
        } else if errorString.contains("user already registered") {
            return "Diese E-Mail ist bereits registriert."
        } else if errorString.contains("password") && errorString.contains("weak") {
            return "Das Passwort muss mindestens 6 Zeichen haben."
        } else if errorString.contains("network") {
            return "Keine Internetverbindung."
        }
        
        return "Ein Fehler ist aufgetreten. Bitte versuche es erneut."
    }
}

// ============================================
// MARK: - Data Models
// ============================================

/// User Profile Modell
struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let isPremium: Bool
    let displayName: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isPremium = "is_premium"
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Lead Modell für Supabase
struct SupabaseLead: Codable, Identifiable {
    var id: UUID?
    var userId: UUID?
    var name: String
    var company: String
    var email: String
    var phone: String
    var noteText: String
    var transcript: String?
    var audioUrl: String?
    var audioDurationSeconds: Int?
    var generatedEmail: String?
    var createdAt: String?
    var updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case company
        case email
        case phone
        case noteText = "note_text"
        case transcript
        case audioUrl = "audio_url"
        case audioDurationSeconds = "audio_duration_seconds"
        case generatedEmail = "generated_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response von generate-email Edge Function
struct GenerateEmailResponse: Codable {
    let success: Bool
    let email: String?
    let subject: String?
    let error: String?
}

/// Generierte E-Mail
struct GeneratedEmail {
    let subject: String
    let body: String
}

// ============================================
// MARK: - Errors
// ============================================

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case emailGenerationFailed(String)
    case uploadFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Bitte melde dich an, um fortzufahren."
        case .emailGenerationFailed(let reason):
            return "E-Mail konnte nicht generiert werden: \(reason)"
        case .uploadFailed:
            return "Upload fehlgeschlagen."
        case .networkError:
            return "Keine Internetverbindung."
        }
    }
}
