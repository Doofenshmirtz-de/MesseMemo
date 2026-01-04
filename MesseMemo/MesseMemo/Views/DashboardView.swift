//
//  DashboardView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  MULTI-TENANCY:
//  Leads werden nach ownerId gefiltert, sodass jeder User nur seine eigenen sieht.
//  Das Filtering erfolgt im LeadsViewModel.filterLeads()
//

import SwiftUI
import SwiftData

/// Hauptansicht mit der Liste aller Leads
/// Multi-Tenancy: Zeigt nur Leads des aktuell eingeloggten Users
struct DashboardView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lead.createdAt, order: .reverse) private var leads: [Lead]
    
    // MARK: - Supabase (für Refresh bei Login-Änderung)
    
    @ObservedObject private var supabase = SupabaseManager.shared
    
    // MARK: - State
    
    @StateObject private var viewModel = LeadsViewModel()
    @State private var showNewLead = false
    @State private var showSettings = false
    
    /// Gefilterte Leads (nur die des aktuellen Users)
    private var userLeads: [Lead] {
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
                    
                    if userLeads.isEmpty {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        // Card List
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(userLeads) { lead in
                                    NavigationLink(destination: LeadDetailView(lead: lead)) {
                                        LeadCardView(lead: lead)
                                    }
                                    .buttonStyle(.plain) // Wichtig damit die Card nicht blau wird
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarHidden(true) // Standard Navbar verstecken
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
            // Reagiert auf Auth-Änderungen (Login/Logout) um die Liste zu aktualisieren
            .onChange(of: supabase.currentUserId) { _, _ in
                // SwiftUI aktualisiert automatisch, da userLeads computed ist
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
            
            // Add Lead Button (Mini)
            Button(action: { showNewLead = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.systemGray6)) // Blendet mit Hintergrund
    }
    
    // MARK: - Subscription Manager
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Keine Kontakte", systemImage: "person.crop.rectangle.stack")
        } description: {
            Text("Erfasse deinen ersten Lead auf einer Messe, indem du eine Visitenkarte scannst.")
        } actions: {
            Button(action: { showNewLead = true }) {
                Text("Ersten Kontakt erfassen")
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
    DashboardView()
        .modelContainer(for: Lead.self, inMemory: true)
}

