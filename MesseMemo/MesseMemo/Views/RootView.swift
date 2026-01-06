//
//  RootView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//
//  LOCAL-ONLY APP:
//  Keine Auth-Prüfung mehr - direkt zum Dashboard
//

import SwiftUI

/// Root View mit kurzem Splash Screen
struct RootView: View {
    
    @State private var showSplash = true
    
    // Binding für Action Button Intent (Scan direkt starten)
    @State private var shouldOpenScanner = false
    
    var body: some View {
        Group {
            if showSplash {
                splashView
            } else {
                MainTabView(shouldOpenScanner: $shouldOpenScanner)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .task {
            // Kurzer Splash Screen (0.8s)
            try? await Task.sleep(nanoseconds: 800_000_000)
            showSplash = false
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScanner)) { _ in
            // Warte kurz bis App vollständig geladen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                shouldOpenScanner = true
            }
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
    
    // MARK: - Deep Link Handler (für Action Button)
    
    private func handleDeepLink(url: URL) {
        // messememo://scan - Öffnet direkt den Scanner
        if url.host == "scan" {
            shouldOpenScanner = true
        }
    }
}

#Preview {
    RootView()
}
