//
//  DashboardView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  LOCAL-ONLY APP:
//  Alle Leads werden angezeigt (keine Auth-Prüfung)
//

import SwiftUI
import SwiftData

/// Hauptansicht mit der Liste aller Leads
struct DashboardView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lead.createdAt, order: .reverse) private var leads: [Lead]
    
    // MARK: - State
    
    @StateObject private var viewModel = LeadsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showNewLead = false
    
    // Binding für Action Button (Scanner direkt öffnen)
    @Binding var shouldOpenScanner: Bool
    
    /// Gefilterte Leads
    private var filteredLeads: [Lead] {
        viewModel.filterLeads(leads)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    customHeader
                    
                    if filteredLeads.isEmpty {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        // Card List
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredLeads) { lead in
                                    NavigationLink(destination: LeadDetailView(lead: lead)) {
                                        LeadCardView(lead: lead)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                // Floating Action Button
                floatingActionButton
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showNewLead) {
                NewLeadView()
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .onChange(of: shouldOpenScanner) { _, newValue in
                if newValue {
                    showNewLead = true
                    shouldOpenScanner = false
                }
            }
        }
    }
    
    // MARK: - Custom Header
    
    private var customHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MesseMemo")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                // Credit Badge
                Text("\(subscriptionManager.credits) Credits")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Leads Counter
            if !leads.isEmpty {
                Text("\(leads.count) Kontakte")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Floating Action Button (groß und prominent)
    
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showNewLead = true }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Keine Kontakte", systemImage: "person.crop.rectangle.stack")
        } description: {
            Text("Erfasse deinen ersten Lead auf einer Messe, indem du eine Visitenkarte scannst.")
        } actions: {
            Button(action: { showNewLead = true }) {
                HStack {
                    Image(systemName: "plus.viewfinder")
                    Text("Ersten Kontakt erfassen")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Preview

#Preview {
    DashboardView(shouldOpenScanner: .constant(false))
        .modelContainer(for: Lead.self, inMemory: true)
}
