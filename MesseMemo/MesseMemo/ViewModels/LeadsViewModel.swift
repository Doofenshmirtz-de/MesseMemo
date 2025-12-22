//
//  LeadsViewModel.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel für die Verwaltung von Leads
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
    
    // MARK: - Computed Properties
    
    /// Filtert Leads basierend auf dem Suchtext
    func filterLeads(_ leads: [Lead]) -> [Lead] {
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

