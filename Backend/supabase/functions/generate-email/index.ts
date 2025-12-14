// ============================================
// MesseMemo AI Email Generation Edge Function
// Version: 2.0 (mit Credit-System)
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS Headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// OpenAI Configuration
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_MODEL = "gpt-4o-mini";

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
    // 1. Auth Check
    // ========================================
    
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return errorResponse(401, "Nicht authentifiziert");
    }

    // Supabase Client mit User-Token
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
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
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Versuche 1 Credit abzuziehen
    const { data: creditResult, error: creditError } = await supabaseAdmin
      .rpc("use_ai_credit", { user_id: user.id });

    if (creditError) {
      console.error("Credit RPC Error:", creditError);
      return errorResponse(500, "Fehler beim Credit-Check");
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
    
    const { name, company, transcript } = await req.json();

    if (!name && !company && !transcript) {
      // Credit zurückgeben bei ungültigem Request
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(400, "Name, Firma oder Kontext erforderlich");
    }

    // ========================================
    // 4. OpenAI API Call
    // ========================================
    
    if (!OPENAI_API_KEY) {
      // Credit zurückgeben bei Konfigurationsfehler
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      return errorResponse(500, "OpenAI API nicht konfiguriert");
    }

    const prompt = buildPrompt(name, company, transcript);

    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        messages: [
          {
            role: "system",
            content: `Du bist ein professioneller Business-Kommunikationsexperte. 
Deine Aufgabe ist es, freundliche, professionelle Follow-up E-Mails auf Deutsch zu verfassen.
Die E-Mails sollten:
- Kurz und prägnant sein (max. 150 Wörter)
- Einen klaren Betreff haben
- Persönlich wirken, aber professionell bleiben
- Einen konkreten Call-to-Action enthalten
- Das Format sein: BETREFF: [Betreff]\n\n[E-Mail-Text]`,
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.7,
        max_tokens: 500,
      }),
    });

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text();
      console.error("OpenAI Error:", errorData);
      
      // Credit zurückgeben bei OpenAI Fehler
      await supabaseAdmin.rpc("add_ai_credits", { 
        user_id: user.id, 
        amount: 1 
      });
      
      return errorResponse(500, "KI-Generierung fehlgeschlagen");
    }

    const openaiData = await openaiResponse.json();
    const generatedText = openaiData.choices?.[0]?.message?.content || "";

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
    return errorResponse(500, "Interner Serverfehler");
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

function buildPrompt(name: string, company: string, transcript: string): string {
  let prompt = "Erstelle eine Follow-up E-Mail für folgenden Kontakt:\n\n";
  
  if (name) {
    prompt += `Name: ${name}\n`;
  }
  if (company) {
    prompt += `Firma: ${company}\n`;
  }
  if (transcript) {
    prompt += `\nKontext aus dem Gespräch:\n${transcript}\n`;
  }
  
  prompt += "\nBitte erstelle eine professionelle, freundliche Follow-up E-Mail.";
  
  return prompt;
}

function parseEmailResponse(text: string): { subject: string; body: string } {
  // Versuche "BETREFF:" Format zu parsen
  const betreffMatch = text.match(/BETREFF:\s*(.+?)(?:\n|$)/i);
  
  if (betreffMatch) {
    const subject = betreffMatch[1].trim();
    const body = text.replace(/BETREFF:\s*.+?\n+/i, "").trim();
    return { subject, body };
  }
  
  // Fallback: Erste Zeile als Betreff
  const lines = text.split("\n").filter(l => l.trim());
  if (lines.length >= 2) {
    return {
      subject: lines[0].replace(/^(Betreff|Subject):\s*/i, "").trim(),
      body: lines.slice(1).join("\n").trim(),
    };
  }
  
  // Letzter Fallback
  return {
    subject: "Follow-up zu unserem Gespräch",
    body: text.trim(),
  };
}
