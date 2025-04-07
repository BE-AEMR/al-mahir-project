import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../models/user_profile.dart';
import '../models/project_model.dart';

/// Service pour gérer les rôles et permissions dans le système RBAC
class RoleService {
  final SupabaseClient _client;

  RoleService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  /// Vérifie si l'utilisateur courant a une permission spécifique
  Future<bool> hasPermission(
    String permissionName, {
    String? teamId,
    String? projectId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('=== RBAC DEBUG === Pas d\'utilisateur connecté, permission refusée');
        return false;
      }
      
      print('\n=== RBAC DEBUG === [DÉBUT] Vérification permission: $permissionName');
      print('=== RBAC DEBUG === Utilisateur: $userId');
      if (teamId != null) {
        print('=== RBAC DEBUG === Contexte d\'équipe: $teamId');
      }
      if (projectId != null) {
        print('=== RBAC DEBUG === Contexte de projet: $projectId');
      }
      
      // Récupérer détails de la permission
      print('=== RBAC DEBUG === Récupération des détails de la permission: $permissionName');
      final permissionDetails = await _client
          .from('permissions')
          .select('id, name, description, resource_type, action')
          .eq('name', permissionName)
          .maybeSingle();
      
      if (permissionDetails != null) {
        print('=== RBAC DEBUG === Permission trouvée: ${permissionDetails['description']} (type: ${permissionDetails['resource_type']}, action: ${permissionDetails['action']})');
      } else {
        print('=== RBAC DEBUG === ATTENTION: Permission "$permissionName" non trouvée dans la base de données!');
      }
      
      // Récupérer directement les rôles et permissions pour DEBUG
      final userRolesWithPermissionsResponse = await _client.from('user_roles')
          .select('''
            role_id,
            roles (
              id, 
              name, 
              description
            ),
            team_id,
            project_id
          ''')
          .eq('user_id', userId);
      
      print('=== RBAC DEBUG === Rôles attribués à l\'utilisateur:');
      List<Map<String, dynamic>> userRoles = [];
      
      for (var roleData in userRolesWithPermissionsResponse) {
        final roleName = roleData['roles']['name'];
        final roleId = roleData['roles']['id'];
        final roleDesc = roleData['roles']['description'];
        final roleTeamId = roleData['team_id'];
        final roleProjectId = roleData['project_id'];
        
        userRoles.add({
          'id': roleId,
          'name': roleName,
          'description': roleDesc,
          'team_id': roleTeamId,
          'project_id': roleProjectId
        });
        
        print('=== RBAC DEBUG ===   - Rôle: $roleName ($roleDesc)');
        if (roleTeamId != null) print('=== RBAC DEBUG ===     → Équipe: $roleTeamId');
        if (roleProjectId != null) print('=== RBAC DEBUG ===     → Projet: $roleProjectId');
      }
      
      // Si l'utilisateur est un admin système, accorder automatiquement toutes les permissions
      final isSystemAdmin = userRoles.any((role) => role['name'] == 'system_admin');
      if (isSystemAdmin) {
        print('=== RBAC DEBUG === L\'utilisateur est system_admin, permission $permissionName accordée automatiquement');
        return true;
      }

      // Pour le rôle project_manager, vérifier si un des rôles correspond exactement au projet demandé
      if (projectId != null) {
        final projectManagerRole = userRoles.where(
          (role) => role['name'] == 'project_manager' && role['project_id'] == projectId
        ).toList();
        
        if (projectManagerRole.isNotEmpty) {
          print('=== RBAC DEBUG === Utilisateur a le rôle project_manager pour ce projet spécifique');
          
          // Récupérer toutes les permissions pour le rôle project_manager directement avec la bonne structure
          final projectManagerRoleId = projectManagerRole.first['id'];
          if (projectManagerRoleId != null) {
            print('=== RBAC DEBUG === ID du rôle project_manager: $projectManagerRoleId');
            
            final rolePermissions = await _client
                .from('role_permissions')
                .select('permissions (name)')
                .eq('role_id', projectManagerRoleId);
            
            final permissions = rolePermissions.map((p) => p['permissions']['name'] as String).toList();
            print('=== RBAC DEBUG === Permissions du project_manager: $permissions');
            
            if (permissions.contains(permissionName)) {
              print('=== RBAC DEBUG === [RÉSULTAT FINAL] Permission $permissionName trouvée pour le project_manager, ACCORDÉE');
              return true;
            }
          }
        }
      }

      // Pour les autres rôles, vérifier dans la base de données      
      print('=== RBAC DEBUG === Appel de la RPC user_has_permission avec:');
      print('=== RBAC DEBUG ===   - user_id: $userId');
      print('=== RBAC DEBUG ===   - permission_name: $permissionName');
      print('=== RBAC DEBUG ===   - team_id: $teamId');
      print('=== RBAC DEBUG ===   - project_id: $projectId');
      
      final response = await _client.rpc('user_has_permission', params: {
        'p_user_id': userId,
        'p_permission_name': permissionName,
        'p_team_id': teamId,
        'p_project_id': projectId,
      });
      
      print('=== RBAC DEBUG === Réponse de la RPC: $response');
      
      // Si la permission n'est pas accordée, vérifier les contextes plus larges
      if (response != true) {
        if (projectId != null) {
          print('=== RBAC DEBUG === Permission refusée pour le projet spécifique, vérification du contexte global...');
          
          // Vérifier si l'utilisateur a cette permission dans un contexte global (sans projet)
          final hasGlobalPermission = await _client.rpc('user_has_permission', params: {
            'p_user_id': userId,
            'p_permission_name': permissionName,
            'p_team_id': teamId,
            'p_project_id': null,
          });
          
          print('=== RBAC DEBUG === Permission dans le contexte global: $hasGlobalPermission');
          
          if (hasGlobalPermission == true) {
            print('=== RBAC DEBUG === Permission accordée via un contexte global');
            return true;
          }
        }
        
        if (teamId != null) {
          print('=== RBAC DEBUG === Permission refusée dans le contexte d\'équipe spécifique, vérification sans équipe...');
          
          // Vérifier si l'utilisateur a cette permission sans contexte d'équipe
          final hasNonTeamPermission = await _client.rpc('user_has_permission', params: {
            'p_user_id': userId,
            'p_permission_name': permissionName,
            'p_team_id': null,
            'p_project_id': projectId,
          });
          
          print('=== RBAC DEBUG === Permission sans contexte d\'équipe: $hasNonTeamPermission');
          
          if (hasNonTeamPermission == true) {
            print('=== RBAC DEBUG === Permission accordée sans contexte d\'équipe');
            return true;
          }
        }
      }

      print('=== RBAC DEBUG === [RÉSULTAT FINAL] Permission ' + 
            (response == true ? 'ACCORDÉE' : 'REFUSÉE') + 
            ' pour ' + permissionName);
      return response ?? false;
    } catch (e) {
      print('=== RBAC DEBUG === ERREUR lors de la vérification de la permission: $e');
      print('=== RBAC DEBUG === Stack trace: ${e is Error ? e.stackTrace : "Non disponible"}');
      return false;
    }
  }

  /// Vérifie si l'utilisateur courant peut accéder à un projet
  Future<bool> canAccessProject(String projectId) async {
    try {
      final response = await _client.rpc('can_access_project', params: {
        'project_id': projectId,
      });
      
      return response ?? false;
    } catch (e) {
      print('Erreur lors de la vérification de l\'accès au projet: $e');
      return false;
    }
  }

  /// Vérifie si l'utilisateur courant peut modifier un projet
  Future<bool> canModifyProject(String projectId) async {
    try {
      final response = await _client.rpc('can_modify_project', params: {
        'project_id': projectId,
      });
      
      return response ?? false;
    } catch (e) {
      print('Erreur lors de la vérification des droits de modification: $e');
      return false;
    }
  }

  /// Attribue un rôle à un utilisateur
  Future<bool> assignRole({
    required String userId,
    required String roleName,
    String? teamId,
    String? projectId,
  }) async {
    try {
      // Récupérer l'ID du rôle par son nom
      final rolesResponse = await _client
          .from('roles')
          .select('id')
          .eq('name', roleName)
          .single();
      
      final roleId = rolesResponse['id'] as String;
      
      // Insérer le rôle utilisateur
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role_id': roleId,
        'team_id': teamId,
        'project_id': projectId,
        'created_by': _client.auth.currentUser?.id,
      });
      
      return true;
    } catch (e) {
      print('Erreur lors de l\'attribution du rôle: $e');
      return false;
    }
  }

  /// Récupère tous les rôles disponibles dans le système
  Future<List<Role>> getAllRoles() async {
    try {
      final response = await _client.from('roles').select().order('name');
      return response.map((json) => Role.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des rôles: $e');
      return [];
    }
  }

  /// Récupère toutes les permissions disponibles dans le système
  Future<List<Permission>> getAllPermissions() async {
    try {
      final response = await _client.from('permissions').select().order('resource_type, action');
      return response.map((json) => Permission.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des permissions: $e');
      return [];
    }
  }

  /// Récupère tous les rôles utilisateurs dans le système
  Future<List<UserRole>> getAllUserRoles() async {
    try {
      print('DEBUG: Récupération de tous les user_roles');
      final response = await _client
          .from('user_roles')
          .select('''
            *,
            roles (*),
            teams (*)
          ''')
          .order('created_at');
      
      print('DEBUG: Réponse user_roles: ${response.length} éléments');
      if (response.isEmpty) {
        print('DEBUG: Aucun user_role trouvé dans la base de données');
        return [];
      }
      
      // Convertir en objets UserRole (sans les projets pour l'instant)
      List<UserRole> userRoles = [];
      for (var userRoleJson in response) {
        print('DEBUG: Traitement du user_role ID: ${userRoleJson['id']}');
        
        // Créer l'objet UserRole de base (sans projet)
        final userRole = UserRole.fromJson(userRoleJson);
        
        try {
          // Récupérer les projets associés à ce user_role depuis la nouvelle table
          final projectsResponse = await _client
              .from('user_role_projects')
              .select('''
                projects (*)
              ''')
              .eq('user_role_id', userRole.id);
          
          print('DEBUG: Projets trouvés pour ce user_role: ${projectsResponse.length}');
          
          // Si ce rôle a des projets associés via user_role_projects, utiliser le premier pour l'affichage
          if (projectsResponse.isNotEmpty) {
            try {
              final projectData = projectsResponse[0]['projects'];
              
              // Créer un objet Project à partir des données JSON
              final Project projectObject = Project.fromJson(projectData);
              
              // Mettre à jour le userRole avec le premier projet trouvé (pour affichage initial)
              userRoles.add(UserRole(
                id: userRole.id,
                userId: userRole.userId,
                roleId: userRole.roleId,
                role: userRole.role,
                teamId: userRole.teamId,
                team: userRole.team,
                projectId: projectObject.id,  // Utiliser l'ID du projet
                project: projectObject,  // Utiliser l'objet Project correctement créé
                createdAt: userRole.createdAt,
                createdBy: userRole.createdBy,
                userProfile: userRole.userProfile,
                // Stocker tous les projets associés pour usage ultérieur (données brutes)
                associatedProjects: projectsResponse.map((pr) => pr['projects']).toList(),
              ));
            } catch (e) {
              print('DEBUG: Erreur lors de la conversion du projet: $e');
              // En cas d'erreur, ajouter quand même le userRole de base
              userRoles.add(userRole);
            }
          } else {
            // Si aucun projet n'est associé, ajouter le userRole tel quel
            userRoles.add(userRole);
          }
        } catch (e) {
          print('DEBUG: Erreur lors de la récupération des projets associés: $e');
          // En cas d'erreur, ajouter quand même le userRole de base
          userRoles.add(userRole);
        }
      }
      
      print('DEBUG: Nombre total de user_roles récupérés: ${userRoles.length}');
      
      // Pour chaque userRole, récupérer les informations de profil
      for (var i = 0; i < userRoles.length; i++) {
        try {
          final userProfile = await _client
              .from('profiles')
              .select('id, email, display_name')
              .eq('id', userRoles[i].userId)
              .single();
          
          if (userProfile != null) {
            // Mettre à jour le modèle UserRole avec les infos de profil
            userRoles[i] = UserRole(
              id: userRoles[i].id,
              userId: userRoles[i].userId,
              roleId: userRoles[i].roleId,
              role: userRoles[i].role,
              teamId: userRoles[i].teamId,
              team: userRoles[i].team,
              projectId: userRoles[i].projectId,
              project: userRoles[i].project,
              createdAt: userRoles[i].createdAt,
              createdBy: userRoles[i].createdBy,
              userProfile: UserProfile.fromJson(userProfile),
              associatedProjects: userRoles[i].associatedProjects,
            );
          }
        } catch (e) {
          print('Erreur lors de la récupération du profil utilisateur ${userRoles[i].userId}: $e');
        }
      }
      
      return userRoles;
    } catch (e) {
      print('Erreur lors de la récupération des rôles utilisateurs: $e');
      return [];
    }
  }

  /// Récupère les rôles d'un utilisateur spécifique
  Future<List<UserRole>> getUserRoles(String userId) async {
    try {
      print('DEBUG: Récupération des rôles de l\'utilisateur: $userId');
      final response = await _client
          .from('user_roles')
          .select('''
            *,
            roles (*),
            teams (*)
          ''')
          .eq('user_id', userId)
          .order('created_at');
      
      print('DEBUG: Réponse user_roles pour utilisateur $userId: ${response.length} éléments');
      
      // Convertir en objets UserRole (sans les projets pour l'instant)
      List<UserRole> userRoles = [];
      for (var userRoleJson in response) {
        print('DEBUG: Traitement du user_role ID: ${userRoleJson['id']}');
        
        // Créer l'objet UserRole de base (sans projet)
        final userRole = UserRole.fromJson(userRoleJson);
        
        try {
          // Récupérer les projets associés à ce user_role depuis la nouvelle table
          final projectsResponse = await _client
              .from('user_role_projects')
              .select('''
                projects (*)
              ''')
              .eq('user_role_id', userRole.id);
          
          print('DEBUG: Projets trouvés pour ce user_role: ${projectsResponse.length}');
          
          // Si ce rôle a des projets associés via user_role_projects, utiliser le premier pour l'affichage
          if (projectsResponse.isNotEmpty) {
            try {
              final projectData = projectsResponse[0]['projects'];
              
              // Créer un objet Project à partir des données JSON
              final Project projectObject = Project.fromJson(projectData);
              
              // Mettre à jour le userRole avec le premier projet trouvé (pour affichage initial)
              userRoles.add(UserRole(
                id: userRole.id,
                userId: userRole.userId,
                roleId: userRole.roleId,
                role: userRole.role,
                teamId: userRole.teamId,
                team: userRole.team,
                projectId: projectObject.id,  // Utiliser l'ID du projet
                project: projectObject,  // Utiliser l'objet Project correctement créé
                createdAt: userRole.createdAt,
                createdBy: userRole.createdBy,
                userProfile: userRole.userProfile,
                // Stocker tous les projets associés pour usage ultérieur (données brutes)
                associatedProjects: projectsResponse.map((pr) => pr['projects']).toList(),
              ));
            } catch (e) {
              print('DEBUG: Erreur lors de la conversion du projet: $e');
              // En cas d'erreur, ajouter quand même le userRole de base
              userRoles.add(userRole);
            }
          } else {
            // Si aucun projet n'est associé, ajouter le userRole tel quel
            userRoles.add(userRole);
          }
        } catch (e) {
          print('DEBUG: Erreur lors de la récupération des projets associés: $e');
          // En cas d'erreur, ajouter quand même le userRole de base
          userRoles.add(userRole);
        }
      }
      
      // Récupérer les informations de profil de l'utilisateur
      try {
        final userProfile = await _client
            .from('profiles')
            .select('id, email, display_name')
            .eq('id', userId)
            .single();
        
        if (userProfile != null) {
          final profile = UserProfile.fromJson(userProfile);
          
          // Mettre à jour tous les UserRole avec les mêmes informations de profil
          for (int i = 0; i < userRoles.length; i++) {
            userRoles[i] = UserRole(
              id: userRoles[i].id,
              userId: userRoles[i].userId,
              roleId: userRoles[i].roleId,
              role: userRoles[i].role,
              teamId: userRoles[i].teamId,
              team: userRoles[i].team,
              projectId: userRoles[i].projectId,
              project: userRoles[i].project,
              createdAt: userRoles[i].createdAt,
              createdBy: userRoles[i].createdBy,
              userProfile: profile,
              associatedProjects: userRoles[i].associatedProjects,
            );
          }
        }
      } catch (e) {
        print('Erreur lors de la récupération du profil utilisateur $userId: $e');
      }
      
      return userRoles;
    } catch (e) {
      print('Erreur lors de la récupération des rôles de l\'utilisateur: $e');
      return [];
    }
  }

  /// Supprime un rôle utilisateur
  Future<bool> deleteUserRole(String userRoleId) async {
    try {
      await _client.from('user_roles').delete().eq('id', userRoleId);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du rôle utilisateur: $e');
      return false;
    }
  }

  /// Récupère les noms des rôles de l'utilisateur actuellement connecté
  Future<List<String>> getUserRolesWithoutParam() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return ['Non connecté'];
      
      final response = await _client.from('user_roles').select('roles (name)').eq('user_id', userId);
      final roles = (response as List).map((role) => role['roles']['name'] as String).toList();
      
      return roles.isNotEmpty ? roles : ['Aucun rôle'];
    } catch (e) {
      print('Erreur lors de la récupération des rôles: $e');
      return ['Erreur'];
    }
  }

  /// Récupère les informations détaillées des rôles de l'utilisateur (incluant team_id et project_id)
  Future<List<Map<String, dynamic>>> getUserRolesDetails() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [{'error': 'Non connecté'}];
      
      final response = await _client
          .from('user_roles')
          .select('*, roles (id, name)')
          .eq('user_id', userId);
      
      // Convertir la réponse en liste de Map
      List<Map<String, dynamic>> roleDetails = [];
      for (var role in response) {
        roleDetails.add({
          'role_id': role['role_id'],
          'role_name': role['roles']['name'],
          'team_id': role['team_id'],
          'project_id': role['project_id'],
          'user_id': role['user_id'],
        });
      }
      
      print('DEBUG: Détails des rôles récupérés: $roleDetails');
      return roleDetails;
    } catch (e) {
      print('Erreur lors de la récupération des détails des rôles: $e');
      return [{'error': e.toString()}];
    }
  }

  /// Récupère les informations sur tous les utilisateurs
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, email, display_name')
          .order('display_name');
      
      return response;
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
      return [];
    }
  }

  /// Récupère les rôles d'un utilisateur avec les détails associés
  Future<List<Map<String, dynamic>>> getUserRolesWithDetails(String userId) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('role_id, roles (name, description), team_id, project_id')
          .eq('user_id', userId);
      
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Erreur lors de la récupération des rôles de l\'utilisateur: $e');
      return [];
    }
  }
  
  /// Récupère les permissions associées à un rôle
  Future<List<Map<String, dynamic>>> getRolePermissions(String roleId) async {
    try {
      final response = await _client
          .from('role_permissions')
          .select('permissions (name, description)')
          .eq('role_id', roleId);
      
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('Erreur lors de la récupération des permissions du rôle: $e');
      return [];
    }
  }
}
