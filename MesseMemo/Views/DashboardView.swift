//
//  DashboardView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
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
    @State private var showNewLead = false
    @State private var showSettings = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if leads.isEmpty {
                    emptyStateView
                } else {
                    leadsList
                }
            }
            .navigationTitle("MesseMemo")
            .searchable(text: $viewModel.searchText, prompt: "Kontakte durchsuchen")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showNewLead) {
                NewLeadView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
                Text("Ersten Kontakt erfassen")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Leads List
    
    private var leadsList: some View {
        List {
            ForEach(viewModel.filterLeads(leads)) { lead in
                NavigationLink(destination: LeadDetailView(lead: lead)) {
                    LeadRowView(lead: lead)
                }
            }
            .onDelete { offsets in
                viewModel.deleteLeads(viewModel.filterLeads(leads), at: offsets, context: modelContext)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                Button(action: { showNewLead = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            if !leads.isEmpty {
                Button(action: { viewModel.exportLeads(leads) }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(viewModel.isExporting)
            }
        }
    }
}

// MARK: - Lead Row View

struct LeadRowView: View {
    let lead: Lead
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Text(lead.displayName.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                if !lead.company.isEmpty {
                    Text(lead.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if !lead.email.isEmpty {
                        Label(lead.email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if lead.hasAudioNote {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Date
            Text(lead.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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

