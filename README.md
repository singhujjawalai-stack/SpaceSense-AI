# SpaceSense AI

**Turn a photo of any room into an expert design report — score, fix-it plan, and "after" previews.**

SpaceSense AI looks at your room, rates it across six dimensions (clutter, design, functionality, storage, lighting), and gives you an impact-ranked action plan of what to change first — plus direct product suggestions for the fixes.

- ✅ Free to use — bring your own free API key (Google Gemini works great)
- ✅ No backend, no account-data server, no subscription
- ✅ Photos and history stay on your phone

## Features

- 📸 **Photo analysis** — snap a room or upload one; AI identifies the room type, objects, layout and lighting in one shot
- 📊 **Six-dimension scoring** — overall score with a clear breakdown (clutter, design, functionality, storage, lighting)
- 🥇 **Impact-ranked recommendations** — the changes that matter most, sorted and ranked (gold/silver/bronze) by expected improvement
- 🛍️ **Suggested products** — what to add or replace, each with one-tap search links (Google Shopping / Amazon)
- ✨ **Reimagine the room** — realistic "after" previews of your own photo per style: decluttered, brighter, minimalist, more storage, modern refresh
- 🗂️ **Offline history** — every analysis and photo is saved locally on the device, viewable and shareable anytime
- 🔑 **Bring your own AI key** — add an OpenAI, Anthropic or Google Gemini key in Settings (with a one-tap connection test); the free Gemini tier covers everyday use at no cost

## Privacy

Photos are kept on your device. The only thing that leaves the phone is a base64 copy of the photo you choose to analyze, sent directly to the AI provider you configured in Settings. Nothing is stored on any server.

## For Developers

Flutter (Android) app; Supabase handles sign-in (email/password + Google) and everything else runs locally in Dart.

```
mobile/                    # Flutter app
└── lib/
    ├── core/              # theme, config, AI service (direct provider calls)
    ├── features/          # auth, camera, analysis, history, settings
    └── shared/            # models
```

```bash
cd mobile
flutter pub get
flutter run               # debug on a device or emulator
flutter build apk --release --split-per-abi   # release APKs
```

To use your own Supabase project, set the URL and publishable key in
`mobile/lib/core/config/env.dart` (see `SUPABASE_SETUP_CHECKLIST.md`).
