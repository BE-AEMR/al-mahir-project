import 'package:flutter/material.dart';
import 'package:webxio_new/services/role_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour le service de gestion des rôles et permissions (RBAC)
class RoleProvider extends ChangeNotifier {
  final RoleService _roleService;
  
  // Cache des permissions vérifiées pour éviter des appels répétés à Supabase
  final Map<String, bool> _permissionCache = {};

  RoleProvider() : _roleService = RoleService(Supabase.instance.client);

  /// Vérifie si l'utilisateur courant a une permission spécifique
  Future<bool> hasPermission(
    String permissionName, {
    String? teamId,
    String? projectId,
  }) async {
    // Clé de cache pour cette vérification spécifique
    final cacheKey = '${permissionName}_${teamId ?? ''}_${projectId ?? ''}';
    print('DEBUG: RoleProvider.hasPermission() - Vérification de la permission: $permissionName');
    print('DEBUG: RoleProvider.hasPermission() - Clé de cache: $cacheKey');
    
    // Vérifier si on a déjà le résultat en cache
    if (_permissionCache.containsKey(cacheKey)) {
      print('DEBUG: RoleProvider.hasPermission() - Résultat trouvé en cache: ${_permissionCache[cacheKey]}');
      return _permissionCache[cacheKey]!;
    }
    
    print('DEBUG: RoleProvider.hasPermission() - Pas de cache, appel au service');
    // Sinon, demander au service et stocker le résultat en cache
    final hasPermission = await _roleService.hasPermission(
      permissionName,
      teamId: teamId,
      projectId: projectId,
    );
    
    print('DEBUG: RoleProvider.hasPermission() - Résultat du service: $hasPermission');
    
    // Journalisation détaillée des rôles de l'utilisateur pour diagnostic
    try {
      final userRoles = await _roleService.getUserRolesWithoutParam();
      print('DEBUG: RoleProvider.hasPermission() - Rôles de l\'utilisateur: $userRoles');
      
      final rolesDetails = await _roleService.getUserRolesDetails();
      print('DEBUG: RoleProvider.hasPermission() - Détails des rôles: $rolesDetails');
    } catch (e) {
      print('DEBUG: RoleProvider.hasPermission() - Erreur lors de la récupération des détails des rôles: $e');
    }
    
    _permissionCache[cacheKey] = hasPermission;
    return hasPermission;
  }

  /// Vérifie si l'utilisateur peut accéder à un projet
  Future<bool> canAccessProject(String projectId) async {
    return _roleService.canAccessProject(projectId);
  }

  /// Vérifie si l'utilisateur peut modifier un projet
  Future<bool> canModifyProject(String projectId) async {
    return _roleService.canModifyProject(projectId);
  }

  /// Vide le cache des permissions (à appeler en cas de changement de rôle)
  void clearPermissionCache() {
    _permissionCache.clear();
    notifyListeners();
  }

  /// Récupère la liste des noms de rôles de l'utilisateur courant
  Future<List<String>> getUserRoles() async {
    try {
      return await _roleService.getUserRolesWithoutParam();
    } catch (e) {
      print('Erreur lors de la récupération des rôles: $e');
      return ['Erreur'];
    }
  }
  
  /// Récupère les informations détaillées des rôles de l'utilisateur (y compris team_id, project_id)
  Future<List<Map<String, dynamic>>> getUserRolesDetails() async {
    try {
      return await _roleService.getUserRolesDetails();
    } catch (e) {
      print('Erreur lors de la récupération des détails des rôles: $e');
      return [{'error': e.toString()}];
    }
  }
}
