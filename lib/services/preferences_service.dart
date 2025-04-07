import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _cagnotteUrlKey = 'cagnotte_url';
  static const String _defaultCagnotteUrl = 'https://www.cotizup.com/apprentissage-du-coran';

  // Singleton pattern
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  /// Récupère l'URL de la cagnotte configurée
  Future<String> getCagnotteUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cagnotteUrlKey) ?? _defaultCagnotteUrl;
  }

  /// Définit l'URL de la cagnotte
  Future<bool> setCagnotteUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_cagnotteUrlKey, url);
  }

  /// Vérifie si l'URL de la cagnotte a été configurée
  Future<bool> isCagnotteUrlConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_cagnotteUrlKey);
  }

  /// Réinitialise l'URL de la cagnotte (supprime la configuration)
  Future<bool> resetCagnotteUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_cagnotteUrlKey);
  }
}
