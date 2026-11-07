/// App-wide configuration.
///
/// Override the backend URL at build time:
///   flutter run --dart-define=API_BASE_URL=https://dekad-backend.onrender.com
/// The default points at a backend on your machine as seen from the Android
/// emulator (10.0.2.2 is the host's localhost).
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
