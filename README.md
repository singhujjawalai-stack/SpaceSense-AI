# SpaceSense AI

**An AI-powered room analysis app that helps users optimize their living spaces.**

- **Frontend**: Flutter app (Android-first)
- **Database**: Supabase (auth only)
- **Storage**: Local device storage (photos + analysis history)
- **AI**: User-provided API keys (OpenAI / Anthropic / Google) — called **directly from the app**, no backend server
- **Cost**: subscriptions/AI keys are the user's own; no server costs

## Architecture

```
Flutter app ──── Supabase (email/password + Google sign-in)
     │
     └── calls AI provider directly (OpenAI / Anthropic / Google vision APIs)
         with the user's own API key. One AI call returns the analysis:
         room type, detected objects, scoring data, recommendations
         (impact-ranked), and suggested products (with webshop search links).
```

There is **no intermediary backend** — the old FastAPI proxy was removed.
Scores are computed locally in Dart from the AI's vision data.

```
mobile/                      # Flutter app
├── lib/
│   ├── main.dart
│   ├── core/                # config, theme, network, ai (direct AI calls)
│   ├── features/            # auth, camera, analysis, history, settings
│   └── shared/              # models (analysis, api key, user)
└── assets/
```

Analysis results and photos are stored in local app documents storage:

```
<app documents>/spacesense/
├── originals/               # room photos ({roomId}_{timestamp}.jpg)
└── analyses/                # analysis JSON ({analysisId}.json),
                             # links the photo via image_path
```

## Setup

1. **Supabase**: create a project at [supabase.com](https://supabase.com) and copy the
   Project URL + anon/publishable key. See `SUPABASE_SETUP_CHECKLIST.md`.
2. **Configure the app**: edit `mobile/lib/core/config/env.dart` with your
   Supabase URL and key.
3. **API key**: no code changes needed — users add their own OpenAI /
   Anthropic / Google API key inside the app (Settings → API Configuration →
   Test Connection).

## Run

```bash
cd mobile
flutter pub get
flutter run          # debug on a device or emulator
```

## Build APKs

```bash
cd mobile
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/
#   app-arm64-v8a-release.apk      ← modern Android phones
#   app-armeabi-v7a-release.apk    ← older Android phones
#   app-x86_64-release.apk         ← emulators
```

## Features

- ✅ Email/password + Google sign-in (Supabase)
- ✅ User API key management with Test Connection
- ✅ Camera capture + gallery upload
- ✅ Single-call AI room analysis (6-dimension scoring, computed locally)
- ✅ Impact-ranked recommendations (best fix first, gold/silver/bronze ranks)
- ✅ Suggested products to add or replace, with one-tap webshop search links
- ✅ Local photo storage + offline history with delete

## Privacy

Photos are processed locally on device except a base64 copy sent to the
user's chosen AI provider for analysis. Nothing is stored server-side.
