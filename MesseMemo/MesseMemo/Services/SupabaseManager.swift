//
//  SupabaseManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  ARCHITEKTUR-HINWEIS:
//  Supabase wird NUR für Auth und KI-Funktionen verwendet.
//  Lead-Daten werden lokal via SwiftData + CloudKit gespeichert (Datenschutz).
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

/// Singleton Manager für Supabase Auth & KI-Funktionen
/// Hinweis: Lead-Daten werden NICHT über Supabase gespeichert!
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
    
    // ============================================
    // MARK: - Auth State
    // ============================================
    
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
    
    // ============================================
    // MARK: - Authentication
    // ============================================
    
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
            // Ohne Session = Email-Bestätigung erforderlich
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
    
    // ============================================
    // MARK: - User Profile & Credits
    // ============================================
    
    /// Lädt das User-Profil (inkl. Credits)
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
    
    /// Aktualisiert das User-Profil (z.B. nach Credit-Verbrauch)
    @MainActor
    func refreshProfile() async {
        await loadUserProfile()
    }
    
    /// Gibt die aktuelle Anzahl der KI-Credits zurück
    var currentCredits: Int {
        userProfile?.aiCreditsBalance ?? 0
    }
    
    /// Prüft, ob der User genug Credits für eine KI-Generierung hat
    var hasCredits: Bool {
        currentCredits > 0
    }
    
    // ============================================
    // MARK: - Auth Provider Detection
    // ============================================
    
    /// Prüft ob der User mit Apple Sign In eingeloggt ist
    /// Wichtig für UI-Hinweise bzgl. CloudKit-Sync vs. lokale Daten
    var isAppleLogin: Bool {
        // Versuche den Provider aus der aktuellen Session zu lesen
        guard let userId = currentUserId else { return false }
        
        // Methode 1: App Metadata prüfen (wenn verfügbar)
        // Die Session speichert den Provider in user.appMetadata
        Task {
            do {
                let session = try await client.auth.session
                if let provider = session.user.appMetadata["provider"]?.value as? String {
                    return provider.lowercased() == "apple"
                }
                // Fallback: Identities prüfen
                if let identities = session.user.identities {
                    return identities.contains { $0.provider.lowercased() == "apple" }
                }
            } catch {
                // Session nicht verfügbar
            }
            return false
        }
        
        // Synchroner Fallback: E-Mail-Adresse prüfen
        // Apple Private Relay E-Mails enden auf @privaterelay.appleid.com
        if let email = userProfile?.email {
            if email.contains("@privaterelay.appleid.com") {
                return true
            }
            // Normale E-Mail = wahrscheinlich Email-Login
            return false
        }
        
        // Keine E-Mail = könnte Apple Login mit versteckter E-Mail sein
        return false
    }
    
    /// Auth-Provider des aktuellen Users (async, da Session-Zugriff)
    @MainActor
    func getAuthProvider() async -> AuthProvider {
        guard isAuthenticated else { return .unknown }
        
        do {
            let session = try await client.auth.session
            
            // Prüfe app_metadata für Provider
            if let providerValue = session.user.appMetadata["provider"] {
                // AnyJSON zu String konvertieren
                let providerString = String(describing: providerValue).lowercased()
                if providerString.contains("apple") {
                    return .apple
                } else if providerString.contains("email") || providerString.contains("password") {
                    return .email
                }
            }
            
            // Fallback: Identities prüfen
            if let identities = session.user.identities {
                for identity in identities {
                    if identity.provider.lowercased() == "apple" {
                        return .apple
                    }
                }
            }
            
            // Fallback: E-Mail-Muster prüfen
            if let email = session.user.email {
                if email.contains("@privaterelay.appleid.com") {
                    return .apple
                }
            }
            
            // Standard: Email-Login (wenn keine Apple-Indikatoren gefunden)
            return .email
            
        } catch {
            return .unknown
        }
    }
    
    // ============================================
    // MARK: - AI Email Generation (Edge Function)
    // ============================================
    
    /// Generiert eine Follow-Up E-Mail via Edge Function
    /// Verbraucht 1 Credit bei Erfolg
    /// - Returns: Generierte E-Mail mit Betreff und Body, sowie verbleibende Credits
    func generateEmail(
        name: String,
        company: String,
        transcript: String
    ) async throws -> GeneratedEmailResult {
        guard isAuthenticated else {
            throw SupabaseError.notAuthenticated
        }
        
        // Request Body erstellen
        let requestBody: [String: String] = [
            "name": name,
            "company": company,
            "transcript": transcript
        ]
        
        // Edge Function aufrufen (prüft Credits serverseitig)
        let response: GenerateEmailResponse = try await client.functions.invoke(
            "generate-email",
            options: FunctionInvokeOptions(body: requestBody)
        )
        
        // Fehlerbehandlung
        if let error = response.error {
            if error.contains("Kein Guthaben") || error.contains("credits") {
                throw SupabaseError.noCredits
            }
            throw SupabaseError.emailGenerationFailed(error)
        }
        
        guard response.success,
              let email = response.email,
              let subject = response.subject else {
            throw SupabaseError.emailGenerationFailed("Unbekannter Fehler")
        }
        
        // Profile aktualisieren um neuen Credit-Stand zu bekommen
        await MainActor.run {
            Task {
                await refreshProfile()
            }
        }
        
        return GeneratedEmailResult(
            email: GeneratedEmail(subject: subject, body: email),
            creditsRemaining: response.creditsRemaining ?? (currentCredits - 1)
        )
    }
    
    // ============================================
    // MARK: - Helper
    // ============================================
    
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

