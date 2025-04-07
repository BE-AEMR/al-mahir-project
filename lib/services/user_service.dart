import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _profilesTable = 'profiles';
  
  // Cache pour les noms d'utilisateurs afin d'éviter de faire trop de requêtes
  final Map<String, String> _displayNameCache = {};

  // Récupérer le nom d'affichage d'un utilisateur par son ID
  Future<String> getUserDisplayName(String userId) async {
    // Vérifier si le nom est déjà dans le cache
    if (_displayNameCache.containsKey(userId)) {
      return _displayNameCache[userId]!;
    }
    
    try {
      // Récupérer les infos du profil depuis la table profiles
      final response = await _supabase
          .from(_profilesTable)
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      
      String displayName;
      
      if (response != null && response['display_name'] != null) {
        displayName = response['display_name'] as String;
      } else {
        // Essayer de récupérer l'email depuis auth.users comme fallback
        final authResponse = await _supabase
            .from('auth.users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();
        
        if (authResponse != null && authResponse['email'] != null) {
          displayName = authResponse['email'] as String;
        } else {
          displayName = 'Utilisateur $userId';
        }
      }
      
      // Stocker dans le cache
      _displayNameCache[userId] = displayName;
      
      return displayName;
    } catch (e) {
      // print('Erreur lors de la récupération du nom d\'utilisateur: $e');
      return 'Utilisateur $userId';
    }
  }
  
  // Récupérer plusieurs noms d'affichage en une seule requête
  Future<Map<String, String>> getUsersDisplayNames(List<String> userIds) async {
    if (userIds.isEmpty) {
      return {};
    }
    
    // Filtrer les IDs qui sont déjà dans le cache
    final uncachedIds = userIds.where((id) => !_displayNameCache.containsKey(id)).toList();
    
    if (uncachedIds.isNotEmpty) {
      try {
        // Récupérer les infos des profils depuis la table profiles
        final response = await _supabase
            .from(_profilesTable)
            .select('id, display_name')
            .inFilter('id', uncachedIds);
        
        // Ajouter les résultats au cache
        for (final profile in response) {
          final id = profile['id'] as String;
          final name = profile['display_name'] as String? ?? 'Utilisateur $id';
          _displayNameCache[id] = name;
        }
        
        // Vérifier s'il y a des IDs qui n'ont pas été trouvés
        final foundIds = response.map<String>((p) => p['id'] as String).toList();
        final missingIds = uncachedIds.where((id) => !foundIds.contains(id)).toList();
        
        if (missingIds.isNotEmpty) {
          // Essayer de récupérer les emails depuis auth.users comme fallback
          final authResponse = await _supabase
              .from('auth.users')
              .select('id, email')
              .inFilter('id', missingIds);
          
          for (final user in authResponse) {
            final id = user['id'] as String;
            final email = user['email'] as String? ?? 'Utilisateur $id';
            _displayNameCache[id] = email;
          }
          
          // Pour les IDs restants qui n'ont toujours pas été trouvés
          for (final id in missingIds) {
            if (!_displayNameCache.containsKey(id)) {
              _displayNameCache[id] = 'Utilisateur $id';
            }
          }
        }
      } catch (e) {
        // print('Erreur lors de la récupération des noms d\'utilisateurs: $e');
        // Ajouter des valeurs par défaut pour les IDs non trouvés
        for (final id in uncachedIds) {
          if (!_displayNameCache.containsKey(id)) {
            _displayNameCache[id] = 'Utilisateur $id';
          }
        }
      }
    }
    
    // Retourner les noms pour tous les IDs demandés
    return Map.fromEntries(
      userIds.map((id) => MapEntry(id, _displayNameCache[id] ?? 'Utilisateur $id'))
    );
  }
}
