import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../config/supabase_config.dart';
import '../../models/team_model.dart';
import '../auth_service.dart';
import '../email_service.dart';
import '../notification_service.dart';
import '../role_service.dart';
import '../../models/project_model.dart';

class TeamService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  static const String _teamsTable = 'teams';
  static const String _teamMembersTable = 'team_members';
  static const String _teamProjectsTable = 'team_projects';
  static const String _teamTasksTable = 'team_tasks';
  static const String _invitationsTable = 'invitations';
  static const String _projectsTable = 'projects';
  static const String _usersTable = 'users';
  static const String _profilesTable = 'profiles';
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();

  // Équipes
  Future<List<Team>> getTeams() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return []; // Si utilisateur non connecté, retourner une liste vide
      }
      
      // Récupérer les équipes dont l'utilisateur est membre
      final response = await _supabase
          .from(_teamMembersTable)
          .select('team_id')
          .eq('user_id', user.id)
          .eq('status', TeamMemberStatus.active.toValue());
      
      final teamIds = response.map<String>((json) => json['team_id'] as String).toList();
      
      if (teamIds.isEmpty) {
        return [];
      }
      
      // Récupérer les détails de ces équipes
      final teamsResponse = await _supabase
          .from(_teamsTable)
          .select()
          .inFilter('id', teamIds)
          .order('name');
      
      return teamsResponse.map<Team>((json) => Team.fromJson(json)).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des équipes: $e');
      rethrow;
    }
  }

  Future<Team> getTeam(String teamId) async {
    try {
      final response = await _supabase
          .from(_teamsTable)
          .select()
          .eq('id', teamId)
          .single();
      
      return Team.fromJson(response);
    } catch (e) {
      // print('Erreur lors de la récupération de l\'équipe: $e');
      rethrow;
    }
  }

  Future<Team> createTeam(Team team) async {
    try {
      // Vérifier si l'utilisateur a la permission de créer une équipe
      final hasPermission = await _roleService.hasPermission('create_team');
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de créer une équipe');
      }
      
      // Vérifier si createdBy est vide et le définir si nécessaire
      String createdBy = team.createdBy;
      if (createdBy.isEmpty) {
        final currentUser = _supabase.auth.currentUser;
        if (currentUser == null) {
          throw Exception("Utilisateur non connecté");
        }
        createdBy = currentUser.id;
      }
      
      // Créer une copie de l'équipe avec le bon createdBy
      final teamToCreate = team.copyWith(createdBy: createdBy);
      
      final response = await _supabase
          .from(_teamsTable)
          .insert(teamToCreate.toJson())
          .select()
          .single();
      
      // Ajouter automatiquement le créateur comme administrateur
      await _supabase.from(_teamMembersTable).insert({
        'id': const Uuid().v4(),
        'team_id': response['id'],
        'user_id': createdBy,
        'role': TeamMemberRole.admin.toValue(),
        'status': TeamMemberStatus.active.toValue(),
      });
      
      return Team.fromJson(response);
    } catch (e) {
      // print('Erreur lors de la création de l\'équipe: $e');
      rethrow;
    }
  }

  Future<Team> updateTeam(Team team) async {
    try {
      // Vérifier si l'utilisateur a la permission de mettre à jour cette équipe
      final hasPermission = await _roleService.hasPermission(
        'update_team',
        teamId: team.id,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de modifier cette équipe');
      }
      
      final response = await _supabase
          .from(_teamsTable)
          .update(team.toJson())
          .eq('id', team.id)
          .select()
          .single();
      
      return Team.fromJson(response);
    } catch (e) {
      // print('Erreur lors de la mise à jour de l\'équipe: $e');
      rethrow;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      // Vérifier si l'utilisateur a la permission de supprimer cette équipe
      final hasPermission = await _roleService.hasPermission(
        'delete_team',
        teamId: teamId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de supprimer cette équipe');
      }
      
      await _supabase
          .from(_teamsTable)
          .delete()
          .eq('id', teamId);
    } catch (e) {
      // print('Erreur lors de la suppression de l\'équipe: $e');
      rethrow;
    }
  }

  // Membres d'équipe
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      // Récupérer les membres d'équipe avec jointure à la table profiles
      final response = await _supabase
          .from(_teamMembersTable)
          .select('*, profiles:user_id(email, display_name, avatar_url)')
          .eq('team_id', teamId);
      
      return response.map<TeamMember>((json) {
        final userInfo = json['profiles'] as Map<String, dynamic>?;
        return TeamMember.fromJson({
          ...json,
          'user_email': userInfo?['email'],
          'user_name': userInfo?['display_name'],
        });
      }).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des membres de l\'équipe: $e');
      rethrow;
    }
  }

  Future<TeamMember> addTeamMember(TeamMember member) async {
    try {
      final response = await _supabase
          .from(_teamMembersTable)
          .insert(member.toJson())
          .select()
          .single();
      
      return TeamMember.fromJson(response);
    } catch (e) {
      // print('Erreur lors de l\'ajout du membre à l\'équipe: $e');
      rethrow;
    }
  }

  Future<TeamMember> updateTeamMember(TeamMember member) async {
    try {
      final response = await _supabase
          .from(_teamMembersTable)
          .update(member.toJson())
          .eq('id', member.id)
          .select()
          .single();
      
      return TeamMember.fromJson(response);
    } catch (e) {
      // print('Erreur lors de la mise à jour du membre de l\'équipe: $e');
      rethrow;
    }
  }

  Future<void> removeTeamMember(String memberId) async {
    try {
      await _supabase
          .from(_teamMembersTable)
          .delete()
          .eq('id', memberId);
    } catch (e) {
      // print('Erreur lors de la suppression du membre de l\'équipe: $e');
      rethrow;
    }
  }

  // Projets d'équipe
  Future<List<Project>> getTeamProjects(String teamId) async {
    try {
      final response = await _supabase
          .from(_teamProjectsTable)
          .select('project_id')
          .eq('team_id', teamId);
      
      final projectIds = response.map<String>((json) => json['project_id'] as String).toList();
      
      if (projectIds.isEmpty) {
        return [];
      }
      
      final projectsResponse = await _supabase
          .from(_projectsTable)
          .select()
          .inFilter('id', projectIds);
      
      return projectsResponse.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des projets de l\'équipe: $e');
      rethrow;
    }
  }

  Future<List<Team>> getTeamsByProject(String projectId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return []; // Si utilisateur non connecté, retourner une liste vide
      }

      // Récupérer les équipes dont l'utilisateur est membre
      final userTeamsResponse = await _supabase
          .from(_teamMembersTable)
          .select('team_id')
          .eq('user_id', user.id)
          .eq('status', TeamMemberStatus.active.toValue());
      
      final userTeamIds = userTeamsResponse.map<String>((json) => json['team_id'] as String).toList();
      
      if (userTeamIds.isEmpty) {
        return [];
      }
      
      // Récupérer les équipes associées au projet
      final response = await _supabase
          .from(_teamProjectsTable)
          .select('team_id')
          .eq('project_id', projectId);
      
      final teamIds = response.map<String>((json) => json['team_id'] as String).toList();
      
      if (teamIds.isEmpty) {
        return [];
      }
      
      // Ne garder que les équipes dont l'utilisateur est membre
      final filteredTeamIds = teamIds.where((id) => userTeamIds.contains(id)).toList();
      
      if (filteredTeamIds.isEmpty) {
        return [];
      }
      
      final teamsResponse = await _supabase
          .from(_teamsTable)
          .select()
          .inFilter('id', filteredTeamIds);
      
      return teamsResponse.map<Team>((json) => Team.fromJson(json)).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des équipes du projet: $e');
      rethrow;
    }
  }

  Future<bool> addProjectToTeam(String teamId, String projectId) async {
    try {
      // Utiliser une procédure stockée côté serveur qui s'exécute avec les privilèges
      // du serveur pour contourner les contraintes RLS
      await _supabase.rpc('add_project_to_team', params: {
        'p_team_id': teamId,
        'p_project_id': projectId,
      });
      
      // Si la RPC n'est pas disponible ou échoue, on essaie la méthode traditionnelle
      // mais elle risque d'échouer en fonction des droits RLS
      /*
      await _supabase
          .from(_teamProjectsTable)
          .insert({
            'id': const Uuid().v4(),
            'team_id': teamId,
            'project_id': projectId,
          });
      */
      
      // Envoyer une notification pour informer que le projet a été ajouté à l'équipe
      try {
        final team = await getTeam(teamId);
        final project = await _supabase
            .from(_projectsTable)
            .select()
            .eq('id', projectId)
            .single();
            
        await _notifyProjectAddedToTeam(team, Project.fromJson(project));
      } catch (notifError) {
        // print('Erreur lors de l\'envoi de la notification: $notifError');
        // On ne propage pas l'erreur pour ne pas interrompre le flux principal
      }
      
      // Retourner true pour indiquer le succès
      return true;
    } catch (e) {
      print('Erreur lors de l\'ajout du projet à l\'équipe: $e');
      // Retourner false pour indiquer l'échec
      return false;
    }
  }

  Future<void> removeProjectFromTeam(String teamId, String projectId) async {
    try {
      await _supabase
          .from(_teamProjectsTable)
          .delete()
          .eq('team_id', teamId)
          .eq('project_id', projectId);
    } catch (e) {
      // print('Erreur lors de la suppression du projet de l\'équipe: $e');
      rethrow;
    }
  }

  Future<bool> removeAllTeamsFromProject(String projectId) async {
    try {
      // Utiliser une procédure stockée côté serveur qui s'exécute avec les privilèges
      // du serveur pour contourner les contraintes RLS
      await _supabase.rpc('remove_all_teams_from_project', params: {
        'p_project_id': projectId,
      });
      
      // Retourner true pour indiquer le succès
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de toutes les équipes du projet: $e');
      // Retourner false pour indiquer l'échec mais sans propager l'erreur
      return false;
    }
  }

  // Tâches d'équipe
  Future<List<Team>> getTeamsByTask(String taskId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return []; // Si utilisateur non connecté, retourner une liste vide
      }

      // Récupérer les équipes dont l'utilisateur est membre
      final userTeamsResponse = await _supabase
          .from(_teamMembersTable)
          .select('team_id')
          .eq('user_id', user.id)
          .eq('status', TeamMemberStatus.active.toValue());
      
      final userTeamIds = userTeamsResponse.map<String>((json) => json['team_id'] as String).toList();
      
      if (userTeamIds.isEmpty) {
        return [];
      }
      
      // Récupérer les équipes associées à la tâche
      final teamTasksData = await _supabase
          .from(_teamTasksTable)
          .select('team_id')
          .eq('task_id', taskId);

      if (teamTasksData.isEmpty) {
        return [];
      }

      final teamIds = teamTasksData.map<String>((item) => item['team_id'] as String).toList();
      
      // Ne garder que les équipes dont l'utilisateur est membre
      final filteredTeamIds = teamIds.where((id) => userTeamIds.contains(id)).toList();
      
      if (filteredTeamIds.isEmpty) {
        return [];
      }

      final teamsData = await _supabase
          .from(_teamsTable)
          .select()
          .inFilter('id', filteredTeamIds);

      return teamsData.map<Team>((item) => Team.fromJson(item)).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des équipes associées à la tâche: $e');
      rethrow;
    }
  }

  Future<void> assignTaskToTeam(String taskId, String teamId) async {
    try {
      await _supabase
          .from(_teamTasksTable)
          .insert({
            'task_id': taskId,
            'team_id': teamId,
          });
    } catch (e) {
      // print('Erreur lors de l\'assignation de la tâche à l\'équipe: $e');
      rethrow;
    }
  }

  Future<void> removeTaskFromTeam(String taskId, String teamId) async {
    try {
      await _supabase
          .from(_teamTasksTable)
          .delete()
          .eq('task_id', taskId)
          .eq('team_id', teamId);
    } catch (e) {
      // print('Erreur lors de la suppression de l\'assignation de la tâche: $e');
      rethrow;
    }
  }

  Future<void> removeAllTeamsFromTask(String taskId) async {
    try {
      await _supabase
          .from(_teamTasksTable)
          .delete()
          .eq('task_id', taskId);
    } catch (e) {
      // print('Erreur lors de la suppression des assignations d\'équipes: $e');
      rethrow;
    }
  }

  // Invitations
  Future<List<Invitation>> getSentInvitations(String teamId) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .select('*, teams:team_id(name)')
          .eq('team_id', teamId);
      
      return response.map<Invitation>((json) {
        final teamInfo = json['teams'] as Map<String, dynamic>?;
        return Invitation.fromJson({
          ...json,
          'team_name': teamInfo?['name'],
        });
      }).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des invitations envoyées: $e');
      rethrow;
    }
  }

  Future<List<Invitation>> getReceivedInvitations() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final userEmail = user.email;
      if (userEmail == null) {
        throw Exception('Email de l\'utilisateur non disponible');
      }
      
      final response = await _supabase
          .from(_invitationsTable)
          .select('*, teams:team_id(name)')
          .eq('email', userEmail)
          .eq('status', InvitationStatus.pending.toValue());
      
      return response.map<Invitation>((json) {
        final teamInfo = json['teams'] as Map<String, dynamic>?;
        return Invitation.fromJson({
          ...json,
          'team_name': teamInfo?['name'],
        });
      }).toList();
    } catch (e) {
      // print('Erreur lors de la récupération des invitations reçues: $e');
      rethrow;
    }
  }

  Future<Invitation> createInvitation(Invitation invitation) async {
    try {
      // Vérifier si l'utilisateur a la permission d'inviter des membres
      final hasPermission = await _roleService.hasPermission(
        'invite_team_member',
        teamId: invitation.teamId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation d\'inviter des membres dans cette équipe');
      }
      
      // Générer un token d'invitation
      final token = _generateInvitationToken();
      
      // Ajouter le roleId à l'invitation (par défaut: team_member)
      String roleId;
      try {
        final roleResponse = await _supabase
            .from('roles')
            .select('id')
            .eq('name', 'team_member')
            .single();
        roleId = roleResponse['id'];
      } catch (e) {
        print('Erreur lors de la récupération du rôle: $e');
        throw Exception('Impossible de déterminer le rôle à attribuer');
      }
      
      // Créer l'invitation avec le token et le roleId
      final invitationWithDetails = invitation.copyWith(
        token: token,
        metadata: {
          'role_id': roleId,
          'role_name': 'team_member'
        }
      );
      
      final response = await _supabase
          .from(_invitationsTable)
          .insert(invitationWithDetails.toJson())
          .select()
          .single();
      
      final createdInvitation = Invitation.fromJson(response);
      
      // Envoyer un email d'invitation si le service d'email est disponible
      if (createdInvitation.email.isNotEmpty) {
        try {
          // Récupérer les informations de l'équipe
          final team = await getTeam(createdInvitation.teamId);
          
          // Récupérer les informations de l'invitation
          final inviter = await _supabase
              .from('profiles')
              .select('display_name, email')
              .eq('id', createdInvitation.invitedBy)
              .single();
          
          final inviterName = inviter['display_name'] ?? inviter['email'];
          
          // Envoyer un email d'invitation en utilisant la méthode statique sendInvitationEmail
          await EmailService.sendInvitationEmail(
            to: createdInvitation.email,
            teamName: team.name,
            inviterName: inviterName.toString(),
            token: token,
            teamId: team.id,
          );
        } catch (emailError) {
          print('Erreur lors de l\'envoi de l\'email d\'invitation: $emailError');
          // Continuer même si l'envoi de l'email échoue
        }
      }
      
      return createdInvitation;
    } catch (e) {
      print('Erreur lors de la création de l\'invitation: $e');
      rethrow;
    }
  }

  Future<Invitation> updateInvitationStatus(String invitationId, InvitationStatus status) async {
    try {
      final response = await _supabase
          .from(_invitationsTable)
          .update({'status': status.toValue()})
          .eq('id', invitationId)
          .select()
          .single();
      
      return Invitation.fromJson(response);
    } catch (e) {
      // print('Erreur lors de la mise à jour du statut de l\'invitation: $e');
      rethrow;
    }
  }

  Future<void> deleteInvitation(String invitationId) async {
    try {
      await _supabase
          .from(_invitationsTable)
          .delete()
          .eq('id', invitationId);
    } catch (e) {
      // print('Erreur lors de la suppression de l\'invitation: $e');
      rethrow;
    }
  }

  // Récupérer une invitation par son token
  Future<Invitation> getInvitationByToken(String token) async {
    try {
      // Nettoyer le token (supprimer espaces et normaliser)
      final cleanToken = token.trim();
      
      // print('Recherche de l\'invitation avec le token: "$cleanToken"');
      
      // Vérifier si le token est valide
      if (cleanToken.isEmpty) {
        throw Exception('Le token d\'invitation est vide');
      }
      
      // Afficher toutes les invitations disponibles pour le débogage
      final allInvitations = await _supabase
          .from(_invitationsTable)
          .select();
      
      // print('Nombre total d\'invitations dans la base: ${allInvitations.length}');
      
      // Afficher les détails de chaque invitation pour le débogage
      for (var inv in allInvitations) {
        final invToken = inv['token'] as String;
        // print('Invitation trouvée dans la DB: "$invToken" - Pour: ${inv['email']} - Correspond au token saisi: ${invToken == cleanToken}');
      }
      
      // On essaie d'abord une recherche par similarité pour le débogage
      final likeResults = await _supabase
          .from(_invitationsTable)
          .select()
          .ilike('token', '%${cleanToken.substring(0, math.min(8, cleanToken.length))}%');
          
      // print('Résultats similaires trouvés: ${likeResults.length}');
      
      // Rechercher l'invitation spécifique
      try {
        final response = await _supabase
            .from(_invitationsTable)
            .select('*, teams!inner(name)')
            .eq('token', cleanToken)
            .single();
        
        // print('Invitation trouvée avec succès pour le token: "$cleanToken"');
        return Invitation.fromJson(response);
      } catch (specificError) {
        // print('Erreur spécifique lors de la recherche exacte: $specificError');
        
        // Si on ne trouve pas avec la jointure, essayons sans
        final responseNoJoin = await _supabase
            .from(_invitationsTable)
            .select()
            .eq('token', cleanToken)
            .single();
            
        // print('Invitation trouvée sans jointure pour le token: "$cleanToken"');
        return Invitation.fromJson(responseNoJoin);
      }
    } catch (e) {
      // print('Erreur lors de la récupération de l\'invitation par token: $e');
      
      if (e.toString().contains('The result contains 0 rows')) {
        throw Exception('Aucune invitation trouvée avec ce code. Veuillez vérifier le code saisi ou contacter l\'administrateur.');
      }
      
      rethrow;
    }
  }

  // Accepter une invitation
  Future<void> acceptInvitation(String invitationId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Récupérer l'invitation
      final invitationResponse = await _supabase
          .from(_invitationsTable)
          .select()
          .eq('id', invitationId)
          .single();
      
      final invitation = Invitation.fromJson(invitationResponse);
      
      // Vérifier si l'invitation est expirée
      if (invitation.isExpired) {
        await updateInvitationStatus(invitationId, InvitationStatus.expired);
        throw Exception('L\'invitation a expiré');
      }
      
      // S'assurer que le profil de l'utilisateur existe
      await _ensureProfileExists(user);
      
      // Vérifier si l'utilisateur est déjà membre de l'équipe
      final memberCheck = await _supabase
          .from(_teamMembersTable)
          .select()
          .eq('team_id', invitation.teamId)
          .eq('user_id', user.id);
      
      if (memberCheck.isNotEmpty) {
        // Mettre à jour le statut de l'invitation
        await updateInvitationStatus(invitationId, InvitationStatus.accepted);
        
        // Mettre à jour le statut du membre si nécessaire
        final member = TeamMember.fromJson(memberCheck.first);
        if (member.status != TeamMemberStatus.active) {
          await updateTeamMember(member.copyWith(status: TeamMemberStatus.active));
        }
      } else {
        // Ajouter l'utilisateur comme membre de l'équipe
        await _supabase.from(_teamMembersTable).insert({
          'id': const Uuid().v4(),
          'team_id': invitation.teamId,
          'user_id': user.id,
          'role': TeamMemberRole.member.toValue(),
          'invited_by': invitation.invitedBy,
          'status': TeamMemberStatus.active.toValue(),
        });
        
        // Mettre à jour le statut de l'invitation
        await updateInvitationStatus(invitationId, InvitationStatus.accepted);
      }
    } catch (e) {
      // print('Erreur lors de l\'acceptation de l\'invitation: $e');
      rethrow;
    }
  }
  
  // Accepter une invitation directement par token
  Future<void> acceptInvitationByToken(String token) async {
    try {
      final cleanToken = token.trim();
      
      print('Tentative d\'acceptation directe par token: "$cleanToken"');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Nouvelle approche : utiliser la fonction côté serveur qui gère tout
      await _supabase.rpc('accept_team_invitation_by_token', params: {
        'p_token': cleanToken
      });
      
      print('Invitation acceptée avec succès via la fonction stored procedure');
      return; // Succès
    } catch (e) {
      print('Erreur lors de l\'acceptation de l\'invitation par token: $e');
      rethrow;
    }
  }

  // S'assurer que le profil de l'utilisateur existe
  Future<void> _ensureProfileExists(User user) async {
    try {
      // Vérifier si le profil existe déjà
      final profileCheck = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      // Si le profil n'existe pas, le créer
      if (profileCheck == null) {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('Profil créé pour l\'utilisateur: ${user.email}');
      }
    } catch (e) {
      print('Erreur lors de la vérification/création du profil: $e');
    }
  }

  // Rejeter une invitation
  Future<void> rejectInvitation(String invitationId) async {
    try {
      await updateInvitationStatus(invitationId, InvitationStatus.rejected);
    } catch (e) {
      print('Erreur lors du rejet de l\'invitation: $e');
      rethrow;
    }
  }

  // Vérifier si l'utilisateur est membre d'une équipe
  Future<bool> isTeamMember(String teamId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final response = await _supabase
          .from(_teamMembersTable)
          .select()
          .eq('team_id', teamId)
          .eq('user_id', user.id)
          .eq('status', TeamMemberStatus.active.toValue());
      
      return response.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification de l\'appartenance à l\'équipe: $e');
      return false;
    }
  }

  // Vérifier si l'utilisateur est administrateur d'une équipe
  Future<bool> isTeamAdmin(String teamId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final response = await _supabase
          .from(_teamMembersTable)
          .select()
          .eq('team_id', teamId)
          .eq('user_id', user.id)
          .eq('role', TeamMemberRole.admin.toValue())
          .eq('status', TeamMemberStatus.active.toValue());
      
      return response.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification du rôle d\'administrateur: $e');
      return false;
    }
  }
  
  // Récupère les équipes dont l'utilisateur est membre
  Future<List<Team>> getUserTeams() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final response = await _supabase
          .from(_teamMembersTable)
          .select('team_id')
          .eq('user_id', user.id)
          .eq('status', TeamMemberStatus.active.toValue());
      
      final teamIds = response.map<String>((json) => json['team_id'] as String).toList();
      
      if (teamIds.isEmpty) {
        return [];
      }
      
      final teamsResponse = await _supabase
          .from(_teamsTable)
          .select()
          .inFilter('id', teamIds)
          .order('name');
      
      return teamsResponse.map<Team>((json) => Team.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des équipes de l\'utilisateur: $e');
      rethrow;
    }
  }
  
  // Récupérer les membres d'une équipe avec leurs informations utilisateur
  Future<List<TeamMember>> getTeamMembersWithUserInfo(String teamId) async {
    try {
      // Récupérer les membres d'équipe avec plus d'informations utilisateur
      final response = await _supabase
          .from(_teamMembersTable)
          .select('*, profiles:user_id(id, email, display_name, avatar_url, bio)')
          .eq('team_id', teamId);
      
      return response.map<TeamMember>((json) {
        final userInfo = json['profiles'] as Map<String, dynamic>?;
        return TeamMember.fromJson({
          ...json,
          'user_email': userInfo?['email'],
          'user_name': userInfo?['display_name'],
        });
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des membres de l\'équipe avec informations: $e');
      rethrow;
    }
  }
  
  // Vérifier si un utilisateur peut être ajouté à une équipe
  Future<bool> canAddUserToTeam(String email, String teamId) async {
    try {
      // Vérifier si l'utilisateur existe
      final userResponse = await _supabase
          .from(_usersTable)
          .select('id')
          .eq('email', email);
      
      if (userResponse.isEmpty) {
        return false; // L'utilisateur n'existe pas
      }
      
      final userId = userResponse.first['id'] as String;
      
      // Vérifier si l'utilisateur est déjà membre de l'équipe
      final memberResponse = await _supabase
          .from(_teamMembersTable)
          .select()
          .eq('team_id', teamId)
          .eq('user_id', userId);
      
      return memberResponse.isEmpty; // Peut être ajouté si pas déjà membre
    } catch (e) {
      print('Erreur lors de la vérification de l\'ajout d\'utilisateur: $e');
      return false;
    }
  }
  
  // Obtenir les statistiques d'une équipe (nombre de membres, projets, etc.)
  Future<Map<String, dynamic>> getTeamStats(String teamId) async {
    try {
      // Nombre de membres
      final membersResponse = await _supabase
          .from(_teamMembersTable)
          .select('count(*)')
          .eq('team_id', teamId)
          .eq('status', TeamMemberStatus.active.toValue());
      
      final membersCount = membersResponse[0]['count'] as int;
      
      // Nombre de projets
      final projectsResponse = await _supabase
          .from(_teamProjectsTable)
          .select('count(*)')
          .eq('team_id', teamId);
      
      final projectsCount = projectsResponse[0]['count'] as int;
      
      // Nombre d'invitations en attente
      final invitationsResponse = await _supabase
          .from(_invitationsTable)
          .select('count(*)')
          .eq('team_id', teamId)
          .eq('status', InvitationStatus.pending.toValue());
      
      final pendingInvitationsCount = invitationsResponse[0]['count'] as int;
      
      return {
        'members_count': membersCount,
        'projects_count': projectsCount,
        'pending_invitations_count': pendingInvitationsCount,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques de l\'équipe: $e');
      rethrow;
    }
  }

  // Récupérer tous les membres uniques des équipes assignées à un projet
  Future<List<Map<String, dynamic>>> getProjectTeamMembers(String projectId) async {
    try {
      // D'abord, récupérer les IDs des équipes du projet
      final teamsResponse = await _supabase
          .from(_teamProjectsTable)
          .select('team_id')
          .eq('project_id', projectId);
      
      final teamIds = <String>[];
      for (var item in teamsResponse) {
        teamIds.add(item['team_id'] as String);
      }
      
      if (teamIds.isEmpty) {
        return [];
      }
      
      // Ensuite, récupérer tous les membres de ces équipes
      final response = await _supabase
          .from(_teamMembersTable)
          .select('*, profiles:user_id(id, email, display_name, avatar_url, bio)')
          .inFilter('team_id', teamIds);
      
      final members = <TeamMember>[];
      for (var item in response) {
        final userInfo = item['profiles'] as Map<String, dynamic>?;
        members.add(TeamMember.fromJson({
          ...item,
          'user_email': userInfo?['email'],
          'user_name': userInfo?['display_name'],
        }));
      }
      
      // Éliminer les doublons
      final uniqueUserIds = <String>{};
      final uniqueMembers = <Map<String, dynamic>>[];
      
      for (var member in members) {
        if (!uniqueUserIds.contains(member.userId)) {
          uniqueUserIds.add(member.userId);
          uniqueMembers.add({
            'id': member.userId,
            'fullName': member.userName ?? 'Utilisateur sans nom',
            'email': member.userEmail ?? 'Pas d\'email',
          });
        }
      }
      
      // Trier par nom
      uniqueMembers.sort((a, b) => (a['fullName'] as String).compareTo(b['fullName'] as String));
      
      return uniqueMembers;
    } catch (e) {
      print('Erreur lors de la récupération des membres des équipes: $e');
      rethrow;
    }
  }

  // Vérifier les équipes où l'utilisateur est administrateur
  Future<List<Team>> getUserAdminTeams(String userId) async {
    try {
      // 1. Récupérer les équipes où l'utilisateur est administrateur
      final adminTeamIdsResponse = await _supabase
          .from(_teamMembersTable)
          .select('team_id')
          .eq('user_id', userId)
          .eq('role', TeamMemberRole.admin.toValue())
          .eq('status', TeamMemberStatus.active.toValue());
      
      final adminTeamIds = adminTeamIdsResponse
          .map<String>((json) => json['team_id'] as String)
          .toList();
      
      if (adminTeamIds.isEmpty) {
        return [];
      }
      
      // 2. Récupérer les détails de ces équipes
      final teamsResponse = await _supabase
          .from(_teamsTable)
          .select()
          .inFilter('id', adminTeamIds);
      
      return teamsResponse.map<Team>((json) => Team.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des équipes d\'administration: $e');
      rethrow;
    }
  }

  // Récupérer tous les membres d'équipe pour un utilisateur
  Future<List<TeamMember>> getUserTeamMemberships(String userId) async {
    try {
      final response = await _supabase
          .from(_teamMembersTable)
          .select('*, teams:team_id(name)')
          .eq('user_id', userId);
      
      return response.map<TeamMember>((json) {
        final teamInfo = json['teams'] as Map<String, dynamic>?;
        return TeamMember.fromJson({
          ...json,
          'team_name': teamInfo?['name'],
        });
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des membres d\'équipe pour l\'utilisateur: $e');
      rethrow;
    }
  }

  // Utilitaires
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Méthode pour notifier que le projet a été ajouté à l'équipe
  Future<void> _notifyProjectAddedToTeam(Team team, Project project) async {
    try {
      // Récupérer tous les membres de l'équipe
      final teamMembers = await getTeamMembers(team.id);
      
      // Envoyer une notification à chaque membre de l'équipe
      for (final member in teamMembers) {
        await _notificationService.createProjectAddedToTeamNotification(
          projectId: project.id,
          projectName: project.name,
          teamId: team.id,
          teamName: team.name,
          userId: member.userId,
        );
      }
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications aux membres: $e');
    }
  }

  // Méthode pour générer un token d'invitation aléatoire
  String _generateInvitationToken() {
    // Génération d'un token simple pour les invitations
    // Utilisez des caractères alphanumériques aléatoires pour un token de 24 caractères
    final random = DateTime.now().millisecondsSinceEpoch.toString() + 
                  DateTime.now().microsecondsSinceEpoch.toString();
    return random.substring(0, 24);
  }

  // Récupère le profil d'un utilisateur par son ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Erreur lors de la récupération du profil utilisateur: $e');
      return null;
    }
  }
}
