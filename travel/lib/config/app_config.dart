class AppConfig {
  static const bool isDebug = true; // flip to false for production
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String aiAssistantUrl = String.fromEnvironment(
    'AI_ASSISTANT_URL',
  );

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
}
