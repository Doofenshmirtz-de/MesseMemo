// ============================================
// MesseMemo AI Email Generation Edge Function
// Version: 3.0 (Google Gemini 1.5 Flash)
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
// Hinweis: Die Edge Function verwendet eine Fallback-Strategie und versucht
// automatisch verschiedene Modellnamen und API-Versionen, falls das erste Modell nicht verfügbar ist.

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
      console.error("Missing environment variables:", {
        hasUrl: !!supabaseUrl,
        hasAnonKey: !!supabaseAnonKey,
        hasServiceKey: !!supabaseServiceKey,
      });
      return errorResponse(500, "Server-Konfiguration fehlerhaft");
    }
    
    // ========================================
    // 1. Auth Check
    // ========================================
    
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse(401, "Nicht authentifiziert");
    }

    // Supabase Client mit User-Token
    const supabaseClient = createClient(
      supabaseUrl,
      supabaseAnonKey,
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    // User verifizieren
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    
    if (authError || !user) {
      return errorResponse(401, "Ungültiger Token");
    }

    // ========================================
    // 2. Credit Check & Abzug (atomar)
    // ========================================
    
    // Service Client für RPC Call (SECURITY DEFINER)
    const supabaseAdmin = createClient(
      supabaseUrl,
      supabaseServiceKey
    );

    // Versuche 1 Credit abzuziehen
    const { data: creditResult, error: creditError } = await supabaseAdmin
      .rpc("use_ai_credit", { user_id: user.id });

    if (creditError) {
      console.error("Credit RPC Error:", JSON.stringify(creditError, null, 2));
      return errorResponse(500, `Fehler beim Credit-Check: ${creditError.message || JSON.stringify(creditError)}`);
    }

    // Prüfe Ergebnis
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
      console.error("JSON Parse Error:", parseError);
      return errorResponse(400, "Ungültiger Request-Body");
    }
    
    const { name, company, transcript } = requestBody;

    if (!name && !company && !transcript) {
      // Credit zurückgeben bei ungültigem Request
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(400, "Name, Firma oder Kontext erforderlich");
    }

    // ========================================
    // 4. Google Gemini API Call
    // ========================================
    
    if (!GOOGLE_API_KEY) {
      console.error("❌ GOOGLE_API_KEY environment variable is missing");
      // Credit zurückgeben bei Konfigurationsfehler
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(500, "Google API Key nicht konfiguriert. Bitte GOOGLE_API_KEY in Supabase Edge Function Secrets setzen.");
    }

    // Validiere API-Key Format (sollte nicht leer sein)
    if (GOOGLE_API_KEY.trim().length === 0) {
      console.error("❌ GOOGLE_API_KEY is empty");
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(500, "Google API Key ist leer. Bitte GOOGLE_API_KEY in Supabase Edge Function Secrets setzen.");
    }

    const prompt = buildGeminiPrompt(name, company, transcript);

    // Versuche verschiedene Modellnamen und API-Versionen (Fallback-Strategie)
    // Priorität: Neueste/zuverlässigste Modelle zuerst
    const modelOptions = [
      { model: "gemini-1.5-flash-latest", apiVersion: "v1beta" },
      { model: "gemini-1.5-pro-latest", apiVersion: "v1beta" },
      { model: "gemini-1.5-flash-002", apiVersion: "v1beta" },
      { model: "gemini-1.5-flash", apiVersion: "v1" },
      { model: "gemini-1.5-flash-latest", apiVersion: "v1" },
      { model: "gemini-2.0-flash-exp", apiVersion: "v1beta" },
      { model: "gemini-pro", apiVersion: "v1beta" },
    ];
    
    let geminiResponse: Response | null = null;
    let lastError: string = "";
    
    for (const { model, apiVersion } of modelOptions) {
      const endpoint = `https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent`;
      const fullUrl = `${endpoint}?key=${GOOGLE_API_KEY}`;
      
      console.log(`Trying model: ${model} (${apiVersion})`);
      
      try {
        geminiResponse = await fetch(fullUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: prompt
                  }
                ]
              }
            ],
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 500,
              topP: 0.9,
              topK: 40
            },
            safetySettings: [
              {
                category: "HARM_CATEGORY_HARASSMENT",
                threshold: "BLOCK_NONE"
              },
              {
                category: "HARM_CATEGORY_HATE_SPEECH",
                threshold: "BLOCK_NONE"
              },
              {
                category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                threshold: "BLOCK_NONE"
              },
              {
                category: "HARM_CATEGORY_DANGEROUS_CONTENT",
                threshold: "BLOCK_NONE"
              }
            ]
          }),
        });
        
        if (geminiResponse.ok) {
          console.log(`✅ Successfully used model: ${model} (${apiVersion})`);
          break; // Erfolgreich, beende Schleife
        } else {
          const errorData = await geminiResponse.text();
          const statusText = geminiResponse.statusText || `HTTP ${geminiResponse.status}`;
          lastError = `Model ${model} (${apiVersion}): ${statusText} - ${errorData}`;
          console.warn(`❌ Model ${model} (${apiVersion}) failed [${geminiResponse.status}]:`, errorData);
          geminiResponse = null; // Reset für nächsten Versuch
        }
      } catch (fetchError) {
        lastError = `Model ${model} (${apiVersion}): ${fetchError instanceof Error ? fetchError.message : String(fetchError)}`;
        console.warn(`Model ${model} (${apiVersion}) threw error:`, fetchError);
        geminiResponse = null;
      }
    }

    if (!geminiResponse || !geminiResponse.ok) {
      console.error("❌ All Gemini models failed. Last error:", lastError);
      console.error("Tried models:", modelOptions.map(m => `${m.model} (${m.apiVersion})`).join(", "));
      
      // Credit zurückgeben bei Gemini Fehler
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      
      // Benutzerfreundliche Fehlermeldung
      let userMessage = "KI-Generierung fehlgeschlagen. ";
      if (lastError.includes("404") || lastError.includes("not found")) {
        userMessage += "Modell nicht verfügbar. Bitte API-Key und Modellverfügbarkeit prüfen.";
      } else if (lastError.includes("401") || lastError.includes("403")) {
        userMessage += "API-Key ungültig oder keine Berechtigung.";
      } else if (lastError.includes("429")) {
        userMessage += "API-Limit erreicht. Bitte später erneut versuchen.";
      } else {
        userMessage += `Technischer Fehler: ${lastError.substring(0, 200)}`;
      }
      
      return errorResponse(500, userMessage);
    }

    const geminiData = await geminiResponse.json();
    
    // Gemini Response Format: candidates[0].content.parts[0].text
    const generatedText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "";

    if (!generatedText) {
      console.error("Empty Gemini response:", JSON.stringify(geminiData));
      
      // Credit zurückgeben bei leerem Response
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      
      return errorResponse(500, "Keine Antwort von der KI erhalten");
    }

    // ========================================
    // 5. Response parsen
    // ========================================
    
    const { subject, body } = parseEmailResponse(generatedText);

    if (!subject || !body) {
      // Credit zurückgeben bei Parse-Fehler
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(500, "E-Mail konnte nicht generiert werden");
    }

    // ========================================
    // 6. Erfolg zurückgeben
    // ========================================
    
    return new Response(
      JSON.stringify({
        success: true,
        subject: subject,
        email: body,
        credits_remaining: creditsRemaining,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error) {
    console.error("Unhandled Error:", error);
    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorStack = error instanceof Error ? error.stack : undefined;
    console.error("Error Details:", { message: errorMessage, stack: errorStack });
    return errorResponse(500, `Interner Serverfehler: ${errorMessage}`);
  }
});

