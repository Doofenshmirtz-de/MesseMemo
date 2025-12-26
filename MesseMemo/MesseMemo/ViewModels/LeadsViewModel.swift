//
//  LeadsViewModel.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//
//  MULTI-TENANCY:
//  Leads werden nach ownerId gefiltert, sodass jeder User nur seine eigenen sieht.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel für die Verwaltung von Leads
/// Implementiert Multi-Tenancy: Jeder User sieht nur seine eigenen Leads
@MainActor
final class LeadsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchText = ""
    @Published var isExporting = false
    @Published var exportURL: URL?
    @Published var showExportSheet = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Services
    
    private let csvExportService = CSVExportService()
    
    // MARK: - Multi-Tenancy
    
    /// Gibt die aktuelle Owner-ID zurück (Supabase User-ID oder Fallback)
    var currentOwnerId: String {
        SupabaseManager.shared.currentUserId?.uuidString ?? "local_user"
    }
    
    /// Filtert Leads nach Owner-ID UND Suchtext
    /// Dies ist die Hauptmethode für Multi-Tenancy auf App-Ebene
    func filterLeads(_ leads: [Lead]) -> [Lead] {
        // 1. Zuerst nach Owner filtern (Multi-Tenancy)
        let ownedLeads = leads.filter { lead in
            lead.ownerId == currentOwnerId
        }
        
        // 2. Dann nach Suchtext filtern (falls vorhanden)
        guard !searchText.isEmpty else { return ownedLeads }
        
        return ownedLeads.filter { lead in
            lead.name.localizedCaseInsensitiveContains(searchText) ||
            lead.company.localizedCaseInsensitiveContains(searchText) ||
            lead.email.localizedCaseInsensitiveContains(searchText) ||
            lead.phone.contains(searchText)
        }
    }
    
    /// Filtert Leads nur nach Suchtext (ohne Owner-Filter)
    /// Nützlich wenn die Leads bereits vorselektiert sind
    func filterBySearchText(_ leads: [Lead]) -> [Lead] {
        guard !searchText.isEmpty else { return leads }
        
        return leads.filter { lead in
            lead.name.localizedCaseInsensitiveContains(searchText) ||
            lead.company.localizedCaseInsensitiveContains(searchText) ||
            lead.email.localizedCaseInsensitiveContains(searchText) ||
            lead.phone.contains(searchText)
        }
    }
    
    /// Sortiert Leads nach Erstellungsdatum (neueste zuerst)
    func sortLeads(_ leads: [Lead]) -> [Lead] {
        leads.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - Export
    
    /// Exportiert alle Leads als CSV
    func exportLeads(_ leads: [Lead]) {
        isExporting = true
        
        do {
            let fileURL = try csvExportService.createCSVFile(from: leads)
            exportURL = fileURL
            showExportSheet = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isExporting = false
    }
    
    // MARK: - Lead Management
    
    /// Löscht einen Lead und seine zugehörige Audiodatei
    func deleteLead(_ lead: Lead, context: ModelContext) {
        // Audiodatei löschen falls vorhanden
        if let audioPath = lead.audioFilePath {
            let audioService = AudioService()
            audioService.deleteRecording(at: audioPath)
        }
        
        // Lead aus der Datenbank löschen
        context.delete(lead)
    }
    
    /// Löscht mehrere Leads
    func deleteLeads(_ leads: [Lead], at offsets: IndexSet, context: ModelContext) {
        for index in offsets {
            deleteLead(leads[index], context: context)
        }
    }
}

