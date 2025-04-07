import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  late SharedPreferences _prefs;
  final Map<String, dynamic> _memoryCache = {};
  
  // Clés pour les différents types de données
  static const String _projectsKey = 'cached_projects';
  static const String _phasesKey = 'cached_phases';
  static const String _tasksKey = 'cached_tasks';
  static const String _transactionsKey = 'cached_transactions';
  static const String _teamsKey = 'cached_teams';
  static const String _userCachesKey = 'cached_users';
  
  // Informations sur la dernière mise à jour
  static const String _lastUpdateSuffixKey = '_last_updated';
  
  // Durée de validité du cache (en minutes)
  static const int _cacheValidityMinutes = 30;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Méthodes génériques de gestion du cache
  
  Future<void> saveToCache<T>(String key, T data) async {
    // Enregistrer dans le cache mémoire
    _memoryCache[key] = data;
    
    // Enregistrer dans le cache persistant
    if (data is List || data is Map) {
      await _prefs.setString(key, jsonEncode(data));
    } else if (data is String) {
      await _prefs.setString(key, data);
    } else if (data is int) {
      await _prefs.setInt(key, data);
    } else if (data is double) {
      await _prefs.setDouble(key, data);
    } else if (data is bool) {
      await _prefs.setBool(key, data);
    }
    
    // Mettre à jour le timestamp
    await _prefs.setInt('$key$_lastUpdateSuffixKey', DateTime.now().millisecondsSinceEpoch);
  }
  
  T? getFromCache<T>(String key) {
    // Vérifier d'abord le cache mémoire (plus rapide)
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key] as T?;
    }
    
    // Sinon vérifier le cache persistant
    if (_prefs.containsKey(key)) {
      if (T == List || T == Map) {
        final String? data = _prefs.getString(key);
        if (data != null) {
          final decoded = jsonDecode(data);
          _memoryCache[key] = decoded; // Mettre en cache mémoire pour les prochains accès
          return decoded as T?;
        }
      } else if (T == String) {
        return _prefs.getString(key) as T?;
      } else if (T == int) {
        return _prefs.getInt(key) as T?;
      } else if (T == double) {
        return _prefs.getDouble(key) as T?;
      } else if (T == bool) {
        return _prefs.getBool(key) as T?;
      }
    }
    
    return null;
  }
  
  bool isCacheValid(String key) {
    final lastUpdateKey = '$key$_lastUpdateSuffixKey';
    if (!_prefs.containsKey(lastUpdateKey)) {
      return false;
    }
    
    final lastUpdate = _prefs.getInt(lastUpdateKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = (now - lastUpdate) ~/ (1000 * 60); // Différence en minutes
    
    return diff < _cacheValidityMinutes;
  }
  
  Future<void> clearCache() async {
    _memoryCache.clear();
    await _prefs.clear();
  }
  
  // Méthodes spécifiques aux entités de l'application
  
  // Projets
  Future<void> cacheProjects(List<dynamic> projects) async {
    await saveToCache(_projectsKey, projects);
  }
  
  List<dynamic>? getCachedProjects() {
    return getFromCache<List<dynamic>>(_projectsKey);
  }
  
  bool areProjectsCacheValid() {
    return isCacheValid(_projectsKey);
  }
  
  // Phases
  Future<void> cachePhases(String? projectId, List<dynamic> phases) async {
    final key = projectId == null ? _phasesKey : '${_phasesKey}_$projectId';
    await saveToCache(key, phases);
  }
  
  List<dynamic>? getCachedPhases(String? projectId) {
    final key = projectId == null ? _phasesKey : '${_phasesKey}_$projectId';
    return getFromCache<List<dynamic>>(key);
  }
  
  bool arePhasesCacheValid(String? projectId) {
    final key = projectId == null ? _phasesKey : '${_phasesKey}_$projectId';
    return isCacheValid(key);
  }
  
  // Tâches
  Future<void> cacheTasks(String? projectId, List<dynamic> tasks) async {
    final key = projectId == null ? _tasksKey : '${_tasksKey}_$projectId';
    await saveToCache(key, tasks);
  }
  
  List<dynamic>? getCachedTasks(String? projectId) {
    final key = projectId == null ? _tasksKey : '${_tasksKey}_$projectId';
    return getFromCache<List<dynamic>>(key);
  }
  
  bool areTasksCacheValid(String? projectId) {
    final key = projectId == null ? _tasksKey : '${_tasksKey}_$projectId';
    return isCacheValid(key);
  }
  
  // Forcer l'invalidation du cache des projets
  Future<void> invalidateProjectsCache() async {
    // Supprimer l'entrée du cache ou mettre la date d'expiration dans le passé
    _memoryCache.remove(_projectsKey);
    await _prefs.remove(_projectsKey);
    await _prefs.remove('${_projectsKey}${_lastUpdateSuffixKey}');
  }
  
  // Transactions
  Future<void> cacheTransactions(String? projectId, List<dynamic> transactions) async {
    final key = projectId == null ? _transactionsKey : '${_transactionsKey}_$projectId';
    await saveToCache(key, transactions);
  }
  
  List<dynamic>? getCachedTransactions(String? projectId) {
    final key = projectId == null ? _transactionsKey : '${_transactionsKey}_$projectId';
    return getFromCache<List<dynamic>>(key);
  }
  
  bool areTransactionsCacheValid(String? projectId) {
    final key = projectId == null ? _transactionsKey : '${_transactionsKey}_$projectId';
    return isCacheValid(key);
  }
  
  // Équipes
  Future<void> cacheTeams(List<dynamic> teams) async {
    await saveToCache(_teamsKey, teams);
  }
  
  List<dynamic>? getCachedTeams() {
    return getFromCache<List<dynamic>>(_teamsKey);
  }
  
  bool areTeamsCacheValid() {
    return isCacheValid(_teamsKey);
  }
  
  // Cache des noms d'utilisateur (pour optimiser les appels répétés)
  Future<void> cacheUserDisplayName(String userId, String displayName) async {
    // Récupérer le cache actuel
    final userCache = getFromCache<Map<String, dynamic>>(_userCachesKey) ?? {};
    
    // Mettre à jour avec le nouveau nom
    userCache[userId] = displayName;
    
    // Sauvegarder le cache mis à jour
    await saveToCache(_userCachesKey, userCache);
  }
  
  String? getCachedUserDisplayName(String userId) {
    final userCache = getFromCache<Map<String, dynamic>>(_userCachesKey);
    if (userCache != null && userCache.containsKey(userId)) {
      return userCache[userId] as String?;
    }
    return null;
  }
}
