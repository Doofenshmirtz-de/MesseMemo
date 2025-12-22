//
//  AuthView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 14.12.25.
//

import SwiftUI
import AuthenticationServices

/// Login und Registrierungs-View
struct AuthView: View {
    
    // MARK: - Environment
    
    @StateObject private var supabase = SupabaseManager.shared
    
    // MARK: - State
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessMessage = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Titel
                    headerView
                    
                    // Form
                    formView
                    
                    // Buttons
                    actionButtons
                    
                    // Toggle Login/Register
                    toggleModeButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .alert("Fehler", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Erfolgreich!", isPresented: $showSuccessMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte prüfe deine E-Mails und bestätige deine Registrierung.")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "person.crop.rectangle.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("MesseMemo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(isLoginMode ? "Willkommen zurück!" : "Erstelle dein Konto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Form
    
    private var formView: some View {
        VStack(spacing: 16) {
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("E-Mail")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                    TextField("deine@email.de", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            
            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Passwort")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                    SecureField("Mindestens 6 Zeichen", text: $password)
                        .textContentType(isLoginMode ? .password : .newPassword)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            
            // Confirm Password (nur bei Registrierung)
            if !isLoginMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passwort bestätigen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "lock.badge.checkmark")
                            .foregroundStyle(.secondary)
                        SecureField("Passwort wiederholen", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(passwordsMatch ? Color(.separator) : .red, lineWidth: 1)
                    )
                    
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwörter stimmen nicht überein")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoginMode)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary Button
            Button(action: handlePrimaryAction) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isLoginMode ? "Anmelden" : "Registrieren")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: isFormValid ? [.blue, .purple] : [.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: isFormValid ? .blue.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!isFormValid || isLoading)
            
            // Passwort vergessen (nur bei Login)
            if isLoginMode {
                Button(action: handleForgotPassword) {
                    Text("Passwort vergessen?")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                
                Text("oder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Sign in with Apple
            SignInWithAppleButton(
                onRequest: configureAppleSignIn,
                onCompletion: handleAppleSignIn
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Toggle Mode Button
    
    private var toggleModeButton: some View {
        HStack {
            Text(isLoginMode ? "Noch kein Konto?" : "Bereits registriert?")
                .foregroundStyle(.secondary)
            
            Button(action: toggleMode) {
                Text(isLoginMode ? "Registrieren" : "Anmelden")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .font(.subheadline)
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        if isLoginMode {
            return emailValid && passwordValid
        } else {
            return emailValid && passwordValid && passwordsMatch
        }
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword
    }
    
    // MARK: - Actions
    
    private func handlePrimaryAction() {
        Task {
            isLoading = true
            
            do {
                if isLoginMode {
                    try await supabase.signIn(email: email, password: password)
                } else {
                    try await supabase.signUp(email: email, password: password)
                    showSuccessMessage = true
                }
            } catch {
                errorMessage = supabase.errorMessage ?? "Ein Fehler ist aufgetreten."
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func handleForgotPassword() {
        guard email.contains("@") else {
            errorMessage = "Bitte gib zuerst deine E-Mail-Adresse ein."
            showError = true
            return
        }
        
        Task {
            isLoading = true
            
            do {
                try await supabase.resetPassword(email: email)
                errorMessage = "Eine E-Mail zum Zurücksetzen wurde gesendet."
                showError = true
            } catch {
                errorMessage = "Fehler beim Senden der E-Mail."
                showError = true
            }
            
            isLoading = false
        }
    }
    
    private func toggleMode() {
        withAnimation {
            isLoginMode.toggle()
            confirmPassword = ""
        }
    }
    
    // MARK: - Apple Sign In
    
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email, .fullName]
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Apple Sign In fehlgeschlagen."
                showError = true
                return
            }
            
            Task {
                isLoading = true
                do {
                    try await supabase.signInWithApple(idToken: tokenString)
                } catch {
                    await MainActor.run {
                        errorMessage = "Apple Sign In fehlgeschlagen: \(error.localizedDescription)"
                        showError = true
                    }
                }
                isLoading = false
            }
            
        case .failure(let error):
            // User cancelled - don't show error
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple Sign In fehlgeschlagen."
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}