// ============================================
// Helper Functions
// ============================================

function errorResponse(
  status: number, 
  message: string, 
  extra: Record<string, unknown> = {}
): Response {
  return new Response(
    JSON.stringify({
      success: false,
      error: message,
      ...extra,
    }),
    {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: status,
    }
  );
}

/**
 * Baut den Prompt für Gemini 1.5 Flash
 * System-Instruktion ist direkt im Prompt enthalten
 */
function buildGeminiPrompt(name: string, company: string, transcript: string): string {
  // System-Instruktion direkt am Anfang
  let prompt = `Du bist ein professioneller Business-Kommunikationsexperte, der freundliche, professionelle Follow-up E-Mails auf Deutsch verfasst.

WICHTIGE REGELN:
- Die E-Mail muss kurz und prägnant sein (max. 150 Wörter)
- Schreibe einen klaren, professionellen Betreff
- Die E-Mail soll persönlich wirken, aber professionell bleiben
- Füge einen konkreten Call-to-Action hinzu
- WICHTIG: Beginne IMMER mit "BETREFF:" gefolgt vom Betreff, dann eine Leerzeile, dann der E-Mail-Text

BEISPIEL-FORMAT:
BETREFF: Schön Sie kennengelernt zu haben

Sehr geehrte/r [Name],

[E-Mail-Text hier]

Mit freundlichen Grüßen
[Absender]

---

AUFGABE: Erstelle eine Follow-up E-Mail für folgenden Kontakt:

`;

  if (name) {
    prompt += `Name: ${name}\n`;
  }
  if (company) {
    prompt += `Firma: ${company}\n`;
  }
  if (transcript) {
    prompt += `\nKontext aus dem Gespräch:\n${transcript}\n`;
  }
  
  prompt += "\nBitte erstelle jetzt die professionelle Follow-up E-Mail im oben beschriebenen Format.";
  
  return prompt;
}

/**
 * Parst die generierte E-Mail in Betreff und Body
 */
function parseEmailResponse(text: string): { subject: string; body: string } {
  // Bereinige den Text
  const cleanText = text.trim();
  
  // Versuche "BETREFF:" Format zu parsen
  const betreffMatch = cleanText.match(/BETREFF:\s*(.+?)(?:\n|$)/i);
  
  if (betreffMatch) {
    const subject = betreffMatch[1].trim();
    // Entferne den Betreff-Teil und führende Leerzeilen
    const body = cleanText
      .replace(/BETREFF:\s*.+?\n+/i, "")
      .trim();
    
    if (subject && body) {
      return { subject, body };
    }
  }
  
  // Fallback: Suche nach "Betreff:" ohne Großbuchstaben
  const altMatch = cleanText.match(/(?:Betreff|Subject):\s*(.+?)(?:\n|$)/i);
  
  if (altMatch) {
    const subject = altMatch[1].trim();
    const body = cleanText
      .replace(/(?:Betreff|Subject):\s*.+?\n+/i, "")
      .trim();
    
    if (subject && body) {
      return { subject, body };
    }
  }
  
  // Letzter Fallback: Erste Zeile als Betreff
  const lines = cleanText.split("\n").filter(l => l.trim());
  if (lines.length >= 2) {
    return {
      subject: lines[0].replace(/^[*#\-]+\s*/, "").trim(),
      body: lines.slice(1).join("\n").trim(),
    };
  }
  
  // Absoluter Fallback
  return {
    subject: "Follow-up zu unserem Gespräch",
    body: cleanText,
  };
}
