//
//  LeadCardView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI

/// Eine Premium-Karte für einen Lead
struct LeadCardView: View {
    
    // MARK: - Properties
    
    let lead: Lead
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar / Initials
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(lead.displayName.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                if !lead.company.isEmpty {
                    Text(lead.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Keine Firma")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            
            Spacer()
            
            // Date / Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(lead.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        LeadCardView(lead: Lead(name: "Max Mustermann", company: "Musterfirma GmbH"))
            .padding()
    }
}
