import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/phase_model.dart';
import '../services/notification_service.dart';
import '../services/project_service.dart';

class PhaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();

  // Récupère toutes les phases
  Future<List<Phase>> getAllPhases() async {
    try {
      final response = await _supabase
          .from('phases')
          .select('*, projects:project_id(name)')
          .order('order_index');

      return response.map<Phase>((json) {
        // Récupérer le nom du projet à partir de la jointure
        final projectName = json['projects'] != null ? json['projects']['name'] : null;
        
        // Créer une copie du json pour éviter de modifier l'original
        final phaseJson = Map<String, dynamic>.from(json);
        
        // Ajouter le nom du projet au json de la phase
        phaseJson['project_name'] = projectName;
        
        return Phase.fromJson(phaseJson);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases: $e');
      return [];
    }
  }

  // Récupère les phases d'un projet spécifique
  Future<List<Phase>> getPhasesByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('phases')
          .select('*, projects:project_id(name)')
          .eq('project_id', projectId)
          .order('order_index');

      return response.map<Phase>((json) {
        // Récupérer le nom du projet à partir de la jointure
        final projectName = json['projects'] != null ? json['projects']['name'] : null;
        
        // Créer une copie du json pour éviter de modifier l'original
        final phaseJson = Map<String, dynamic>.from(json);
        
        // Ajouter le nom du projet au json de la phase
        phaseJson['project_name'] = projectName;
        
        return Phase.fromJson(phaseJson);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases du projet: $e');
      return [];
    }
  }

  // Récupère une phase spécifique par son ID
  Future<Phase?> getPhaseById(String phaseId) async {
    try {
      final response = await _supabase
          .from('phases')
          .select('*, projects:project_id(name)')
          .eq('id', phaseId)
          .single();

      // Récupérer le nom du projet à partir de la jointure
      final projectName = response['projects'] != null ? response['projects']['name'] : null;
      
      // Créer une copie du json pour éviter de modifier l'original
      final phaseJson = Map<String, dynamic>.from(response);
      
      // Ajouter le nom du projet au json de la phase
      phaseJson['project_name'] = projectName;

      return Phase.fromJson(phaseJson);
    } catch (e) {
      print('Erreur lors de la récupération de la phase: $e');
      return null;
    }
  }

  // Crée une nouvelle phase
  Future<Phase?> createPhase(Phase phase) async {
    try {
      // Déterminer l'index d'ordre pour la nouvelle phase
      int orderIndex = 0;
      final existingPhases = await getPhasesByProject(phase.projectId);
      if (existingPhases.isNotEmpty) {
        // Trouver le plus grand index et ajouter 1
        orderIndex = existingPhases
            .map((p) => p.orderIndex ?? 0)
            .reduce((max, index) => index > max ? index : max) + 1;
      }

      // Ajouter l'index d'ordre à la phase
      final phaseJson = phase.toJson();
      phaseJson['order_index'] = orderIndex;

      final response = await _supabase
          .from('phases')
          .insert(phaseJson)
          .select()
          .single();

      final createdPhase = Phase.fromJson(response);
      
      // Envoyer une notification pour la création de phase
      await _notifyPhaseCreation(createdPhase);
      
      return createdPhase;
    } catch (e) {
      print('Erreur lors de la création de la phase: $e');
      return null;
    }
  }

  // Met à jour une phase existante
  Future<Phase?> updatePhase(Phase phase) async {
    try {
      // Récupérer l'ancienne phase pour comparer le statut
      final oldPhase = await getPhaseById(phase.id);
      
      final response = await _supabase
          .from('phases')
          .update(phase.toJson())
          .eq('id', phase.id)
          .select()
          .single();

      final updatedPhase = Phase.fromJson(response);
      
      // Vérifier si le statut a changé
      if (oldPhase != null && oldPhase.status != updatedPhase.status) {
        // Envoyer une notification pour le changement de statut
        await _notifyPhaseStatusChange(updatedPhase);
      }
      
      return updatedPhase;
    } catch (e) {
      print('Erreur lors de la mise à jour de la phase: $e');
      return null;
    }
  }

  // Supprime une phase
  Future<bool> deletePhase(String phaseId) async {
    try {
      await _supabase.from('phases').delete().eq('id', phaseId);
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de la phase: $e');
      return false;
    }
  }

  // Réorganise les phases d'un projet
  Future<bool> reorderPhases(String projectId, List<String> phaseIds) async {
    try {
      final batch = phaseIds.asMap().entries.map((entry) {
        final index = entry.key;
        final phaseId = entry.value;
        return {
          'id': phaseId,
          'order_index': index,
        };
      }).toList();

      await _supabase.from('phases').upsert(batch);
      return true;
    } catch (e) {
      print('Erreur lors de la réorganisation des phases: $e');
      return false;
    }
  }

  // Met à jour le budget alloué et consommé d'une phase
  Future<bool> updatePhaseBudget(String phaseId, double? budgetAllocated, double? budgetConsumed) async {
    try {
      await _supabase
          .from('phases')
          .update({
            'budget_allocated': budgetAllocated,
            'budget_consumed': budgetConsumed,
          })
          .eq('id', phaseId);
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget de la phase: $e');
      return false;
    }
  }

  // Méthodes privées pour les notifications
  
  // Envoie des notifications pour la création d'une phase
  Future<void> _notifyPhaseCreation(Phase phase) async {
    try {
      // Récupérer le nom du projet
      String projectName = phase.projectName ?? '';
      if (projectName.isEmpty) {
        final project = await _supabase
            .from('projects')
            .select('name')
            .eq('id', phase.projectId)
            .single();
        projectName = project['name'] as String;
      }
      
      // Récupérer les membres de l'équipe du projet
      final teamMembers = await _projectService.getProjectTeamMembers(phase.projectId);
      
      // Créer les notifications
      await _notificationService.createPhaseNotification(
        phase.id,
        phase.name,
        projectName,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications de création de phase: $e');
    }
  }
  
  // Envoie des notifications pour un changement de statut de phase
  Future<void> _notifyPhaseStatusChange(Phase phase) async {
    try {
      // Récupérer le nom du projet
      String projectName = phase.projectName ?? '';
      if (projectName.isEmpty) {
        final project = await _supabase
            .from('projects')
            .select('name')
            .eq('id', phase.projectId)
            .single();
        projectName = project['name'] as String;
      }
      
      // Récupérer les membres de l'équipe du projet
      final teamMembers = await _projectService.getProjectTeamMembers(phase.projectId);
      
      // Créer les notifications
      await _notificationService.createPhaseStatusNotification(
        phase.id,
        phase.name,
        projectName,
        phase.status,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications de changement de statut de phase: $e');
    }
  }
}
