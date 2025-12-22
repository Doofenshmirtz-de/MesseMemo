//
//  PaywallView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI

/// Paywall-Sheet für Premium-Upgrade
/// Zeigt die Vorteile von MesseMemo Pro und ermöglicht den Kauf
struct PaywallView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // MARK: - State
    
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPlan: PricingPlan = .yearly
    
    // MARK: - Properties
    
    /// Das Feature, das den Paywall-Trigger ausgelöst hat
    var triggerFeature: PremiumFeature?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Feature Trigger Info
                    if let feature = triggerFeature {
                        featureTriggerBanner(feature: feature)
                    }
                    
                    // Features Liste
                    featuresSection
                    
                    // Pricing Options
                    pricingSection
                    
                    // CTA Button
                    purchaseButton
                    
                    // Restore & Terms
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.purple.opacity(0.05),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Fehler", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pro Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .yellow.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("MesseMemo Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Entfessle das volle Potenzial")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Feature Trigger Banner
    
    private func featureTriggerBanner(feature: PremiumFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Du möchtest:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(feature.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Alle Pro-Features")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(PremiumFeature.allCases, id: \.self) { feature in
                    FeatureRow(feature: feature)
                }
            }
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(PricingPlan.allCases, id: \.self) { plan in
                PricingCard(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlan = plan
                        }
                        // Haptic Feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                )
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Jetzt upgraden")
                        .fontWeight(.bold)
                    
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .purple.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .disabled(isProcessing)
        .scaleEffect(isProcessing ? 0.98 : 1)
        .animation(.spring(response: 0.2), value: isProcessing)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore Button
            Button("Käufe wiederherstellen") {
                Task {
                    await restore()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(isProcessing)
            
            // Terms
            Text("Abonnement verlängert sich automatisch. Jederzeit kündbar über die App Store Einstellungen.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            // Links
            HStack(spacing: 16) {
                Button("Datenschutz") {
                    // TODO: Open Privacy Policy
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                Button("AGB") {
                    // TODO: Open Terms
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Actions
    
    private func purchase() async {
        isProcessing = true
        defer { isProcessing = false }
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        
        do {
            try await subscriptionManager.purchasePremium()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            generator.notificationOccurred(.error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        
        let generator = UINotificationFeedbackGenerator()
        
        do {
            try await subscriptionManager.restorePurchases()
            
            if subscriptionManager.isPremium {
                generator.notificationOccurred(.success)
                dismiss()
            } else {
                generator.notificationOccurred(.warning)
                errorMessage = "Keine aktiven Käufe gefunden."
                showError = true
            }
        } catch {
            generator.notificationOccurred(.error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let feature: PremiumFeature
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: feature.icon)
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let plan: PricingPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.headline)
                        
                        if plan.isBestValue {
                            Text("BELIEBT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                        }
                    }
                    
                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(plan.period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pricing Plan

private enum PricingPlan: CaseIterable {
    case monthly
    case yearly
    
    var name: String {
        switch self {
        case .monthly: return "Monatlich"
        case .yearly: return "Jährlich"
        }
    }
    
    var subtitle: String {
        switch self {
        case .monthly: return "Flexibel kündbar"
        case .yearly: return "Spare 33%"
        }
    }
    
    var price: String {
        switch self {
        case .monthly: return "4,99 €"
        case .yearly: return "39,99 €"
        }
    }
    
    var period: String {
        switch self {
        case .monthly: return "/ Monat"
        case .yearly: return "/ Jahr"
        }
    }
    
    var isBestValue: Bool {
        self == .yearly
    }
}

// MARK: - Preview

#Preview {
    PaywallView(triggerFeature: .aiEmailGeneration)
}

