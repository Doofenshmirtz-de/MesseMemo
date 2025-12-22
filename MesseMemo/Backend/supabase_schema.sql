-- ============================================
-- MesseMemo - Supabase Database Schema
-- ============================================
-- Führe diesen SQL-Code im Supabase SQL-Editor aus
-- ============================================

-- ============================================
-- 1. PROFILES TABLE
-- ============================================
-- Speichert zusätzliche User-Informationen

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    is_premium BOOLEAN DEFAULT false,
    display_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index für schnellere Abfragen
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);

-- ============================================
-- 2. AUTO-CREATE PROFILE TRIGGER
-- ============================================
-- Erstellt automatisch ein Profil wenn sich ein User registriert

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, is_premium, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        false,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger bei User-Registrierung
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 3. LEADS TABLE
-- ============================================
-- Speichert alle erfassten Leads/Kontakte

CREATE TABLE IF NOT EXISTS public.leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Kontaktdaten
    name TEXT DEFAULT '',
    company TEXT DEFAULT '',
    email TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    
    -- Notizen
    note_text TEXT DEFAULT '',
    transcript TEXT,
    
    -- Audio
    audio_url TEXT,
    audio_duration_seconds INTEGER,
    
    -- KI-generierte Inhalte
    generated_email TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indizes für Performance
CREATE INDEX IF NOT EXISTS leads_user_id_idx ON public.leads(user_id);
CREATE INDEX IF NOT EXISTS leads_created_at_idx ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS leads_name_idx ON public.leads(name);
CREATE INDEX IF NOT EXISTS leads_company_idx ON public.leads(company);

-- ============================================
-- 4. UPDATED_AT TRIGGER
-- ============================================
-- Aktualisiert updated_at automatisch bei Änderungen

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger für profiles
DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger für leads
DROP TRIGGER IF EXISTS leads_updated_at ON public.leads;
CREATE TRIGGER leads_updated_at
    BEFORE UPDATE ON public.leads
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- 5. ROW LEVEL SECURITY (RLS) - PROFILES
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- User kann nur sein eigenes Profil sehen
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- User kann nur sein eigenes Profil aktualisieren
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Insert wird durch Trigger gehandhabt (SECURITY DEFINER)
-- Kein direkter Insert durch User erlaubt

-- ============================================
-- 6. ROW LEVEL SECURITY (RLS) - LEADS
-- ============================================

ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- User kann nur eigene Leads sehen
CREATE POLICY "Users can view own leads"
    ON public.leads FOR SELECT
    USING (auth.uid() = user_id);

-- User kann nur eigene Leads erstellen
CREATE POLICY "Users can create own leads"
    ON public.leads FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- User kann nur eigene Leads aktualisieren
CREATE POLICY "Users can update own leads"
    ON public.leads FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- User kann nur eigene Leads löschen
CREATE POLICY "Users can delete own leads"
    ON public.leads FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================
-- 7. STORAGE BUCKET - VOICE MEMOS
-- ============================================
-- Führe diesen Teil separat aus oder über die Supabase UI

-- Bucket erstellen (falls nicht über UI gemacht)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'voice-memos',
    'voice-memos',
    false,  -- Nicht öffentlich
    52428800,  -- 50MB max
    ARRAY['audio/m4a', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/x-m4a']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 8. STORAGE RLS POLICIES
-- ============================================

-- User kann eigene Dateien hochladen
-- Pfad-Struktur: {user_id}/{dateiname}
CREATE POLICY "Users can upload own voice memos"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'voice-memos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- User kann eigene Dateien lesen
CREATE POLICY "Users can read own voice memos"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'voice-memos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- User kann eigene Dateien aktualisieren
CREATE POLICY "Users can update own voice memos"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'voice-memos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- User kann eigene Dateien löschen
CREATE POLICY "Users can delete own voice memos"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'voice-memos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- ============================================
-- 9. HILFSFUNKTIONEN
-- ============================================

-- Funktion um Lead-Count für einen User zu bekommen
CREATE OR REPLACE FUNCTION public.get_user_lead_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM public.leads WHERE user_id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funktion um zu prüfen ob User Premium ist
CREATE OR REPLACE FUNCTION public.is_user_premium(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (SELECT is_premium FROM public.profiles WHERE id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FERTIG! 🎉
-- ============================================
-- Nächste Schritte:
-- 1. Gehe zu Authentication > Providers und aktiviere Email
-- 2. Gehe zu Edge Functions und deploye generate-email
-- 3. Setze OPENAI_API_KEY als Secret in Edge Functions
-- ============================================

