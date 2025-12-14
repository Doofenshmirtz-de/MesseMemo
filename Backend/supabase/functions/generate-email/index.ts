// ============================================
// MesseMemo - Edge Function: generate-email
// ============================================
// Sicherer Proxy zwischen iOS App und OpenAI
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// CORS Headers für iOS App
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Request Body Interface
interface GenerateEmailRequest {
  name: string
  company: string
  transcript: string
  leadId?: string
}

// Response Interface
interface GenerateEmailResponse {
  success: boolean
  email?: string
  subject?: string
  error?: string
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ============================================
    // 1. AUTH CHECK - User muss eingeloggt sein
    // ============================================
    
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'Nicht autorisiert. Bitte einloggen.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Supabase Client erstellen
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    // User verifizieren
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: 'Ungültiger Token. Bitte erneut einloggen.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================
    // 2. PREMIUM CHECK (Optional - auskommentiert für MVP)
    // ============================================
    
    /*
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('is_premium')
      .eq('id', user.id)
      .single()
    
    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ success: false, error: 'Profil nicht gefunden.' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!profile.is_premium) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Premium-Funktion. Bitte upgrade dein Konto.',
          requiresPremium: true 
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    */

    // ============================================
    // 3. REQUEST BODY PARSEN
    // ============================================
    
    const body: GenerateEmailRequest = await req.json()
    const { name, company, transcript, leadId } = body

    // Validierung
    if (!name && !company && !transcript) {
      return new Response(
        JSON.stringify({ success: false, error: 'Mindestens Name, Firma oder Transkript erforderlich.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================
    // 4. OPENAI API AUFRUF
    // ============================================
    
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiApiKey) {
      console.error('OPENAI_API_KEY nicht konfiguriert')
      return new Response(
        JSON.stringify({ success: false, error: 'KI-Service nicht verfügbar.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Prompt erstellen
    const prompt = buildPrompt(name, company, transcript)

    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: `Du bist ein professioneller Business-Kommunikationsexperte. 
Du schreibst höfliche, prägnante Follow-up E-Mails auf Deutsch.
Die E-Mails sollen professionell aber nicht steif klingen.
Halte die E-Mails kurz (max. 150 Wörter).
Antworte NUR mit der E-Mail, keine zusätzlichen Erklärungen.
Beginne die Mail mit einer passenden Anrede und ende mit "Mit freundlichen Grüßen" und einem Platzhalter [Ihr Name].`
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 500,
      }),
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.json()
      console.error('OpenAI API Error:', errorData)
      return new Response(
        JSON.stringify({ success: false, error: 'KI-Generierung fehlgeschlagen.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const openaiData = await openaiResponse.json()
    const generatedEmail = openaiData.choices[0]?.message?.content?.trim()

    if (!generatedEmail) {
      return new Response(
        JSON.stringify({ success: false, error: 'Keine E-Mail generiert.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================
    // 5. OPTIONAL: E-Mail im Lead speichern
    // ============================================
    
    if (leadId) {
      const { error: updateError } = await supabase
        .from('leads')
        .update({ generated_email: generatedEmail })
        .eq('id', leadId)
        .eq('user_id', user.id) // Sicherheit: Nur eigene Leads
      
      if (updateError) {
        console.error('Lead Update Error:', updateError)
        // Nicht kritisch - E-Mail trotzdem zurückgeben
      }
    }

    // ============================================
    // 6. ERFOLGREICHE RESPONSE
    // ============================================
    
    // Betreff generieren
    const subject = generateSubject(name, company)

    const response: GenerateEmailResponse = {
      success: true,
      email: generatedEmail,
      subject: subject,
    }

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Edge Function Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: 'Ein unerwarteter Fehler ist aufgetreten.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ============================================
// HELPER FUNCTIONS
// ============================================

function buildPrompt(name: string, company: string, transcript: string): string {
  let prompt = 'Erstelle eine kurze, professionelle Follow-up E-Mail auf Deutsch'
  
  if (name && company) {
    prompt += ` für ${name} von ${company}`
  } else if (name) {
    prompt += ` für ${name}`
  } else if (company) {
    prompt += ` für einen Kontakt von ${company}`
  }
  
  prompt += '.'
  
  if (transcript && transcript.trim().length > 0) {
    prompt += `\n\nKontext aus dem Gespräch:\n"${transcript}"\n\nBeziehe dich subtil auf die besprochenen Themen.`
  } else {
    prompt += '\n\nEs gibt keinen spezifischen Gesprächskontext. Schreibe eine allgemeine Follow-up Mail nach einem Messetreffen.'
  }
  
  return prompt
}

function generateSubject(name: string, company: string): string {
  if (company) {
    return `Schön Sie kennengelernt zu haben – ${company}`
  } else if (name) {
    return `Schön Sie kennengelernt zu haben, ${name.split(' ')[0]}`
  }
  return 'Schön Sie auf der Messe kennengelernt zu haben'
}

