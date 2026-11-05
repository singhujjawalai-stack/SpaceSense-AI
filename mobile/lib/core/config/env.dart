class Env {
  // Supabase Configuration
  // Replace these with your actual Supabase credentials from Step 3
  static const String supabaseUrl = 'https://tbipghyefwbrsxfvzlve.supabase.co'; // e.g., 'https://abcdefghijklmnop.supabase.co'
  static const String supabaseAnonKey = 'sb_publishable_jtlKt-kAYpY9_zWC6EGJNQ_QjI782ub'; // The long eyJhbGciOiJIUzI1... string

  // API Configuration
  // NOTE: There is no intermediary backend anymore — the app calls AI
  // providers (OpenAI/Anthropic/Google) directly via lib/core/ai/ai_service.dart.
  // This field is kept only for future use (e.g. a sync service).
  static const String apiBaseUrl = '';

  // Environment
  static const bool isProduction = false;
  static const bool enableLogging = true;
}
