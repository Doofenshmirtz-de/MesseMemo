//
//  StatsView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  LOCAL-ONLY APP:
//  Zeigt Statistiken über alle lokalen Leads
//

import SwiftUI
import SwiftData
import Charts

/// Statistik-View mit Insights zu den generierten Leads
struct StatsView: View {
    
    // MARK: - Query
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Lead.createdAt, order: .reverse) private var leads: [Lead]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Total Leads Card
                    totalLeadsCard
                    
                    // Weekly Chart
                    weeklyChartCard
                    
                    // Placeholder for future stats
                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Cards
    
    private var totalLeadsCard: some View {
        VStack(spacing: 8) {
            Text("Gesamte Leads")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\(leads.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Leads diese Woche")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                // Einfaches Balkendiagramm für die letzten 7 Tage
                Chart {
                    ForEach(getLast7Days(), id: \.date) { dataPoint in
                        BarMark(
                            x: .value("Tag", dataPoint.dayName),
                            y: .value("Leads", dataPoint.count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                }
                .frame(height: 200)
            } else {
                Text("Charts benötigen iOS 16+")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helper Stats
    
    struct DailyLeadCount {
        let date: Date
        let dayName: String
        let count: Int
    }
    
    private func getLast7Days() -> [DailyLeadCount] {
        var results: [DailyLeadCount] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayName = getDayName(date: date)
                let count = leads.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
                results.append(DailyLeadCount(date: date, dayName: dayName, count: count))
            }
        }
        
        return results
    }
    
    private func getDayName(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE" // Mo, Di, Mi...
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Lead.self, inMemory: true)
}
