//
//  MailComposerView.swift
//  MesseMemo
//
//  Created by Jarno Kibies on 10.12.25.
//

import SwiftUI
import MessageUI

/// SwiftUI Wrapper für MFMailComposeViewController
struct MailComposerView: UIViewControllerRepresentable {
    
    // MARK: - Properties
    
    let recipients: [String]
    let subject: String
    let body: String
    let isHTML: Bool
    
    @Environment(\.dismiss) private var dismiss
    var onResult: ((MFMailComposeResult) -> Void)?
    
    // MARK: - Initialization
    
    init(
        recipients: [String] = [],
        subject: String = "",
        body: String = "",
        isHTML: Bool = false,
        onResult: ((MFMailComposeResult) -> Void)? = nil
    ) {
        self.recipients = recipients
        self.subject = subject
        self.body = body
        self.isHTML = isHTML
        self.onResult = onResult
    }
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: isHTML)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // Keine Updates nötig
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.onResult?(result)
            parent.dismiss()
        }
    }
    
    // MARK: - Static Helper
    
    /// Prüft ob das Gerät E-Mails senden kann
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
}

// MARK: - Follow-Up Mail Generator

/// Hilfsklasse zum Generieren von Follow-Up E-Mails
struct FollowUpMailGenerator {
    
    /// Generiert eine professionelle Follow-Up E-Mail basierend auf dem Lead
    /// - Parameters:
    ///   - lead: Der Lead für den die Mail generiert werden soll
    ///   - senderName: Name des Absenders (optional)
    /// - Returns: Tuple mit Subject und Body
    static func generateFollowUpMail(for lead: Lead, senderName: String = "") -> (subject: String, body: String) {
        let greeting = lead.name.isEmpty ? "Guten Tag" : "Guten Tag \(lead.name.components(separatedBy: " ").first ?? "")"
        
        let subject = "Schön, Sie kennengelernt zu haben\(lead.company.isEmpty ? "" : " – \(lead.company)")"
        
        var body = """
        \(greeting),
        
        vielen Dank für das angenehme Gespräch auf der Messe. Es hat mich gefreut, Sie und \(lead.company.isEmpty ? "Ihr Unternehmen" : lead.company) kennenzulernen.
        
        """
        
        // Falls Notizen oder Transkript vorhanden, Kontext hinzufügen
        if let transcript = lead.transcript, !transcript.isEmpty {
            body += """
            
            Wie besprochen, möchte ich gerne an unser Gespräch anknüpfen und die nächsten Schritte mit Ihnen abstimmen.
            
            """
        } else if !lead.notes.isEmpty {
            body += """
            
            Gerne möchte ich an unser Gespräch anknüpfen und freue mich auf den weiteren Austausch.
            
            """
        }
        
        body += """
        
        Lassen Sie mich wissen, wann es Ihnen passt – ich melde mich gerne telefonisch oder per E-Mail.
        
        Mit freundlichen Grüßen
        \(senderName.isEmpty ? "[Ihr Name]" : senderName)
        """
        
        return (subject, body)
    }
}

// MARK: - Preview Helper

#if DEBUG
struct MailComposerPreview: View {
    @State private var showMailComposer = false
    
    var body: some View {
        VStack {
            Text("Mail Composer Preview")
            
            Button("E-Mail öffnen") {
                showMailComposer = true
            }
            .disabled(!MailComposerView.canSendMail)
        }
        .sheet(isPresented: $showMailComposer) {
            if MailComposerView.canSendMail {
                MailComposerView(
                    recipients: ["test@example.com"],
                    subject: "Test",
                    body: "Das ist ein Test."
                )
            }
        }
    }
}

#Preview {
    MailComposerPreview()
}
#endif

