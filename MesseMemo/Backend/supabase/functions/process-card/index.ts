// ============================================
// MesseMemo AI Contact Extraction Edge Function
// Version: 1.0 (Google Gemini)
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS Headers
const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Google Gemini Configuration
const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY");

// ============================================
// Main Handler
// ============================================

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // ========================================
        // 0. Environment Variables Check
        // ========================================

        const supabaseUrl = Deno.env.get("SUPABASE_URL");
        const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

        if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
            return errorResponse(500, "Server-Konfiguration fehlerhaft (Env Vars fehlen)");
        }

        // ========================================
        // 1. Auth Check
        // ========================================

        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
            return errorResponse(401, "Nicht authentifiziert");
        }

        const supabaseClient = createClient(
            supabaseUrl,
            supabaseAnonKey,
            {
                global: {
                    headers: { Authorization: authHeader },
                },
            }
        );

        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

        if (authError || !user) {
            return errorResponse(401, "Ungültiger Token");
        }

        // ========================================
        // 2. Credit Check & Abzug
        // ========================================
        // Wir nutzen denselben Credit-Mechanismus wie bei generate-email

        const supabaseAdmin = createClient(
            supabaseUrl,
            supabaseServiceKey
        );

        const { data: creditResult, error: creditError } = await supabaseAdmin
            .rpc("use_ai_credit", { user_id: user.id });

        if (creditError) {
            console.error("Credit RPC Error:", creditError);
            return errorResponse(500, "Fehler beim Guthaben-Abzug");
        }

        const creditData = creditResult?.[0];
        if (!creditData?.success) {
            return errorResponse(403, creditData?.error_message || "Kein Guthaben mehr", {
                credits_remaining: 0,
            });
        }

        const creditsRemaining = creditData.credits_remaining;

        // ========================================
        // 3. Request Body parsen
        // ========================================

        let requestBody;
        try {
            requestBody = await req.json();
        } catch (parseError) {
            return errorResponse(400, "Ungültiger Request-Body");
        }

        // Erwarte 'text' als Array von Strings (OCR Zeilen) oder als einzelner String
        const { text, context } = requestBody;

        if (!text || (Array.isArray(text) && text.length === 0)) {
            // Credit zurückgeben
            await supabaseAdmin.rpc("add_ai_credits", { user_id: user.id, amount: 1 });
            return errorResponse(400, "Kein Text zur Analyse übergeben");
        }

        const textToAnalyze = Array.isArray(text) ? text.join("\n") : text;

        // ========================================
        // 4. Google Gemini API Call
        // ========================================

        if (!GOOGLE_API_KEY) {
            await supabaseAdmin.rpc("add_ai_credits", { user_id: user.id, amount: 1 });
            return errorResponse(500, "Google API Key nicht konfiguriert");
        }

        // Prompt bauen
        const prompt = `
Du bist ein intelligenter Assistent für die Erfassung von Visitenkarten.
Extrahiere strukturierte Kontaktdaten aus dem folgenden OCR-Text.
Der Text kann Fehler enthalten oder unformatiert sein.

Gib das Ergebnis NUR als valides JSON zurück, ohne Markdown-Formatierung, ohne Code-Blöcke.
JSON Struktur:
{
  "name": "Voller Name (Vor- und Nachname)",
  "company": "Firmenname",
  "email": "E-Mail Adresse",
  "phone": "Telefonnummer (bevorzugt Mobil)",
  "job_title": "Jobtitel / Rolle",
  "website": "Webseite (URL)",
  "address": "Adresse (Straße, PLZ, Stadt)"
}

Falls ein Feld nicht gefunden wird, lasse es leer ("").
Korrigiere offensichtliche OCR-Fehler bei E-Mail oder Telefonnummern.

WICHTIG: Suche im Text auch nach Hinweisen auf QR-Codes oder vCard-Rohdaten. 
Falls eine URL oder vCard-Daten gefunden werden, extrahiere diese bevorzugt in die entsprechenden Felder!

OCR-Text:
${textToAnalyze}

${context ? `Zusätzlicher Kontext: ${context}` : ""}
`;

        // Modell-Optionen (Fallback Strategie)
        // HINWEIS: Wir nutzen v1beta für Gemini 1.5 Modelle (JSON Mode).
        // Fallback auf gemini-pro (v1) ohne JSON Mode (nur Prompt-basiert).
        const modelOptions = [
            { model: "gemini-1.5-flash-latest", apiVersion: "v1beta" },
            { model: "gemini-1.5-pro-latest", apiVersion: "v1beta" },
            { model: "gemini-1.5-flash-002", apiVersion: "v1beta" },
            { model: "gemini-1.5-flash", apiVersion: "v1" },
            { model: "gemini-1.5-flash-latest", apiVersion: "v1" },
            { model: "gemini-2.0-flash-exp", apiVersion: "v1beta" },
            { model: "gemini-pro", apiVersion: "v1beta" },
        ];

        let geminiData = null;
        let lastError = "";

        console.log("Analyzing text with models:", modelOptions.map(m => m.model));

        for (const { model, apiVersion, useJsonMode } of modelOptions) {
            try {
                const url = `https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent?key=${GOOGLE_API_KEY}`;

                const payload: any = {
                    contents: [{ parts: [{ text: prompt }] }]
                };

                if (useJsonMode) {
                    payload.generationConfig = {
                        responseMimeType: "application/json"
                    };
                }

                const response = await fetch(url, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(payload),
                });

                if (response.ok) {
                    geminiData = await response.json();
                    break;
                } else {
                    lastError = await response.text();
                    console.warn(`Model ${model} failed: ${lastError}`);
                }
            } catch (e) {
                lastError = String(e);
                console.warn(`Model ${model} error: ${e}`);
            }
        }

        if (!geminiData) {
            await supabaseAdmin.rpc("add_ai_credits", { user_id: user.id, amount: 1 });
            return errorResponse(500, "KI-Analyse fehlgeschlagen: " + lastError);
        }

        // ========================================
        // 5. Response parsen
        // ========================================

        const generatedContent = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

        if (!generatedContent) {
            await supabaseAdmin.rpc("add_ai_credits", { user_id: user.id, amount: 1 });
            return errorResponse(500, "Keine Antwort von KI erhalten");
        }

        let parsedContact;
        try {
            // Versuche JSON zu parsen (manchmal ist Markdown drumherum, auch mit responseMimeType safety)
            let cleanJson = generatedContent.trim();
            // Entferne Markdown Code Blocks falls vorhanden ```json ... ```
            cleanJson = cleanJson.replace(/^```json\s*/, "").replace(/\s*```$/, "");
            parsedContact = JSON.parse(cleanJson);
        } catch (e) {
            console.error("JSON Parse Error:", e, generatedContent);
            // Fallback: Versuche simple Extraktion, falls JSON kaputt, oder Fail
            // Hier geben wir einfach einen Fehler zurück, da wir strukturiertes JSON brauchen
            await supabaseAdmin.rpc("add_ai_credits", { user_id: user.id, amount: 1 });
            return errorResponse(500, "Konnte KI-Antwort nicht lesen (JSON Error)");
        }

        // ========================================
        // 6. Success Response
        // ========================================

        return new Response(
            JSON.stringify({
                success: true,
                data: parsedContact,
                credits_remaining: creditsRemaining
            }),
            {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
                status: 200,
            }
        );

    } catch (error) {
        console.error("Fatal Error:", error);
        return errorResponse(500, "Interner Serverfehler");
    }
});

function errorResponse(status: number, message: string, extra = {}) {
    return new Response(
        JSON.stringify({ success: false, error: message, ...extra }),
        {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: status,
        }
    );
}
