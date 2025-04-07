import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_model.dart';
import '../services/notification_service.dart';

class ProjectService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  // Récupère tous les projets
  Future<List<Project>> getProjects() async {
    try {
      final response = await _supabase
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets: $e');
      return [];
    }
  }

  // Récupère un projet spécifique par son ID
  Future<Project?> getProjectById(String projectId) async {
    try {
      final response = await _supabase
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du projet: $e');
      return null;
    }
  }

  // Crée un nouveau projet
  Future<Project?> createProject(Project project) async {
    try {
      final response = await _supabase
          .from('projects')
          .insert(project.toJson())
          .select()
          .single();

      final createdProject = Project.fromJson(response);
      
      // Récupérer les membres de l'équipe pour envoyer des notifications
      await _notifyTeamMembers(createdProject.id, createdProject.name);
      
      return createdProject;
    } catch (e) {
      print('Erreur lors de la création du projet: $e');
      return null;
    }
  }

  // Met à jour un projet existant
  Future<Project?> updateProject(Project project) async {
    try {
      // Récupérer l'ancien projet pour comparer le statut
      final oldProject = await getProjectById(project.id);
      
      final response = await _supabase
          .from('projects')
          .update(project.toJson())
          .eq('id', project.id)
          .select()
          .single();

      final updatedProject = Project.fromJson(response);
      
      // Vérifier si le statut a changé
      if (oldProject != null && oldProject.status != updatedProject.status) {
        // Si le statut est terminé, en attente ou annulé, envoyer une notification
        if (updatedProject.status == 'completed' || 
            updatedProject.status == 'onHold' || 
            updatedProject.status == 'cancelled') {
          await _notifyProjectStatusChange(updatedProject.id, updatedProject.name, updatedProject.status);
        }
      }
      
      // Vérifier le budget
      if (updatedProject.budgetAllocated != null && 
          updatedProject.budgetAllocated! > 0 && 
          updatedProject.budgetConsumed != null) {
        final percentage = (updatedProject.budgetConsumed! / updatedProject.budgetAllocated!) * 100;
        
        // Envoyer des notifications à 70%, 90% et 100%
        if (percentage >= 70) {
          await _notifyProjectBudgetAlert(updatedProject.id, updatedProject.name, percentage);
        }
      }
      
      return updatedProject;
    } catch (e) {
      print('Erreur lors de la mise à jour du projet: $e');
      return null;
    }
  }

  // Supprime un projet
  Future<bool> deleteProject(String projectId) async {
    try {
      await _supabase
          .from('projects')
          .delete()
          .eq('id', projectId);
          
      return true;
    } catch (e) {
      print('Erreur lors de la suppression du projet: $e');
      return false;
    }
  }
  
  // Récupérer les membres d'un projet
  Future<List<String>> getProjectTeamMembers(String projectId) async {
    try {
      // Récupérer les équipes associées au projet
      final teamsResponse = await _supabase
          .from('team_projects')
          .select('team_id')
          .eq('project_id', projectId);
      
      // Si aucune équipe n'est associée, retourner uniquement le créateur
      if (teamsResponse.isEmpty) {
        final projectResponse = await _supabase
            .from('projects')
            .select('created_by')
            .eq('id', projectId)
            .single();
        
        return [projectResponse['created_by']];
      }
      
      // Pour chaque équipe, récupérer les membres
      final List<String> allTeamMembers = [];
      
      for (final team in teamsResponse) {
        final teamId = team['team_id'];
        final teamMembersResponse = await _supabase
            .from('team_members')
            .select('user_id')
            .eq('team_id', teamId)
            .eq('status', 'active');
        
        for (final member in teamMembersResponse) {
          allTeamMembers.add(member['user_id']);
        }
      }
      
      // Ajouter également le créateur du projet s'il n'est pas déjà inclus
      final projectResponse = await _supabase
          .from('projects')
          .select('created_by')
          .eq('id', projectId)
          .single();
      
      final creatorId = projectResponse['created_by'];
      if (!allTeamMembers.contains(creatorId)) {
        allTeamMembers.add(creatorId);
      }
      
      return allTeamMembers;
    } catch (e) {
      print('Erreur lors de la récupération des membres du projet: $e');
      return [];
    }
  }

  // Récupère les projets créés par l'utilisateur actuel
  Future<List<Project>> getProjectsByUser() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('projects')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets de l\'utilisateur: $e');
      return [];
    }
  }

  // Récupère tous les projets, y compris ceux où l'utilisateur est collaborateur
  Future<List<Project>> getAllProjects() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Récupérer les projets où l'utilisateur est soit créateur, soit membre de l'équipe
      final response = await _supabase
          .from('projects')
          .select()
          .or('created_by.eq.$userId,team_members.cs.{$userId}')
          .order('created_at', ascending: false);

      return response.map<Project>((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de tous les projets: $e');
      return [];
    }
  }

  // Met à jour le budget alloué et consommé d'un projet
  Future<bool> updateProjectBudget(String projectId, double? budgetAllocated, double? budgetConsumed) async {
    try {
      await _supabase
          .from('projects')
          .update({
            'budget_allocated': budgetAllocated,
            'budget_consumed': budgetConsumed,
          })
          .eq('id', projectId);
      
      // Vérifier le budget après la mise à jour
      if (budgetAllocated != null && budgetAllocated > 0 && budgetConsumed != null) {
        final percentage = (budgetConsumed / budgetAllocated) * 100;
        final project = await getProjectById(projectId);
        
        // Envoyer des notifications à 70%, 90% et 100%
        if (percentage >= 70 && project != null) {
          await _notifyProjectBudgetAlert(projectId, project.name, percentage);
        }
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget du projet: $e');
      return false;
    }
  }
  
  // Méthodes privées pour les notifications
  
  // Récupère les membres de l'équipe d'un projet et envoie des notifications
  Future<void> _notifyTeamMembers(String projectId, String projectName) async {
    try {
      // Récupérer tous les membres associés au projet
      final response = await _supabase
          .from('team_projects')
          .select('team_id')
          .eq('project_id', projectId);
      
      if (response.isEmpty) {
        final creatorId = _supabase.auth.currentUser!.id;
        // Notifier seulement le créateur si aucune équipe n'est associée
        await _notificationService.createProjectNotification(
          projectId,
          projectName,
          [creatorId],
        );
        return;
      }
      
      // Pour chaque équipe, récupérer les membres
      final List<String> allTeamMembers = [];
      
      for (final item in response) {
        final teamId = item['team_id'] as String;
        final teamMembers = await _supabase
            .from('team_members')
            .select('user_id')
            .eq('team_id', teamId);
        
        allTeamMembers.addAll(teamMembers.map((m) => m['user_id'] as String));
      }
      
      // Ajouter aussi le créateur du projet
      final creatorId = _supabase.auth.currentUser!.id;
      if (!allTeamMembers.contains(creatorId)) {
        allTeamMembers.add(creatorId);
      }
      
      // Enlever les doublons
      final uniqueMembers = allTeamMembers.toSet().toList();
      
      // Créer les notifications
      await _notificationService.createProjectNotification(
        projectId,
        projectName,
        uniqueMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications aux membres de l\'équipe: $e');
    }
  }
  
  // Envoie des notifications pour un changement de statut de projet
  Future<void> _notifyProjectStatusChange(String projectId, String projectName, String status) async {
    try {
      // Récupérer les membres associés au projet
      final List<String> teamMembers = await _getProjectTeamMembers(projectId);
      
      // Créer les notifications
      await _notificationService.createProjectStatusNotification(
        projectId,
        projectName,
        status,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications de changement de statut: $e');
    }
  }
  
  // Envoie des notifications pour une alerte de budget
  Future<void> _notifyProjectBudgetAlert(String projectId, String projectName, double percentage) async {
    try {
      // Récupérer les membres associés au projet
      final List<String> teamMembers = await _getProjectTeamMembers(projectId);
      
      // Créer les notifications
      await _notificationService.createProjectBudgetAlert(
        projectId,
        projectName,
        percentage,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications d\'alerte de budget: $e');
    }
  }
  
  // Récupère tous les membres d'un projet
  Future<List<String>> _getProjectTeamMembers(String projectId) async {
    try {
      // Récupérer toutes les équipes associées au projet
      final teamsResponse = await _supabase
          .from('team_projects')
          .select('team_id')
          .eq('project_id', projectId);
      
      if (teamsResponse.isEmpty) {
        // Si aucune équipe n'est associée, retourner seulement le créateur
        final projectResponse = await _supabase
            .from('projects')
            .select('created_by')
            .eq('id', projectId)
            .single();
        
        return [projectResponse['created_by'] as String];
      }
      
      // Pour chaque équipe, récupérer les membres
      final List<String> allTeamMembers = [];
      
      for (final item in teamsResponse) {
        final teamId = item['team_id'] as String;
        final teamMembers = await _supabase
            .from('team_members')
            .select('user_id')
            .eq('team_id', teamId);
        
        allTeamMembers.addAll(teamMembers.map((m) => m['user_id'] as String));
      }
      
      // Ajouter aussi le créateur du projet
      final projectResponse = await _supabase
          .from('projects')
          .select('created_by')
          .eq('id', projectId)
          .single();
      
      final creatorId = projectResponse['created_by'] as String;
      if (!allTeamMembers.contains(creatorId)) {
        allTeamMembers.add(creatorId);
      }
      
      // Enlever les doublons
      return allTeamMembers.toSet().toList();
    } catch (e) {
      print('Erreur lors de la récupération des membres du projet: $e');
      return [];
    }
  }
}