/// User Profile Modell (mit Credit-System)
struct UserProfile: Codable {
    let id: UUID
    let email: String?
    let isPremium: Bool
    let displayName: String?
    let aiCreditsBalance: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case isPremium = "is_premium"
        case displayName = "display_name"
        case aiCreditsBalance = "ai_credits_balance"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Fallback-Initializer für Profile ohne Credits-Spalte
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        aiCreditsBalance = try container.decodeIfPresent(Int.self, forKey: .aiCreditsBalance) ?? 0
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}

/// Response von generate-email Edge Function
struct GenerateEmailResponse: Codable {
    let success: Bool
    let email: String?
    let subject: String?
    let error: String?
    let creditsRemaining: Int?
    
    enum CodingKeys: String, CodingKey {
        case success
        case email
        case subject
        case error
        case creditsRemaining = "credits_remaining"
    }
}

/// Generierte E-Mail
struct GeneratedEmail {
    let subject: String
    let body: String
}

/// Ergebnis der E-Mail-Generierung inkl. Credits
struct GeneratedEmailResult {
    let email: GeneratedEmail
    let creditsRemaining: Int
}

// ============================================
// MARK: - Errors
// ============================================

enum SupabaseError: Error, LocalizedError {
    case notAuthenticated
    case noCredits
    case emailGenerationFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Bitte melde dich an, um fortzufahren."
        case .noCredits:
            return "Kein Guthaben mehr. Bitte lade dein Konto auf."
        case .emailGenerationFailed(let reason):
            return "E-Mail konnte nicht generiert werden: \(reason)"
        case .networkError:
            return "Keine Internetverbindung."
        }
    }
}

// ============================================
// MARK: - Auth Provider Enum
// ============================================

/// Auth-Provider Typen
enum AuthProvider {
    case apple      // Sign in with Apple
    case email      // Email/Password Login
    case unknown    // Nicht bestimmbar
    
    /// Ob CloudKit-Sync verfügbar ist (nur mit Apple ID)
    var hasCloudSync: Bool {
        self == .apple
    }
    
    /// Benutzerfreundlicher Name
    var displayName: String {
        switch self {
        case .apple: return "Apple ID"
        case .email: return "E-Mail"
        case .unknown: return "Unbekannt"
        }
    }
}
