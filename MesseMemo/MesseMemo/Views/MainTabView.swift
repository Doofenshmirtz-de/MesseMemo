//
//  MainTabView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI
import SwiftData

/// Haupt-Navigation via Tab Bar
struct MainTabView: View {
    
    // MARK: - State
    
    @State private var selectedTab: Int = 0
    
    // Binding für Action Button (Scanner direkt öffnen)
    @Binding var shouldOpenScanner: Bool
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Tab 1: Dashboard
            DashboardView(shouldOpenScanner: $shouldOpenScanner)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 2: Statistik
            StatsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.xaxis")
                }
                .tag(1)
            
            // Tab 3: Einstellungen
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.accentColor)
        .onChange(of: shouldOpenScanner) { _, newValue in
            if newValue {
                // Zum Dashboard wechseln wenn Scanner geöffnet werden soll
                selectedTab = 0
            }
        }
    }
}

#Preview {
    MainTabView(shouldOpenScanner: .constant(false))
        .modelContainer(for: Lead.self, inMemory: true)
}
