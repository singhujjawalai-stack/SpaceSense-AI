# Changelog

All notable changes to SpaceSense AI. High-level only — for every detail,
see the commit history on GitHub.

## [1.3.0] — 2026-11-07

### Added
- **Today's Usage** gauge in Settings: how many room analyses and images
  you've run today on the free tiers, resetting daily at ~1:30 PM IST
  (midnight Pacific)
- **Fast recovery from rate limits**: if an analysis hits a provider quota,
  the failure dialog offers a one-tap retry on OpenRouter's free models
- **History search & sort**: find scans by room name, and reorder by
  newest, top scores, or ones needing attention

## [1.2.3] — 2026-11-07

### Improved
- Analysis failures are honest: automatic retries now fit in a ~3.5-minute
  total budget, and the final message explains what to try next
- Cleaner analysis screen (progress tracker without the oversized spinner)
- Keyboard never auto-pops anymore and hides itself when finished
- Home stats and History update instantly after each analysis

## [1.2.2] — 2026-11-07

### Added
- **Guided first-run setup**: tapping the home banner now opens a guided
  three-step key setup (pick provider → tap to key-creation page → paste &
  save), with "advanced options" delegating to Settings
- **Sample report**: a bundled hand-crafted Living Room analysis lets new
  users explore the full results experience before adding any key or photo
- **Progress tracking**: rescanning the same room now shows a "±N pts vs
  last scan" badge on results and history — improvements become visible
- **Checkbox action plan**: recommendations can be ticked off with a live
  projected score gain; ticks persist per report
- **Before/after slider**: Reimagine results open as a drag-to-compare view
  (original photo vs AI "after"), starting mid-split

### Fixed
- Deleting the API key now immediately restores the home setup banner
- Copied-paste key artifacts (quotes, `key=` prefixes, line breaks) are
  stripped automatically on save and validation
- Transient network drops during analysis auto-retry (up to 2 attempts)
  instead of failing the whole scan
- API keys are never displayed in error dialogs or logs anymore (all
  provider URLs shown with credentials redacted)

## [1.2.1] — 2026-11-06

### Added
- **OpenRouter provider** for room analysis with free `:free` models
  selectable in Settings; provider order is free-first
- Tap-through "Create an API key on <provider>" links open each provider's
  key-creation page directly
- Reimagine now routes by the selected provider (Google keys → Gemini image
  models with OpenRouter fallback; OpenRouter keys → their free path;
  other providers get a clear capability message)

### Fixed
- OpenRouter key validation uses an authenticated endpoint — junk keys are
  rejected instead of "connected"
- Dead, quota-capped, or payload-rejecting free model variants each hop to
  the next candidate; no raw provider errors reach the UI

## [1.1.0] — 2026-11-05

### Added
- **Reimagine**: AI-restyle the room (Decluttered / Brighter / Minimalist /
  More storage / Modern refresh, up to 3 at once), generated in the
  background so you can leave during processing; results persist per room
  with share & regenerate
- Optional OpenRouter fallback key for free-tier image generation backup

### Improved
- Camera compression (1600 px) — analysis runs ~3× faster
- Processing screen: live step tracker with elapsed timer

## [1.0.0] — 2026-11-04

- Initial public release: sign-in, room photo analysis with 6-dimensional
  scoring, recommendations with impact ranking, product suggestions,
  history, and direct provider calls (Google Gemini / OpenRouter /
  OpenAI / Anthropic) using the user's own free-tier keys — $0 end-to-end
