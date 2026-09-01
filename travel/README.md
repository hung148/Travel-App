# travel

A new Flutter project.

## Getting Started

### Google Places planner data

For live destination candidates, enable the Google Places API (New) and
Geocoding API for a restricted development key, then run:

```powershell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_KEY
```

Without this define, the planner remains usable with the labeled mock Tokyo
dataset. Production builds should call Google Maps Platform through a protected
backend rather than distributing an unrestricted web-service key in the app.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
