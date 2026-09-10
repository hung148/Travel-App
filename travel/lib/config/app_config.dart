class AppConfig {
  static const bool isDebug = true; // flip to false for production
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const String aiAssistantUrl = String.fromEnvironment(
    'AI_ASSISTANT_URL',
  );

  /// Endpoint for the shopping-place vetting function.
  ///
  /// Usually left unset: both endpoints are the same host with the function
  /// name as the last path segment, in Firebase and in the local gateway
  /// alike, so it is derived from [aiAssistantUrl]. Set PLACE_VETTING_URL when
  /// the two live apart.
  static const String _placeVettingUrlOverride = String.fromEnvironment(
    'PLACE_VETTING_URL',
  );

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
  static String get itineraryImportUrl {
    const override = String.fromEnvironment('ITINERARY_IMPORT_URL');
    if (override.isNotEmpty) return override;
    final endpoint = aiAssistantUrl.trim();
    final swapped = endpoint.replaceFirst(RegExp(r'interpretTripRequest(?=$|[?#])'), 'importItinerary');
    return swapped == endpoint ? '' : swapped;
  }

  static String get placeVettingUrl {
    final override = _placeVettingUrlOverride.trim();
    if (override.isNotEmpty) return override;

    final assistant = aiAssistantUrl.trim();
    if (assistant.isEmpty) return '';
    // Swap the trailing function name, leaving any query string alone.
    final swapped = assistant.replaceFirst(
      RegExp(r'interpretTripRequest(?=$|[?#])'),
      'vetShoppingPlaces',
    );
    // No recognisable function name means we cannot guess. Returning empty
    // switches vetting off rather than posting to the wrong endpoint.
    return swapped == assistant ? '' : swapped;
  }
}
