# MesseMemo Backend - Supabase Setup

## 📋 Übersicht

Dieses Backend verwendet Supabase für:
- **Authentication** - Email/Password Login
- **Database** - PostgreSQL mit Row Level Security
- **Storage** - Audio-Dateien für Sprachnotizen
- **Edge Functions** - KI-Integration mit OpenAI

---

## 🚀 Setup Anleitung

### 1. Supabase Projekt erstellen

1. Gehe zu [supabase.com](https://supabase.com) und erstelle ein neues Projekt
2. Notiere dir:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Anon Key**: `eyJhbGciOiJIUzI1NiIs...`
   - **Service Role Key**: (für Admin-Operationen)

### 2. Datenbank Schema ausführen

1. Gehe zu **SQL Editor** in deinem Supabase Dashboard
2. Kopiere den Inhalt von `supabase_schema.sql`
3. Klicke auf **Run**

Das erstellt:
- ✅ `profiles` Tabelle mit Auto-Create Trigger
- ✅ `leads` Tabelle
- ✅ Row Level Security Policies
- ✅ Storage Bucket `voice-memos`

### 3. Authentication aktivieren

1. Gehe zu **Authentication** → **Providers**
2. Aktiviere **Email**
3. Optional: Aktiviere **Apple** für Sign in with Apple

### 4. Edge Function deployen

#### Voraussetzungen:
```bash
# Supabase CLI installieren
brew install supabase/tap/supabase

# Login
supabase login
```

#### Edge Function deployen:
```bash
# Im Backend-Ordner
cd supabase/functions

# Projekt linken
supabase link --project-ref YOUR_PROJECT_REF

# Secret setzen
supabase secrets set OPENAI_API_KEY=sk-your-openai-key

# Function deployen
supabase functions deploy generate-email
```

### 5. iOS App konfigurieren

Füge diese Werte zur iOS App hinzu (z.B. in einer Config-Datei):

```swift
struct SupabaseConfig {
    static let url = "https://xxxxx.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIs..."
}
```

---

## 📁 Dateistruktur

```
Backend/
├── README.md                     # Diese Datei
├── supabase_schema.sql           # Datenbank Schema
└── supabase/
    └── functions/
        └── generate-email/
            └── index.ts          # Edge Function
```

---

## 🔐 Sicherheit

### Row Level Security (RLS)

Alle Tabellen haben RLS aktiviert:

| Tabelle | Policy |
|---------|--------|
| `profiles` | User sieht/bearbeitet nur eigenes Profil |
| `leads` | User sieht/bearbeitet nur eigene Leads |
| `storage.objects` | User greift nur auf eigene Dateien zu |

### Edge Function Auth

Die Edge Function prüft:
1. ✅ Auth Header vorhanden
2. ✅ JWT Token gültig
3. ✅ User existiert in Supabase Auth
4. ⏸️ Premium Status (auskommentiert für MVP)

---

## 📡 API Endpoints

### Edge Function: generate-email

**URL:** `https://xxxxx.supabase.co/functions/v1/generate-email`

**Method:** POST

**Headers:**
```
Authorization: Bearer {user_access_token}
Content-Type: application/json
```

**Body:**
```json
{
  "name": "Max Mustermann",
  "company": "Beispiel GmbH",
  "transcript": "Wir haben über das neue Produkt gesprochen...",
  "leadId": "optional-uuid-to-save-result"
}
```

**Response:**
```json
{
  "success": true,
  "email": "Sehr geehrter Herr Mustermann,\n\nvielen Dank für...",
  "subject": "Schön Sie kennengelernt zu haben – Beispiel GmbH"
}
```

---

## 🔧 Troubleshooting

### "Permission denied" Fehler
→ RLS Policies prüfen, User muss eingeloggt sein

### "OPENAI_API_KEY not configured"
→ Secret setzen: `supabase secrets set OPENAI_API_KEY=sk-...`

### Storage Upload fehlgeschlagen
→ Pfad muss mit `{user_id}/` beginnen: `userId/audio_123.m4a`

---

## 📱 iOS Integration

Für die iOS-Integration benötigst du:

1. **Supabase Swift SDK**
```swift
// Package.swift oder Xcode SPM
.package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
```

2. **SupabaseManager erstellen** (wird im nächsten Schritt implementiert)

---

## ✅ Checkliste

- [ ] Supabase Projekt erstellt
- [ ] SQL Schema ausgeführt
- [ ] Email Auth aktiviert
- [ ] Supabase CLI installiert
- [ ] Edge Function deployed
- [ ] OPENAI_API_KEY Secret gesetzt
- [ ] iOS App konfiguriert

