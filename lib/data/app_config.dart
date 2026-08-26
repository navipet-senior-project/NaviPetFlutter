import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration loaded from the git-ignored `.env` file.
abstract final class AppConfig {
  static String get supabaseUrl =>
      dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';

  static String get supabasePublishableKey =>
      dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY')?.trim() ??
      dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ??
      '';

  static bool get hasSupabase =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      supabasePublishableKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      !supabasePublishableKey.contains('your_key');

  static String get backendBaseUrl =>
      dotenv.maybeGet('BACKEND_BASE_URL')?.trim() ?? '';

  static bool get hasBackend =>
      Uri.tryParse(backendBaseUrl)?.hasScheme == true &&
      backendBaseUrl.isNotEmpty;
}
