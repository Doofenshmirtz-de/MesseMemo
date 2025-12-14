//
//  SubscriptionManager.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import Foundation
import Combine
import StoreKit

// ============================================
// MARK: - Subscription Manager
// ============================================

/// Zentraler Manager für Premium-Status und In-App Purchases
/// Singleton-Pattern für globalen Zugriff auf Subscription-Status
@MainActor
final class SubscriptionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    /// Gibt an, ob der User Premium-Funktionen nutzen kann
    @Published private(set) var isPremium: Bool = false
    
    /// Gibt an, ob die Subscription gerade geladen wird
    @Published private(set) var isLoading: Bool = false
    
    /// Aktueller Subscription-Typ
    @Published private(set) var subscriptionType: SubscriptionType = .free
    
    /// Letzte Fehler-Nachricht
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseManager.shared
    
    // MARK: - Initialization
    
    private init() {
        setupSubscriptionObserver()
    }
    
    // MARK: - Setup
    
    /// Beobachtet Änderungen am User-Profil und aktualisiert Premium-Status
    private func setupSubscriptionObserver() {
        supabase.$userProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self = self else { return }
                
                if let profile = profile {
                    self.isPremium = profile.isPremium
                    self.subscriptionType = profile.isPremium ? .premium : .free
                } else {
                    self.isPremium = false
                    self.subscriptionType = .free
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Prüft, ob ein Premium-Feature verfügbar ist
    /// - Parameter feature: Das zu prüfende Feature
    /// - Returns: `true` wenn das Feature verfügbar ist
    func canAccess(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .aiEmailGeneration:
            return isPremium
        case .unlimitedLeads:
            return isPremium
        case .cloudSync:
            // Cloud Sync ist für alle verfügbar (via iCloud)
            return true
        case .advancedExport:
            return isPremium
        }
    }
    
    /// Lädt den Subscription-Status neu
    func refreshSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        await supabase.loadUserProfile()
    }
    
    /// Setzt den Premium-Status manuell (für Tests oder Supabase-Webhook)
    /// - Parameter isPremium: Neuer Premium-Status
    func setPremiumStatus(_ isPremium: Bool) {
        self.isPremium = isPremium
        self.subscriptionType = isPremium ? .premium : .free
    }
    
    // MARK: - In-App Purchase (Placeholder)
    
    /// Startet den Kauf-Prozess für Premium
    /// Hinweis: In der finalen Version StoreKit 2 implementieren
    func purchasePremium() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: StoreKit 2 Implementation
        // Für MVP: Simuliere erfolgreichen Kauf
        
        // In Production würde hier der echte IAP-Flow starten:
        // 1. Produkt laden via StoreKit
        // 2. Kauf durchführen
        // 3. Receipt validieren (serverseitig über Supabase Edge Function)
        // 4. Premium-Status in profiles Tabelle setzen
        
        throw SubscriptionError.notImplemented
    }
    
    /// Stellt frühere Käufe wieder her
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: StoreKit 2 Restore Implementation
        
        // Nach Restore: Profile neu laden um Status zu aktualisieren
        await refreshSubscriptionStatus()
    }
}

// ============================================
// MARK: - Enums & Types
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

/// Premium-Features die gesperrt werden können
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

/// Subscription-Fehler
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

