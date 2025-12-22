//
//  SubscriptionManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  ARCHITEKTUR-HINWEIS:
//  - Freemium-Modell mit Credit-System
//  - Neue User bekommen 20 kostenlose Credits
//  - Pro-User bekommen unbegrenzte Credits (oder können nachkaufen)
//

import Foundation
import Combine
import StoreKit

// ============================================
// MARK: - Subscription Manager
// ============================================

/// Zentraler Manager für Credits und Subscription-Status
/// Singleton-Pattern für globalen Zugriff
@MainActor
final class SubscriptionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    /// Aktuelle Anzahl der KI-Credits
    @Published private(set) var credits: Int = 0
    
    /// Gibt an, ob der User Pro-Subscriber ist
    @Published private(set) var isPremium: Bool = false
    
    /// Gibt an, ob Daten geladen werden
    @Published private(set) var isLoading: Bool = false
    
    /// Aktueller Subscription-Typ
    @Published private(set) var subscriptionType: SubscriptionType = .free
    
    /// Letzte Fehler-Nachricht
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseManager.shared
    
    // MARK: - Constants
    
    /// Anzahl der Credits, die neue User bekommen
    static let initialCredits = 20
    
    // MARK: - Initialization
    
    private init() {
        setupProfileObserver()
    }
    
    // MARK: - Setup
    
    /// Beobachtet Änderungen am User-Profil und aktualisiert Credits/Status
    private func setupProfileObserver() {
        supabase.$userProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self = self else { return }
                
                if let profile = profile {
                    self.credits = profile.aiCreditsBalance
                    self.isPremium = profile.isPremium
                    self.subscriptionType = profile.isPremium ? .premium : .free
                } else {
                    self.credits = 0
                    self.isPremium = false
                    self.subscriptionType = .free
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Credits & Access Control
    
    /// Prüft, ob der User genug Credits für eine KI-Generierung hat
    var hasCredits: Bool {
        credits > 0 || isPremium
    }
    
    /// Prüft, ob ein Feature verfügbar ist
    /// - Parameter feature: Das zu prüfende Feature
    /// - Returns: `true` wenn das Feature verfügbar ist
    func canAccess(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .aiEmailGeneration:
            // KI-Mails benötigen Credits ODER Premium
            return hasCredits
        case .unlimitedLeads:
            // Unbegrenzte Leads nur für Premium
            return isPremium
        case .cloudSync:
            // Cloud Sync ist für alle verfügbar (via iCloud)
            return true
        case .advancedExport:
            // Erweiterter Export nur für Premium
            return isPremium
        }
    }
    
    /// Formatierte Anzeige der Credits
    var creditsDisplayText: String {
        if isPremium {
            return "∞"
        }
        return "\(credits)"
    }
    
    /// Text für den Zauber-Mail Button
    var aiButtonSubtitle: String {
        if isPremium {
            return "Unbegrenzt verfügbar"
        } else if credits > 0 {
            return "Noch \(credits)× verfügbar"
        } else {
            return "Keine Credits mehr"
        }
    }
    
    // MARK: - Refresh
    
    /// Lädt den Status neu
    func refreshStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        await supabase.refreshProfile()
    }
    
    // MARK: - In-App Purchase (Credit Packs)
    
    /// Kauft ein Credit-Paket
    /// - Parameter pack: Das zu kaufende Paket
    func purchaseCredits(pack: CreditPack) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: StoreKit 2 Implementation für Credit-Packs
        // 1. Produkt laden via StoreKit
        // 2. Kauf durchführen
        // 3. Receipt validieren (serverseitig)
        // 4. Credits in profiles Tabelle hinzufügen
        
        throw SubscriptionError.notImplemented
    }
    
    /// Kauft Pro-Subscription
    func purchasePremium() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: StoreKit 2 Implementation für Subscription
        
        throw SubscriptionError.notImplemented
    }
    
    /// Stellt frühere Käufe wieder her
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: StoreKit 2 Restore Implementation
        
        await refreshStatus()
    }
}

// ============================================
// MARK: - Credit Packs
// ============================================

/// Verfügbare Credit-Pakete
enum CreditPack: String, CaseIterable, Identifiable {
    case small = "10 Credits"
    case medium = "50 Credits"
    case large = "200 Credits"
    
    var id: String { rawValue }
    
    var credits: Int {
        switch self {
        case .small: return 10
        case .medium: return 50
        case .large: return 200
        }
    }
    
    var price: String {
        switch self {
        case .small: return "2,99 €"
        case .medium: return "9,99 €"
        case .large: return "29,99 €"
        }
    }
    
    var savings: String? {
        switch self {
        case .small: return nil
        case .medium: return "Spare 33%"
        case .large: return "Spare 50%"
        }
    }
    
    var productId: String {
        switch self {
        case .small: return "com.messememo.credits.10"
        case .medium: return "com.messememo.credits.50"
        case .large: return "com.messememo.credits.200"
        }
    }
}

// ============================================
// MARK: - Subscription Types
// ============================================

/// Subscription-Typen
enum SubscriptionType: String, CaseIterable {
    case free = "Free"
    case premium = "Pro"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "MesseMemo Pro"
        }
    }
    
    var icon: String {
        switch self {
        case .free: return "person.circle"
        case .premium: return "crown.fill"
        }
    }
}

/// Premium-Features
enum PremiumFeature: String, CaseIterable {
    case aiEmailGeneration = "KI E-Mail Generierung"
    case unlimitedLeads = "Unbegrenzte Leads"
    case cloudSync = "Cloud Sync"
    case advancedExport = "Erweiterter Export"
    
    var description: String {
        switch self {
        case .aiEmailGeneration:
            return "Generiere professionelle Follow-up E-Mails mit KI"
        case .unlimitedLeads:
            return "Speichere unbegrenzt viele Kontakte"
        case .cloudSync:
            return "Synchronisiere deine Daten über alle Geräte"
        case .advancedExport:
            return "Exportiere Leads als CSV, Excel oder vCard"
        }
    }
    
    var icon: String {
        switch self {
        case .aiEmailGeneration: return "sparkles"
        case .unlimitedLeads: return "infinity"
        case .cloudSync: return "icloud"
        case .advancedExport: return "square.and.arrow.up"
        }
    }
}

// ============================================
// MARK: - Errors
// ============================================

enum SubscriptionError: Error, LocalizedError {
    case notImplemented
    case purchaseFailed
    case restoreFailed
    case noProductsAvailable
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "In-App Käufe sind noch nicht verfügbar."
        case .purchaseFailed:
            return "Der Kauf konnte nicht abgeschlossen werden."
        case .restoreFailed:
            return "Käufe konnten nicht wiederhergestellt werden."
        case .noProductsAvailable:
            return "Keine Produkte verfügbar."
        }
    }
}
