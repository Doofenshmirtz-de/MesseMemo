//
//  SupabaseManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  LOCAL-ONLY APP:
//  Supabase wird NUR für KI-Funktionen (Edge Functions) verwendet.
//  Keine Authentifizierung, keine User-Profile.
//  Credits werden lokal via SubscriptionManager verwaltet.
//

import Foundation
import Combine
import Supabase

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

/// Manager für Supabase Edge Functions (KI-Features)
/// Keine Authentifizierung - alle Calls sind anonym
final class SupabaseManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SupabaseManager()
    
    // MARK: - Supabase Client
    
    let client: SupabaseClient
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // ============================================
    // MARK: - AI Email Generation (Edge Function)
    // ============================================
    
    /// Generiert eine Follow-Up E-Mail via Edge Function
    /// Credits werden lokal via SubscriptionManager verwaltet
    /// - Returns: Generierte E-Mail mit Betreff und Body
    func generateEmail(
        name: String,
        company: String,
        transcript: String
    ) async throws -> GeneratedEmail {
        
        // Request Body erstellen
        let requestBody: [String: String] = [
            "name": name,
            "company": company,
            "transcript": transcript
        ]
        
        // Edge Function aufrufen (ohne Auth)
        let response: GenerateEmailResponse = try await client.functions.invoke(
            "generate-email",
            options: FunctionInvokeOptions(body: requestBody)
        )
        
        // Fehlerbehandlung
        if let error = response.error {
            throw SupabaseError.emailGenerationFailed(error)
        }
        
        guard response.success,
              let email = response.email,
              let subject = response.subject else {
            throw SupabaseError.emailGenerationFailed("Unbekannter Fehler")
        }
        
        return GeneratedEmail(subject: subject, body: email)
    }
    
    // ============================================
    // MARK: - AI Card Processing (Edge Function)
    // ============================================
    
    /// Verarbeitet OCR-Text via Edge Function (Gemini) zu strukturierten Daten
    func processCard(text: [String]) async throws -> ParsedContactCloudData {
        
        let requestBody: [String: [String]] = [
            "text": text
        ]
        
        let response: ProcessCardResponse = try await client.functions.invoke(
            "process-card",
            options: FunctionInvokeOptions(body: requestBody)
        )
        
        if let error = response.error {
            throw SupabaseError.emailGenerationFailed(error)
        }
        
        guard response.success, let data = response.data else {
            throw SupabaseError.emailGenerationFailed("Keine Daten zurückerhalten")
        }
        
        return data
    }
}

// ============================================
// MARK: - Data Models
// ============================================

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

// MARK: - Process Card Models

struct ProcessCardResponse: Codable {
    let success: Bool
    let data: ParsedContactCloudData?
    let error: String?
    let creditsRemaining: Int?
    
    enum CodingKeys: String, CodingKey {
        case success
        case data
        case error
        case creditsRemaining = "credits_remaining"
    }
}

struct ParsedContactCloudData: Codable {
    let name: String?
    let company: String?
    let email: String?
    let phone: String?
    let job_title: String?
    let website: String?
    let address: String?
}

// ============================================
// MARK: - Errors
// ============================================

enum SupabaseError: Error, LocalizedError {
    case emailGenerationFailed(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .emailGenerationFailed(let reason):
            return "KI-Verarbeitung fehlgeschlagen: \(reason)"
        case .networkError:
            return "Keine Internetverbindung."
        }
    }
}
