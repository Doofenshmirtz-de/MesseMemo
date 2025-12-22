-- ============================================
-- MesseMemo Credit System Migration
-- Version: 002
-- Datum: 14.12.2025
-- ============================================

-- ============================================
-- 1. Credits-Spalte zur profiles Tabelle hinzufügen
-- ============================================

-- Füge die ai_credits_balance Spalte hinzu
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS ai_credits_balance INTEGER DEFAULT 20 NOT NULL;

-- Kommentar für die Spalte
COMMENT ON COLUMN public.profiles.ai_credits_balance IS 
'Anzahl der verfügbaren KI-Credits. Neue User starten mit 20 Credits.';

-- ============================================
-- 2. Bestehende User mit Credits ausstatten
-- ============================================

-- Setze Credits für bestehende User, die noch keine haben
UPDATE public.profiles 
SET ai_credits_balance = 20 
WHERE ai_credits_balance IS NULL OR ai_credits_balance = 0;

-- ============================================
-- 3. RPC Funktion zum Credit-Abzug (atomar)
-- ============================================

-- Funktion zum sicheren Abziehen von Credits
CREATE OR REPLACE FUNCTION public.use_ai_credit(user_id UUID)
RETURNS TABLE (
    success BOOLEAN,
    credits_remaining INTEGER,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_credits INTEGER;
    v_is_premium BOOLEAN;
BEGIN
    -- Hole aktuellen Stand (alle Spalten qualifiziert mit Tabellenalias)
    SELECT p.ai_credits_balance, p.is_premium 
    INTO v_current_credits, v_is_premium
    FROM profiles p
    WHERE p.id = user_id
    FOR UPDATE; -- Lock für atomare Operation
    
    -- Prüfe ob User existiert
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0, 'User nicht gefunden'::TEXT;
        RETURN;
    END IF;
    
    -- Premium User haben unbegrenzte Credits
    IF v_is_premium THEN
        RETURN QUERY SELECT TRUE, -1, NULL::TEXT; -- -1 = unbegrenzt
        RETURN;
    END IF;
    
    -- Prüfe ob genug Credits vorhanden
    IF v_current_credits < 1 THEN
        RETURN QUERY SELECT FALSE, 0, 'Kein Guthaben mehr'::TEXT;
        RETURN;
    END IF;
    
    -- Ziehe 1 Credit ab (Spalten qualifiziert)
    UPDATE profiles p
    SET ai_credits_balance = p.ai_credits_balance - 1,
        updated_at = NOW()
    WHERE p.id = user_id;
    
    -- Gib Erfolg zurück
    RETURN QUERY SELECT TRUE, v_current_credits - 1, NULL::TEXT;
END;
$$;

-- Kommentar
COMMENT ON FUNCTION public.use_ai_credit IS 
'Zieht 1 KI-Credit vom User ab. Gibt Erfolg, verbleibende Credits und ggf. Fehlermeldung zurück.';

-- ============================================
-- 4. RPC Funktion zum Credit-Aufladen
-- ============================================

-- Funktion zum Hinzufügen von Credits (nach IAP)
CREATE OR REPLACE FUNCTION public.add_ai_credits(
    user_id UUID,
    amount INTEGER
)
RETURNS TABLE (
    success BOOLEAN,
    credits_after INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Füge Credits hinzu (alle Spalten qualifiziert mit Tabellenalias)
    UPDATE profiles p
    SET ai_credits_balance = p.ai_credits_balance + amount,
        updated_at = NOW()
    WHERE p.id = user_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0;
        RETURN;
    END IF;
    
    -- Gib neuen Stand zurück (Spalten qualifiziert)
    RETURN QUERY 
    SELECT TRUE, p.ai_credits_balance 
    FROM profiles p
    WHERE p.id = user_id;
END;
$$;

-- Kommentar
COMMENT ON FUNCTION public.add_ai_credits IS 
'Fügt KI-Credits zum User-Konto hinzu (nach erfolgreichem In-App Purchase).';

-- ============================================
-- 5. Trigger für neue User (20 Credits)
-- ============================================

-- Aktualisiere den bestehenden Trigger für neue User
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, is_premium, ai_credits_balance, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        FALSE,
        20, -- Starterpaket: 20 kostenlose Credits
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 6. Index für Performance
-- ============================================

-- Index für schnelle Credit-Abfragen
CREATE INDEX IF NOT EXISTS idx_profiles_credits 
ON public.profiles (ai_credits_balance) 
WHERE ai_credits_balance > 0;

-- ============================================
-- Fertig!
-- ============================================

-- Verifiziere die Änderung
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name = 'ai_credits_balance';

