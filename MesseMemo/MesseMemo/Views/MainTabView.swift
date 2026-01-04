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
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Tab 1: Dashboard
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 2: Statistik (Neu)
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
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Lead.self, inMemory: true)
}
