import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/phase_model.dart';
import '../notification_service.dart';
import '../project_service/project_service.dart';

class PhaseService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();

  // Récupérer toutes les phases d'un projet
  Future<List<Phase>> getPhasesByProject(String projectId) async {
    try {
      print('Début de récupération des phases pour le projet: $projectId');
      
      final response = await _supabase
          .from('phases')
          .select()
          .eq('project_id', projectId)
          .filter('parent_phase_id', 'is', null)  // Récupérer uniquement les phases principales
          .order('order_index', ascending: true);

      print('Réponse brute de la base de données: $response');
      
      final phases = response.map<Phase>((json) => Phase.fromJson(json)).toList();
      print('Phases récupérées: ${phases.length} - IDs: ${phases.map((p) => p.id).join(', ')}');
      
      return phases;
    } catch (e) {
      print('Erreur lors de la récupération des phases: $e');
      rethrow;
    }
  }

  // Récupérer une phase par son ID
  Future<Phase> getPhaseById(String phaseId) async {
    try {
      final response = await _supabase
          .from('phases')
          .select()
          .eq('id', phaseId)
          .single();

      return Phase.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la phase: $e');
      rethrow;
    }
  }

  // Récupérer toutes les sous-phases d'une phase principale
  Future<List<Phase>> getSubPhasesByParentId(String parentPhaseId) async {
    try {
      final response = await _supabase
          .from('phases')
          .select()
          .eq('parent_phase_id', parentPhaseId)
          .order('order_index', ascending: true);

      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des sous-phases: $e');
      return []; // Retourner une liste vide en cas d'erreur au lieu de propager l'exception
    }
  }

  // Récupérer toutes les phases et sous-phases d'un projet (structure plate)
  Future<List<Phase>> getAllPhasesAndSubPhases(String projectId) async {
    try {
      final response = await _supabase
          .from('phases')
          .select()
          .eq('project_id', projectId)
          .order('parent_phase_id', ascending: true, nullsFirst: true) // Phases principales d'abord
          .order('order_index', ascending: true);

      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases et sous-phases: $e');
      rethrow;
    }
  }

  // Créer une nouvelle phase
  Future<Phase> createPhase(
      String projectId,
      String name,
      String description,
      int orderIndex,
      ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final phaseId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final phase = Phase(
        id: phaseId,
        projectId: projectId,
        name: name,
        description: description,
        createdAt: now,
        createdBy: userId,
        orderIndex: orderIndex,
        status: PhaseStatus.notStarted.toValue(),
        parentPhaseId: null, // S'assurer qu'il s'agit d'une phase principale
      );

      await _supabase.from('phases').insert(phase.toJson());

      // Envoyer une notification pour la création de la phase
      await _notifyPhaseCreation(phase);

      return phase;
    } catch (e) {
      print('Erreur lors de la création de la phase: $e');
      rethrow;
    }
  }

  // Créer une nouvelle sous-phase
  Future<Phase> createSubPhase(
      String parentPhaseId,
      String name,
      String description,
      {String? status}
      ) async {
    try {
      // Récupérer la phase parente pour obtenir le projectId et calculer l'ordre
      final parentPhase = await getPhaseById(parentPhaseId);
      final projectId = parentPhase.projectId;

      // Récupérer le nombre de sous-phases existantes pour déterminer l'ordre
      final existingSubPhases = await getSubPhasesByParentId(parentPhaseId);
      final orderIndex = existingSubPhases.length;

      final userId = _supabase.auth.currentUser!.id;
      final phaseId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final subPhase = Phase(
        id: phaseId,
        projectId: projectId,
        name: name,
        description: description,
        createdAt: now,
        createdBy: userId,
        orderIndex: orderIndex,
        status: status ?? PhaseStatus.notStarted.toValue(),
        parentPhaseId: parentPhaseId,
      );

      await _supabase.from('phases').insert(subPhase.toJson());

      // Envoyer une notification pour la création de la sous-phase
      await _notifyPhaseCreation(subPhase);

      return subPhase;
    } catch (e) {
      print('Erreur lors de la création de la sous-phase: $e');
      rethrow;
    }
  }

  // Mettre à jour une phase
  Future<void> updatePhase(Phase phase) async {
    try {
      // Récupérer l'ancienne phase pour comparer
      Phase? oldPhase;
      try {
        oldPhase = await getPhaseById(phase.id);
      } catch (e) {
        print('Impossible de récupérer l\'ancienne phase: $e');
      }

      final updatedPhase = phase.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('phases')
          .update(updatedPhase.toJson())
          .eq('id', phase.id);

      // Vérifier si le statut a changé
      if (oldPhase != null && oldPhase.status != updatedPhase.status) {
        await _notifyPhaseStatusChange(updatedPhase);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de la phase: $e');
      rethrow;
    }
  }

  // Supprimer une phase et ses dépendances
  Future<void> deletePhase(String phaseId) async {
    try {
      // Récupérer les informations de la phase avant de la supprimer
      final phaseInfo = await _supabase
          .from('phases')
          .select('project_id, parent_phase_id')
          .eq('id', phaseId)
          .maybeSingle();
      
      if (phaseInfo == null) {
        print('Phase $phaseId déjà supprimée ou inexistante');
        return;
      }
      
      final projectId = phaseInfo['project_id'];
      final parentPhaseId = phaseInfo['parent_phase_id'];
      
      // Récupérer toutes les sous-phases avant suppression
      final subPhases = await getSubPhasesByParentId(phaseId);
      
      // Stocker l'ID de la phase et toutes les sous-phases
      final allPhaseIds = [phaseId, ...subPhases.map((p) => p.id)];
      
      // 1. Mettre à jour les tâches associées à la phase et sous-phases (phaseId = null)
      if (allPhaseIds.isNotEmpty) {
        await _supabase
            .from('tasks')
            .update({'phase_id': null})
            .filter('phase_id', 'in', allPhaseIds);
      }
      
      // 2. Supprimer d'abord toutes les sous-phases
      if (subPhases.isNotEmpty) {
        await _supabase
            .from('phases')
            .delete()
            .eq('parent_phase_id', phaseId);
      }
      
      // 3. Supprimer la phase principale
      final result = await _supabase
          .from('phases')
          .delete()
          .eq('id', phaseId)
          .select();
      
      print('Résultat de la suppression: $result');
      
      // 4. Réindexer les phases restantes du même projet
      await _reindexRemainingPhases(projectId, parentPhaseId);
    } catch (e) {
      print('Erreur lors de la suppression de la phase: $e');
      rethrow;
    }
  }

  // Réindexer les phases après suppression
  Future<void> _reindexRemainingPhases(String projectId, dynamic parentPhaseId) async {
    try {
      print('Réindexation des phases du projet $projectId avec parent $parentPhaseId');
      
      // Récupérer les phases restantes du même niveau (même projet et même parent)
      final List<dynamic> remainingPhases = await _supabase
          .from('phases')
          .select('id, order_index')
          .eq('project_id', projectId)
          .filter('parent_phase_id', parentPhaseId == null ? 'is' : 'eq', 
              parentPhaseId == null ? null : parentPhaseId)
          .order('order_index', ascending: true);
      
      print('Phases restantes à réindexer: ${remainingPhases.length}');
      
      // Mettre à jour les indices
      for (int i = 0; i < remainingPhases.length; i++) {
        await _supabase
            .from('phases')
            .update({'order_index': i})
            .eq('id', remainingPhases[i]['id']);
      }
      
    } catch (e) {
      print('Erreur lors de la réindexation des phases: $e');
      // Ne pas propager l'erreur pour ne pas bloquer la suppression
    }
  }
  
  // Réordonner les phases
  Future<void> reorderPhases(List<Phase> phases) async {
    try {
      for (int i = 0; i < phases.length; i++) {
        final phase = phases[i];
        await _supabase
            .from('phases')
            .update({'order_index': i})
            .eq('id', phase.id);
      }
    } catch (e) {
      print('Erreur lors de la réorganisation des phases: $e');
      rethrow;
    }
  }

  // Réordonner les sous-phases
  Future<void> reorderSubPhases(List<Phase> subPhases) async {
    try {
      // Vérifier que toutes les phases ont le même parent
      if (subPhases.isNotEmpty) {
        final parentId = subPhases.first.parentPhaseId;
        if (subPhases.any((phase) => phase.parentPhaseId != parentId)) {
          throw Exception('Toutes les sous-phases doivent avoir le même parent');
        }
      }

      for (int i = 0; i < subPhases.length; i++) {
        final subPhase = subPhases[i];
        await _supabase
            .from('phases')
            .update({'order_index': i})
            .eq('id', subPhase.id);
      }
    } catch (e) {
      print('Erreur lors de la réorganisation des sous-phases: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget alloué d'une phase
  Future<Phase> updatePhaseBudgetAllocation(String phaseId, double amount) async {
    try {
      // Récupérer la phase actuelle
      final phase = await getPhaseById(phaseId);

      // Calculer le nouveau montant alloué
      final double newBudgetAllocated = (phase.budgetAllocated ?? 0) + amount;

      // Mettre à jour la phase
      final updatedPhase = phase.copyWith(
        budgetAllocated: newBudgetAllocated,
        updatedAt: DateTime.now().toUtc(),
      );

      await updatePhase(updatedPhase);
      return updatedPhase;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget alloué de la phase: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget consommé d'une phase
  Future<Phase> updatePhaseBudgetConsumption(String phaseId, double amount) async {
    try {
      // Récupérer la phase actuelle
      final phase = await getPhaseById(phaseId);

      // Calculer le nouveau montant consommé
      final double newBudgetConsumed = (phase.budgetConsumed ?? 0) + amount;

      // Mettre à jour la phase
      final updatedPhase = phase.copyWith(
        budgetConsumed: newBudgetConsumed,
        updatedAt: DateTime.now().toUtc(),
      );

      await updatePhase(updatedPhase);
      return updatedPhase;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget consommé de la phase: $e');
      rethrow;
    }
  }

  // Définir un budget spécifique pour une phase
  Future<Phase> setPhaseSpecificBudget(String phaseId, double budgetAmount) async {
    try {
      // Récupérer la phase actuelle
      final phase = await getPhaseById(phaseId);

      // Mettre à jour la phase avec le nouveau budget alloué
      final updatedPhase = phase.copyWith(
        budgetAllocated: budgetAmount,
        updatedAt: DateTime.now().toUtc(),
      );

      await updatePhase(updatedPhase);
      return updatedPhase;
    } catch (e) {
      print('Erreur lors de la définition du budget spécifique de la phase: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques budgétaires d'une phase
  Future<Map<String, dynamic>> getPhaseBudgetStatistics(String phaseId) async {
    try {
      // Récupérer la phase
      final phase = await getPhaseById(phaseId);

      // Récupérer les tâches de la phase pour calculer le budget alloué et consommé par tâche
      final tasks = await _supabase
          .from('tasks')
          .select()
          .eq('phase_id', phaseId)
          .order('priority', ascending: false);

      double tasksBudgetAllocated = 0;
      double tasksBudgetConsumed = 0;

      for (var task in tasks) {
        tasksBudgetAllocated += (task['budget_allocated'] ?? 0).toDouble();
        tasksBudgetConsumed += (task['budget_consumed'] ?? 0).toDouble();
      }

      // Calculer le pourcentage d'utilisation
      double budgetUsagePercentage = 0;
      if (phase.budgetAllocated != null && phase.budgetAllocated! > 0) {
        budgetUsagePercentage = ((phase.budgetConsumed ?? 0) / phase.budgetAllocated!) * 100;
      }

      return {
        'phase_id': phaseId,
        'phase_name': phase.name,
        'project_id': phase.projectId,
        'budget_allocated': phase.budgetAllocated ?? 0,
        'budget_consumed': phase.budgetConsumed ?? 0,
        'budget_remaining': (phase.budgetAllocated ?? 0) - (phase.budgetConsumed ?? 0),
        'budget_usage_percentage': budgetUsagePercentage,
        'tasks_budget_allocated': tasksBudgetAllocated,
        'tasks_budget_consumed': tasksBudgetConsumed,
        'is_budget_overrun': (phase.budgetConsumed ?? 0) > (phase.budgetAllocated ?? 0),
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques budgétaires de la phase: $e');
      rethrow;
    }
  }

  // Redistribuer le budget du projet entre les phases
  Future<List<Phase>> redistributeProjectBudget(
      String projectId,
      Map<String, double> phaseAllocations
      ) async {
    try {
      // Récupérer toutes les phases du projet
      final phases = await getPhasesByProject(projectId);
      List<Phase> updatedPhases = [];

      // Mettre à jour chaque phase avec sa nouvelle allocation
      for (var phase in phases) {
        if (phaseAllocations.containsKey(phase.id)) {
          final updatedPhase = await setPhaseSpecificBudget(
              phase.id,
              phaseAllocations[phase.id]!
          );
          updatedPhases.add(updatedPhase);
        } else {
          updatedPhases.add(phase);
        }
      }

      return updatedPhases;
    } catch (e) {
      print('Erreur lors de la redistribution du budget entre les phases: $e');
      rethrow;
    }
  }

  // Méthodes privées pour les notifications

  // Envoyer des notifications pour la création d'une phase
  Future<void> _notifyPhaseCreation(Phase phase) async {
    try {
      // Récupérer le nom du projet
      final projectResponse = await _supabase
          .from('projects')
          .select('name')
          .eq('id', phase.projectId)
          .single();

      final projectName = projectResponse['name'] as String;

      // Récupérer les membres du projet
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

  // Envoyer des notifications pour un changement de statut de phase
  Future<void> _notifyPhaseStatusChange(Phase phase) async {
    try {
      // Récupérer le nom du projet
      final projectResponse = await _supabase
          .from('projects')
          .select('name')
          .eq('id', phase.projectId)
          .single();

      final projectName = projectResponse['name'] as String;

      // Récupérer les membres du projet
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
