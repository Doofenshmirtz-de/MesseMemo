//
//  RootView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI

/// Root View die zwischen Auth und Dashboard wechselt
struct RootView: View {
    
    @StateObject private var supabase = SupabaseManager.shared
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Splash Screen während Auth-Check
                splashView
            } else if supabase.isAuthenticated {
                // User ist eingeloggt
                MainTabView()
            } else {
                // User ist nicht eingeloggt
                AuthView()
            }
        }
        .animation(.easeInOut, value: supabase.isAuthenticated)
        .task {
            // Kurze Verzögerung für Splash-Effekt
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await supabase.checkAuthState()
            isCheckingAuth = false
        }
    }
    
    // MARK: - Splash View
    
    private var splashView: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "person.crop.rectangle.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Text("MesseMemo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    RootView()
}

