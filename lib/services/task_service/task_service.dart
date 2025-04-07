import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../notification_service.dart';
import '../project_service/project_service.dart';

class TaskService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();

  // Récupérer toutes les tâches d'un projet
  Future<List<Task>> getTasksByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('project_id', projectId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches du projet: $e');
      rethrow;
    }
  }

  // Récupérer toutes les tâches d'une phase
  Future<List<Task>> getTasksByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('phase_id', phaseId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de la phase: $e');
      rethrow;
    }
  }

  // Récupérer les tâches assignées à un utilisateur
  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('assigned_to', userId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return response.map<Task>((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer une tâche par son ID
  Future<Task> getTaskById(String taskId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('id', taskId)
          .single();

      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la tâche: $e');
      rethrow;
    }
  }

  // Créer une nouvelle tâche
  Future<Task> createTask({
    required String projectId,
    String? phaseId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? assignedTo,
    required String status,
    required int priority,
    double? budgetAllocated,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final taskId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final task = Task(
        id: taskId,
        projectId: projectId,
        phaseId: phaseId,
        title: title,
        description: description,
        createdAt: now,
        dueDate: dueDate,
        assignedTo: assignedTo,
        createdBy: userId,
        status: status,
        priority: priority,
        budgetAllocated: budgetAllocated,
        budgetConsumed: 0,
      );

      await _supabase.from('tasks').insert(task.toJson());
      
      // Si la tâche est assignée à quelqu'un, envoyer une notification
      if (assignedTo != null && assignedTo.isNotEmpty) {
        await _notifyTaskAssigned(task);
      }
      
      return task;
    } catch (e) {
      print('Erreur lors de la création de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour une tâche
  Future<void> updateTask(Task task) async {
    try {
      // Récupérer l'ancienne tâche pour comparer
      Task? oldTask;
      try {
        oldTask = await getTaskById(task.id);
      } catch (e) {
        print('Impossible de récupérer l\'ancienne tâche: $e');
      }
      
      final updatedTask = task.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('tasks')
          .update(updatedTask.toJson())
          .eq('id', task.id);
      
      if (oldTask != null) {
        // Vérifier si le statut a changé
        if (oldTask.status != updatedTask.status) {
          await _notifyTaskStatusChange(updatedTask, _supabase.auth.currentUser!.id);
        }
        
        // Vérifier si l'assignation a changé
        if (oldTask.assignedTo != updatedTask.assignedTo && updatedTask.assignedTo != null && updatedTask.assignedTo!.isNotEmpty) {
          await _notifyTaskAssigned(updatedTask);
        }
        
        // Vérifier si la date d'échéance est proche
        if (oldTask.dueDate != updatedTask.dueDate && updatedTask.dueDate != null) {
          await _checkTaskDueDate(updatedTask);
        }
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de la tâche: $e');
      rethrow;
    }
  }

  // Supprimer une tâche
  Future<void> deleteTask(String taskId) async {
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      print('Erreur lors de la suppression de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget alloué d'une tâche
  Future<Task> updateTaskBudgetAllocation(String taskId, double amount) async {
    try {
      // Récupérer la tâche actuelle
      final task = await getTaskById(taskId);
      
      // Calculer le nouveau montant alloué
      final double newBudgetAllocated = (task.budgetAllocated ?? 0) + amount;
      
      // Mettre à jour la tâche
      final updatedTask = task.copyWith(
        budgetAllocated: newBudgetAllocated,
        updatedAt: DateTime.now().toUtc(),
      );
      
      await updateTask(updatedTask);
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget alloué de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget consommé d'une tâche
  Future<Task> updateTaskBudgetConsumption(String taskId, double amount) async {
    try {
      // Récupérer la tâche actuelle
      final task = await getTaskById(taskId);
      
      // Calculer le nouveau montant consommé
      final double newBudgetConsumed = (task.budgetConsumed ?? 0) + amount;
      
      // Mettre à jour la tâche
      final updatedTask = task.copyWith(
        budgetConsumed: newBudgetConsumed,
        updatedAt: DateTime.now().toUtc(),
      );
      
      await updateTask(updatedTask);
      
      // Si la tâche appartient à une phase, mettre à jour le budget consommé de la phase
      if (task.phaseId != null) {
        await _supabase.rpc('update_phase_budget_consumption', params: {
          'p_phase_id': task.phaseId,
          'p_amount': amount,
        });
      }
      
      // Mettre à jour le budget consommé du projet
      await _supabase.rpc('update_project_budget_consumption', params: {
        'p_project_id': task.projectId,
        'p_amount': amount,
      });
      
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget consommé de la tâche: $e');
      rethrow;
    }
  }

  // Définir un budget spécifique pour une tâche
  Future<Task> setTaskSpecificBudget(String taskId, double budgetAmount) async {
    try {
      // Récupérer la tâche actuelle
      final task = await getTaskById(taskId);
      
      // Mettre à jour la tâche avec le nouveau budget alloué
      final updatedTask = task.copyWith(
        budgetAllocated: budgetAmount,
        updatedAt: DateTime.now().toUtc(),
      );
      
      await updateTask(updatedTask);
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la définition du budget spécifique de la tâche: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques budgétaires d'une tâche
  Future<Map<String, dynamic>> getTaskBudgetStatistics(String taskId) async {
    try {
      // Récupérer la tâche
      final task = await getTaskById(taskId);
      
      // Calculer le pourcentage d'utilisation
      double budgetUsagePercentage = 0;
      if (task.budgetAllocated != null && task.budgetAllocated! > 0) {
        budgetUsagePercentage = ((task.budgetConsumed ?? 0) / task.budgetAllocated!) * 100;
      }
      
      return {
        'task_id': taskId,
        'task_title': task.title,
        'project_id': task.projectId,
        'phase_id': task.phaseId,
        'budget_allocated': task.budgetAllocated ?? 0,
        'budget_consumed': task.budgetConsumed ?? 0,
        'budget_remaining': (task.budgetAllocated ?? 0) - (task.budgetConsumed ?? 0),
        'budget_usage_percentage': budgetUsagePercentage,
        'is_budget_overrun': (task.budgetConsumed ?? 0) > (task.budgetAllocated ?? 0),
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques budgétaires de la tâche: $e');
      rethrow;
    }
  }

  // Enregistrer une dépense sur une tâche
  Future<void> recordTaskExpense(
    String taskId,
    double amount,
    String description,
    String category,
    String? subcategory,
    DateTime transactionDate,
  ) async {
    try {
      // Mettre à jour le budget consommé de la tâche
      await updateTaskBudgetConsumption(taskId, amount);
      
      // Récupérer la tâche pour obtenir le projectId et phaseId
      final task = await getTaskById(taskId);
      
      // Créer une transaction budgétaire
      final userId = _supabase.auth.currentUser!.id;
      final transactionId = _uuid.v4();
      final now = DateTime.now().toUtc();
      
      await _supabase.from('budget_transactions').insert({
        'id': transactionId,
        'project_id': task.projectId,
        'phase_id': task.phaseId,
        'task_id': taskId,
        'amount': -amount, // Négatif car c'est une dépense
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
        'category': category,
        'subcategory': subcategory,
        'created_at': now.toIso8601String(),
        'created_by': userId,
      });
    } catch (e) {
      print('Erreur lors de l\'enregistrement de la dépense sur la tâche: $e');
      rethrow;
    }
  }

  // Méthodes privées pour les notifications
  
  // Vérifier si la date d'échéance d'une tâche est proche et envoyer des notifications
  Future<void> _checkTaskDueDate(Task task) async {
    if (task.dueDate == null || task.assignedTo == null || task.assignedTo!.isEmpty) {
      return;
    }
    
    final now = DateTime.now();
    final daysUntilDue = task.dueDate!.difference(now).inDays;
    
    try {
      // Obtenir le nom du projet
      final projectName = await _getProjectName(task.projectId);
      
      // Envoyer des notifications si la date d'échéance est proche (1 jour, 3 jours ou 7 jours)
      if (daysUntilDue <= 7) {
        await _notificationService.createTaskDueSoonNotification(
          task.id,
          task.title,
          projectName,
          task.dueDate!,
          task.assignedTo!,
        );
      }
      
      // Si la tâche est en retard, envoyer une notification spécifique
      if (daysUntilDue < 0 && task.status != 'completed') {
        await _notificationService.createTaskOverdueNotification(
          task.id,
          task.title,
          projectName,
          task.assignedTo!,
        );
      }
    } catch (e) {
      print('Erreur lors de la vérification de la date d\'échéance: $e');
    }
  }
  
  // Envoyer une notification d'assignation de tâche
  Future<void> _notifyTaskAssigned(Task task) async {
    if (task.assignedTo == null || task.assignedTo!.isEmpty) {
      return;
    }
    
    try {
      // Obtenir le nom du projet
      final projectName = await _getProjectName(task.projectId);
      
      // Envoyer la notification
      await _notificationService.createTaskAssignedNotification(
        task.id,
        task.title,
        projectName,
        task.assignedTo!,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification d\'assignation: $e');
    }
  }
  
  // Envoyer une notification de changement de statut de tâche
  Future<void> _notifyTaskStatusChange(Task task, String changedByUserId) async {
    if (task.assignedTo == null || task.assignedTo!.isEmpty) {
      return;
    }
    
    try {
      // Obtenir le nom du projet
      final projectName = await _getProjectName(task.projectId);
      
      // Envoyer la notification
      await _notificationService.createTaskStatusNotification(
        task.id,
        task.title,
        projectName,
        task.status,
        task.assignedTo!,
        changedByUserId,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification de changement de statut: $e');
    }
  }
  
  // Vérifier régulièrement les tâches dont la date d'échéance approche
  Future<void> checkAllTasksDueDates() async {
    try {
      // Récupérer toutes les tâches qui ont une date d'échéance et qui ne sont pas terminées
      final response = await _supabase
          .from('tasks')
          .select()
          .not('due_date', 'is', null)
          .neq('status', 'completed')
          .order('due_date', ascending: true);
      
      final tasks = response.map<Task>((json) => Task.fromJson(json)).toList();
      
      // Vérifier chaque tâche
      for (final task in tasks) {
        if (task.dueDate != null && task.assignedTo != null && task.assignedTo!.isNotEmpty) {
          final now = DateTime.now();
          final daysUntilDue = task.dueDate!.difference(now).inDays;
          
          // Si la date d'échéance est dans 1, 3 ou 7 jours, ou si la tâche est en retard
          if (daysUntilDue == 7 || daysUntilDue == 3 || daysUntilDue == 1 || daysUntilDue < 0) {
            await _checkTaskDueDate(task);
          }
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des dates d\'échéance de toutes les tâches: $e');
    }
  }
  
  // Obtenir le nom d'un projet à partir de son ID
  Future<String> _getProjectName(String projectId) async {
    try {
      final response = await _supabase
          .from('projects')
          .select('name')
          .eq('id', projectId)
          .single();
      
      return response['name'] as String;
    } catch (e) {
      print('Erreur lors de la récupération du nom du projet: $e');
      return 'Projet inconnu';
    }
  }
}
