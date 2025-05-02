import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/task_history_model.dart';
import '../../models/phase_model.dart';
import '../notification_service.dart';
import '../cache_service.dart';
import '../role_service.dart';
import '../auth_service.dart';

class ProjectService {
  final SupabaseClient _client = SupabaseConfig.client;
  final String _projectsTable = 'projects';
  final String _tasksTable = 'tasks';
  final String _phasesTable = 'phases';
  final String _taskHistoryTable = 'task_history';
  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();
  final RoleService _roleService = RoleService();
  final AuthService _authService = AuthService();

  // Récupérer tous les projets
  Future<List<Project>> getAllProjects() async {
    // Étape 1: Vérifier si des données en cache sont disponibles
    List<Project> cachedProjects = [];
    final cachedData = _cacheService.getCachedProjects();
    if (cachedData != null) {
      cachedProjects = cachedData.map((json) => Project.fromJson(json)).toList();
    }
    
    try {
      // Étape 2: Si le cache est vide, attendre la réponse de l'API, sinon retourner le cache immédiatement
      if (cachedProjects.isEmpty) {
        final response = await _client
            .from(_projectsTable)
            .select()
            .order('created_at', ascending: false);
        
        // Vérifier si planned_budget est présent dans les données brutes
        for (var projectJson in response) {
          print('Projet brut depuis Supabase: ${projectJson['name']}, PlannedBudget: ${projectJson['planned_budget']}');
        }
        
        final projects = response.map((json) => Project.fromJson(json)).toList();
        
        // Vérifier si planned_budget est correctement converti dans les objets Dart
        for (var project in projects) {
          print('Projet: ${project.name}, PlannedBudget: ${project.plannedBudget}');
        }
        
        // Mettre à jour le cache pour les prochaines fois
        await _cacheService.cacheProjects(response);
        
        return projects;
      } else {
        // Étape 3: Retourner les données du cache immédiatement
        
        // Étape 4: Déclencher une mise à jour en arrière-plan si le cache n'est plus valide
        if (!_cacheService.areProjectsCacheValid()) {
          _refreshProjectsInBackground();
        }
        
        return cachedProjects;
      }
    } catch (e) {
      // Si une erreur se produit et que nous avons des données en cache, utilisez-les
      if (cachedProjects.isNotEmpty) {
        return cachedProjects;
      }
      
      // Sinon, propager l'erreur
      print('Erreur lors de la récupération des projets: $e');
      rethrow;
    }
  }

  // Récupérer les projets d'un utilisateur
  Future<List<Project>> getProjectsByUser(String userId) async {
    try {
      // 1. Récupérer les projets créés par l'utilisateur
      final createdProjects = await _client
          .from(_projectsTable)
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      
      // 2. Récupérer les projets associés aux équipes de l'utilisateur
      final teamProjectsResponse = await _client
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      final teamIds = teamProjectsResponse.map<String>((json) => json['team_id'] as String).toList();
      
      List<dynamic> teamProjects = [];
      if (teamIds.isNotEmpty) {
        final teamProjectsIdsResponse = await _client
            .from('team_projects')
            .select('project_id')
            .inFilter('team_id', teamIds);
        
        final projectIds = teamProjectsIdsResponse.map<String>((json) => json['project_id'] as String).toList();
        
        if (projectIds.isNotEmpty) {
          teamProjects = await _client
              .from(_projectsTable)
              .select()
              .inFilter('id', projectIds)
              .neq('created_by', userId) // Exclure les projets déjà récupérés
              .order('created_at', ascending: false);
        }
      }
      
      // 3. Combiner les deux listes
      final allProjects = [...createdProjects, ...teamProjects];
      
      return allProjects.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des projets de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer un projet par son ID
  Future<Project> getProjectById(String projectId) async {
    try {
      final response = await _client
          .from(_projectsTable)
          .select()
          .eq('id', projectId)
          .single();
      
      return Project.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du projet: $e');
      rethrow;
    }
  }

  // Créer un nouveau projet
  Future<Project> createProject(Project project) async {
    try {
      // Vérifier si l'utilisateur a la permission de créer un projet
      final hasPermission = await _roleService.hasPermission(
        'create_project',
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de créer un projet');
      }

      // Récupérer l'ID de l'utilisateur
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('Aucun utilisateur connecté');
      }
      
      final response = await _client
          .from(_projectsTable)
          .insert(project.toJson())
          .select()
          .single();
      
      final createdProject = Project.fromJson(response);
      
      // Associer automatiquement le projet à l'utilisateur qui l'a créé
      try {
        await _client.rpc('auto_assign_project_to_creator', params: {
          'p_project_id': createdProject.id,
          'p_user_id': userId,
        });
        print('Projet ${createdProject.id} automatiquement associé au créateur $userId');
      } catch (e) {
        // Ne pas bloquer la création du projet si l'association échoue
        print('Erreur lors de l\'association automatique du projet à son créateur: $e');
      }
      
      // Envoyer une notification pour la création du projet
      await _notifyProjectCreation(createdProject);
      
      return createdProject;
    } catch (e) {
      print('Erreur lors de la création du projet: $e');
      rethrow;
    }
  }

  // Mettre à jour un projet
  Future<Project> updateProject(Project project) async {
    try {
      // Vérifier si l'utilisateur a la permission de mettre à jour le projet
      final hasPermission = await _roleService.hasPermission(
        'update_project',
        projectId: project.id,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de modifier ce projet');
      }
      
      // Récupérer l'ancien projet pour comparer le statut
      Project? oldProject;
      try {
        oldProject = await getProjectById(project.id);
      } catch (e) {
        print('Impossible de récupérer l\'ancien projet: $e');
      }
      
      final response = await _client
          .from(_projectsTable)
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
          await _notifyProjectStatusChange(updatedProject);
        }
      }
      
      // Vérifier si le budget prévu a changé
      if (oldProject != null && oldProject.plannedBudget != updatedProject.plannedBudget) {
        // Forcer l'invalidation du cache des projets pour que les changements soient visibles immédiatement
        print('Budget prévu modifié pour ${updatedProject.name}: ${oldProject.plannedBudget} → ${updatedProject.plannedBudget}');
        
        // Utiliser la nouvelle méthode pour invalider le cache des projets
        await _cacheService.invalidateProjectsCache();
      }
      
      // Vérifier si le budget a changé
      if (oldProject != null && 
          updatedProject.budgetAllocated != null && 
          updatedProject.budgetAllocated! > 0 && 
          updatedProject.plannedBudget != null && updatedProject.plannedBudget! > 0) {
        final percentage = (updatedProject.budgetAllocated! / updatedProject.plannedBudget!) * 100;
        
        // Si le budget alloué dépasse certains seuils du budget prévu, envoyer une alerte
        if (percentage > 50 && percentage < 75) {
          // Alerte à 50% (uniquement si on vient de dépasser ce seuil)
          if (oldProject.budgetAllocated == null || 
              oldProject.plannedBudget == null ||
              (oldProject.budgetAllocated! / oldProject.plannedBudget!) * 100 < 50) {
            await _notifyProjectBudgetAlert(updatedProject, percentage);
          }
        } else if (percentage >= 75 && percentage < 90) {
          // Alerte à 75% (uniquement si on vient de dépasser ce seuil)
          if (oldProject.budgetAllocated == null || 
              oldProject.plannedBudget == null ||
              (oldProject.budgetAllocated! / oldProject.plannedBudget!) * 100 < 75) {
            await _notifyProjectBudgetAlert(updatedProject, percentage);
          }
        } else if (percentage >= 90) {
          // Alerte à 90% (uniquement si on vient de dépasser ce seuil)
          if (oldProject.budgetAllocated == null || 
              oldProject.plannedBudget == null ||
              (oldProject.budgetAllocated! / oldProject.plannedBudget!) * 100 < 90) {
            await _notifyProjectBudgetAlert(updatedProject, percentage);
          }
        }
      }
      
      return updatedProject;
    } catch (e) {
      print('Erreur lors de la mise à jour du projet: $e');
      rethrow;
    }
  }

  // Supprimer un projet
  Future<void> deleteProject(String projectId) async {
    try {
      // Vérifier si l'utilisateur a la permission de supprimer le projet
      final hasPermission = await _roleService.hasPermission(
        'delete_project',
        projectId: projectId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de supprimer ce projet');
      }
      
      // 1. Récupérer toutes les phases du projet
      final phases = await getPhasesByProject(projectId);
      
      // 2. Pour chaque phase, supprimer toutes les tâches associées
      for (var phase in phases) {
        final tasks = await getTasksByPhase(phase.id);
        for (var task in tasks) {
          await deleteTask(task.id);
        }
        
        // 3. Supprimer la phase
        await _client.from(_phasesTable).delete().eq('id', phase.id);
      }
      
      // 4. Supprimer toutes les associations d'équipes au projet
      await _client.from('team_projects').delete().eq('project_id', projectId);
      
      // 5. Supprimer le projet lui-même
      await _client.from(_projectsTable).delete().eq('id', projectId);
    } catch (e) {
      print('Erreur lors de la suppression du projet: $e');
      rethrow;
    }
  }

  // Récupérer toutes les tâches d'un projet
  Future<List<Task>> getTasksByProject(String projectId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('project_id', projectId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches du projet: $e');
      rethrow;
    }
  }

  // Récupérer les tâches assignées à un utilisateur
  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('assigned_to', userId)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de l\'utilisateur: $e');
      rethrow;
    }
  }

  // Récupérer une tâche par son ID
  Future<Task> getTaskById(String taskId) async {
    try {
      final response = await _client
          .from(_tasksTable)
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
  Future<Task> createTask(Task task) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .insert(task.toJson())
          .select()
          .single();
      
      return Task.fromJson(response);
    } catch (e) {
      print('Erreur lors de la création de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour une tâche
  Future<Task> updateTask(Task task, {Task? oldTask}) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .update(task.toJson())
          .eq('id', task.id)
          .select()
          .single();
      
      final updatedTask = Task.fromJson(response);
      
      // Si nous avons l'ancienne version de la tâche, enregistrer les changements dans l'historique
      if (oldTask != null) {
        await _recordTaskChanges(oldTask, updatedTask);
      }
      
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour de la tâche: $e');
      rethrow;
    }
  }

  // Mettre à jour le statut d'une tâche
  Future<Task> updateTaskStatus(String taskId, String newStatus) async {
    try {
      // Récupérer la tâche avant la mise à jour
      final oldTask = await getTaskById(taskId);
      
      // Mise à jour du statut
      final response = await _client
          .from(_tasksTable)
          .update({'status': newStatus, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', taskId)
          .select()
          .single();
      
      final updatedTask = Task.fromJson(response);
      
      // Enregistrer le changement dans l'historique
      await _addTaskHistoryEntry(
        taskId: taskId,
        fieldName: 'status',
        oldValue: oldTask.status,
        newValue: newStatus,
      );
      
      return updatedTask;
    } catch (e) {
      print('Erreur lors de la mise à jour du statut de la tâche: $e');
      rethrow;
    }
  }

  // Enregistrer les changements apportés à une tâche dans l'historique
  Future<void> _recordTaskChanges(Task oldTask, Task newTask) async {
    try {
      // Vérifier les changements de statut
      if (oldTask.status != newTask.status) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'status',
          oldValue: oldTask.status,
          newValue: newTask.status,
        );
      }
      
      // Vérifier les changements de priorité
      if (oldTask.priority != newTask.priority) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'priority',
          oldValue: oldTask.priority.toString(),
          newValue: newTask.priority.toString(),
        );
      }
      
      // Vérifier les changements d'assignation
      if (oldTask.assignedTo != newTask.assignedTo) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'assigned_to',
          oldValue: oldTask.assignedTo,
          newValue: newTask.assignedTo ?? '',
        );
      }
      
      // Vérifier les changements de titre
      if (oldTask.title != newTask.title) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'title',
          oldValue: oldTask.title,
          newValue: newTask.title,
        );
      }
      
      // Vérifier les changements de description
      if (oldTask.description != newTask.description) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'description',
          oldValue: oldTask.description,
          newValue: newTask.description,
        );
      }
      
      // Vérifier les changements de date d'échéance
      final oldDueDate = oldTask.dueDate?.toIso8601String();
      final newDueDate = newTask.dueDate?.toIso8601String();
      if (oldDueDate != newDueDate) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'due_date',
          oldValue: oldDueDate,
          newValue: newDueDate ?? '',
        );
      }
      
      // Vérifier les changements de phase
      if (oldTask.phaseId != newTask.phaseId) {
        await _addTaskHistoryEntry(
          taskId: newTask.id,
          fieldName: 'phase_id',
          oldValue: oldTask.phaseId,
          newValue: newTask.phaseId ?? '',
        );
      }
    } catch (e) {
      print('Erreur lors de l\'enregistrement des changements dans l\'historique: $e');
      // Ne pas relancer l'exception pour ne pas perturber la mise à jour de la tâche
    }
  }

  // Ajouter une entrée dans l'historique des tâches
  Future<void> _addTaskHistoryEntry({
    required String taskId,
    required String fieldName,
    String? oldValue,
    required String newValue,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('Utilisateur non authentifié, impossible d\'ajouter l\'entrée d\'historique');
        return;
      }
      
      await _client.from(_taskHistoryTable).insert({
        'task_id': taskId,
        'user_id': userId,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
      });
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'entrée d\'historique: $e');
      // Ne pas relancer l'exception pour ne pas perturber la mise à jour de la tâche
    }
  }

  // Récupérer l'historique d'une tâche
  Future<List<TaskHistory>> getTaskHistory(String taskId) async {
    try {
      final response = await _client
          .from(_taskHistoryTable)
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      
      return response.map((json) => TaskHistory.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de l\'historique de la tâche: $e');
      rethrow;
    }
  }

  // Supprimer une tâche
  Future<void> deleteTask(String taskId) async {
    try {
      await _client
          .from(_tasksTable)
          .delete()
          .eq('id', taskId);
    } catch (e) {
      print('Erreur lors de la suppression de la tâche: $e');
      rethrow;
    }
  }

  // Récupérer toutes les tâches
  Future<List<Task>> getAllTasks() async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      
      print('Réponse brute de getAllTasks: $response');
      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération de toutes les tâches: $e');
      rethrow;
    }
  }

  // Récupérer les tâches pour une liste de projets accessibles (respecte RBAC)
  Future<List<Task>> getTasksForProjects(List<String> projectIds) async {
    try {
      if (projectIds.isEmpty) {
        print('Aucun projet accessible, retourne une liste vide');
        return [];
      }
      
      print('Récupération des tâches pour les projets: ${projectIds.join(", ")}');
      
      // Construire la requête manuellement car la méthode in_ n'est pas disponible
      // dans cette version de postgrest
      final query = _client.from(_tasksTable).select();
      
      // Si nous avons un seul projet, utiliser eq() directement
      if (projectIds.length == 1) {
        final response = await query
            .eq('project_id', projectIds[0])
            .order('priority', ascending: false)
            .order('created_at', ascending: false);
        
        print('Nombre de tâches récupérées (projet unique): ${response.length}');
        return response.map((json) => Task.fromJson(json)).toList();
      } 
      // Sinon, utiliser or() pour créer une condition "project_id in (...)"
      else {
        // Récupérer toutes les tâches puis filtrer manuellement
        final allTasksResponse = await query
            .order('priority', ascending: false)
            .order('created_at', ascending: false);
        
        // Filtrer manuellement par project_id
        final filteredTasks = allTasksResponse
            .where((taskJson) => projectIds.contains(taskJson['project_id']))
            .toList();
        
        print('Nombre de tâches récupérées (filtrage manuel): ${filteredTasks.length}');
        return filteredTasks.map((json) => Task.fromJson(json)).toList();
      }
    } catch (e) {
      print('Erreur lors de la récupération des tâches pour les projets: $e');
      rethrow;
    }
  }

  // Récupérer les tâches d'une phase
  Future<List<Task>> getTasksByPhase(String phaseId) async {
    try {
      final response = await _client
          .from(_tasksTable)
          .select()
          .eq('phase_id', phaseId);

      return response.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des tâches de la phase: $e');
      rethrow;
    }
  }

  // Récupérer toutes les phases
  Future<List<Phase>> getAllPhases() async {
    try {
      final response = await _client
          .from(_phasesTable)
          .select()
          .order('order_index', ascending: true);
      
      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases: $e');
      rethrow;
    }
  }

  // Récupérer les phases d'un projet
  Future<List<Phase>> getPhasesByProject(String projectId) async {
    try {
      final response = await _client
          .from(_phasesTable)
          .select()
          .eq('project_id', projectId)
          .order('order_index', ascending: true);
      
      return response.map<Phase>((json) => Phase.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des phases du projet: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget alloué d'un projet
  Future<Project> updateProjectBudgetAllocation(String projectId, double amount) async {
    try {
      // Récupérer le projet actuel
      final project = await getProjectById(projectId);
      
      // Calculer le nouveau montant alloué
      final double newBudgetAllocated = (project.budgetAllocated ?? 0) + amount;
      
      // Mettre à jour le projet
      final updatedProject = project.copyWith(
        budgetAllocated: newBudgetAllocated,
        updatedAt: DateTime.now().toUtc(),
      );
      
      return await updateProject(updatedProject);
    } catch (e) {
      print('Erreur lors de la mise à jour du budget alloué: $e');
      rethrow;
    }
  }

  // Mettre à jour le budget consommé d'un projet
  Future<Project> updateProjectBudgetConsumption(String projectId, double amount) async {
    try {
      // Récupérer le projet actuel
      final project = await getProjectById(projectId);
      
      // Calculer le nouveau montant consommé
      final double oldBudgetConsumed = project.budgetConsumed ?? 0;
      final double newBudgetConsumed = oldBudgetConsumed + amount;
      
      // Mettre à jour le projet
      final updatedProject = project.copyWith(
        budgetConsumed: newBudgetConsumed,
        updatedAt: DateTime.now().toUtc(),
      );
      
      final result = await updateProject(updatedProject);
      
      // Vérifier si le budget a dépassé un seuil
      if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
        final oldPercentage = (oldBudgetConsumed / project.budgetAllocated!) * 100;
        final newPercentage = (newBudgetConsumed / project.budgetAllocated!) * 100;
        
        // Envoyer une notification si nous franchissons un nouveau seuil
        if ((oldPercentage < 70 && newPercentage >= 70) || 
            (oldPercentage < 90 && newPercentage >= 90) || 
            (oldPercentage < 100 && newPercentage >= 100)) {
          await _notifyProjectBudgetAlert(updatedProject, newPercentage);
        }
      }
      
      return result;
    } catch (e) {
      print('Erreur lors de la mise à jour du budget consommé: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques budgétaires d'un projet
  Future<Map<String, dynamic>> getProjectBudgetStatistics(String projectId) async {
    try {
      // Récupérer le projet
      final project = await getProjectById(projectId);
      
      // Récupérer les tâches du projet pour calculer le budget alloué et consommé par tâche
      final tasks = await getTasksByProject(projectId);
      
      // Calculer le budget alloué et consommé par les tâches
      double tasksBudgetAllocated = 0;
      double tasksBudgetConsumed = 0;
      
      for (var task in tasks) {
        tasksBudgetAllocated += task.budgetAllocated ?? 0;
        tasksBudgetConsumed += task.budgetConsumed ?? 0;
      }
      
      // Récupérer les phases du projet pour calculer le budget alloué et consommé par phase
      final phases = await _client
          .from('phases')
          .select()
          .eq('project_id', projectId)
          .order('order_index', ascending: true);
      
      double phasesBudgetAllocated = 0;
      double phasesBudgetConsumed = 0;
      
      for (var phase in phases) {
        phasesBudgetAllocated += (phase['budget_allocated'] ?? 0).toDouble();
        phasesBudgetConsumed += (phase['budget_consumed'] ?? 0).toDouble();
      }
      
      // Calculer le pourcentage d'utilisation
      double budgetUsagePercentage = 0;
      if (project.budgetAllocated != null && project.budgetAllocated! > 0) {
        budgetUsagePercentage = ((project.budgetConsumed ?? 0) / project.budgetAllocated!) * 100;
      }
      
      return {
        'project_id': projectId,
        'project_name': project.name,
        'budget_allocated': project.budgetAllocated ?? 0,
        'budget_consumed': project.budgetConsumed ?? 0,
        'budget_remaining': (project.budgetAllocated ?? 0) - (project.budgetConsumed ?? 0),
        'budget_usage_percentage': budgetUsagePercentage,
        'tasks_budget_allocated': tasksBudgetAllocated,
        'tasks_budget_consumed': tasksBudgetConsumed,
        'phases_budget_allocated': phasesBudgetAllocated,
        'phases_budget_consumed': phasesBudgetConsumed,
        'is_budget_overrun': (project.budgetConsumed ?? 0) > (project.budgetAllocated ?? 0),
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques budgétaires: $e');
      rethrow;
    }
  }

  // Récupérer le budget planifié d'un projet directement depuis la base de données (sans cache)
  Future<double> getProjectPlannedBudget(String projectId) async {
    try {
      // Requête directe à Supabase pour récupérer uniquement le champ planned_budget
      final response = await _client
          .from(_projectsTable)
          .select('planned_budget')
          .eq('id', projectId)
          .single();
      
      print('Budget planifié récupéré directement depuis Supabase: ${response['planned_budget']}');
      
      // Convertir la valeur en double
      if (response['planned_budget'] != null) {
        if (response['planned_budget'] is int) {
          return (response['planned_budget'] as int).toDouble();
        } else {
          return response['planned_budget'] as double;
        }
      }
      
      return 0.0; // Valeur par défaut si le budget n'est pas défini
    } catch (e) {
      print('Erreur lors de la récupération du budget planifié: $e');
      return 0.0; // Valeur par défaut en cas d'erreur
    }
  }

  // Méthode pour rafraîchir les données en arrière-plan
  Future<void> _refreshProjectsInBackground() async {
    try {
      final response = await _client
          .from(_projectsTable)
          .select()
          .order('created_at', ascending: false);
      
      // Mettre à jour le cache
      await _cacheService.cacheProjects(response);
    } catch (e) {
      // Ignorer les erreurs en arrière-plan, juste logger
      print('Erreur lors du rafraîchissement des projets en arrière-plan: $e');
    }
  }

  // Récupérer les projets accessibles à l'utilisateur selon ses permissions RBAC
  Future<List<Project>> getAccessibleProjects() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('RBAC: Aucun utilisateur connecté pour récupérer les projets accessibles');
        return [];
      }
      
      // Vérifier si l'utilisateur a la permission globale read_all_projects
      final hasAllProjectsAccess = await _roleService.hasPermission('read_all_projects');
      
      if (hasAllProjectsAccess) {
        print('RBAC: Utilisateur avec permission read_all_projects, retourne tous les projets');
        return await getAllProjects();
      }
      
      print('RBAC: Récupération des projets accessibles pour l\'utilisateur: ${user.id}');
      
      // 1. Récupérer les projets accessibles via l'ancien field project_id dans user_roles
      final directProjectsResponse = await Supabase.instance.client
          .from('user_roles')
          .select('project_id')
          .eq('user_id', user.id)
          .not('project_id', 'is', null);
      
      final directProjectIds = directProjectsResponse
          .map<String>((json) => json['project_id'] as String)
          .toList();
      
      // 2. Récupérer les projets accessibles via la nouvelle table user_role_projects
      final userRolesResponse = await Supabase.instance.client
          .from('user_roles')
          .select('id')
          .eq('user_id', user.id);
      
      final userRoleIds = userRolesResponse
          .map<String>((json) => json['id'] as String)
          .toList();
      
      List<String> linkedProjectIds = [];
      
      if (userRoleIds.isNotEmpty) {
        // Traiter les user_role_ids par lots comme nous le faisons pour les projets
        const batchSize = 10;
        for (int i = 0; i < userRoleIds.length; i += batchSize) {
          final endIdx = (i + batchSize < userRoleIds.length) 
              ? i + batchSize 
              : userRoleIds.length;
          final currentBatch = userRoleIds.sublist(i, endIdx);
          
          // Pour chaque lot, récupérer les projets associés
          for (final roleId in currentBatch) {
            final roleProjectsResponse = await Supabase.instance.client
                .from('user_role_projects')
                .select('project_id')
                .eq('user_role_id', roleId);
            
            final roleProjects = roleProjectsResponse
                .map<String>((json) => json['project_id'] as String)
                .toList();
            
            linkedProjectIds.addAll(roleProjects);
          }
        }
      }
      
      // 3. Combiner tous les IDs de projet (supprimer les doublons avec toSet().toList())
      final allProjectIds = [...directProjectIds, ...linkedProjectIds].toSet().toList();
      
      if (allProjectIds.isEmpty) {
        print('RBAC: Aucun projet accessible pour l\'utilisateur');
        return [];
      }
      
      print('RBAC: Projets accessibles IDs: ${allProjectIds.join(", ")}');
      
      // Récupérer les détails des projets accessibles
      List<Project> projects = [];
      
      // Traiter les projets par lots pour éviter une requête trop longue
      const batchSize = 10;
      for (int i = 0; i < allProjectIds.length; i += batchSize) {
        final endIdx = (i + batchSize < allProjectIds.length) 
            ? i + batchSize 
            : allProjectIds.length;
        final currentBatch = allProjectIds.sublist(i, endIdx);
        
        // Construire une requête manuellement car la méthode in_ n'est pas disponible
        // dans cette version de postgrest
        final query = _client.from(_projectsTable).select();
        
        // Si nous avons un seul projet, utiliser eq() directement
        if (currentBatch.length == 1) {
          final batchResponse = await query
              .eq('id', currentBatch[0])
              .order('created_at', ascending: false);
          
          projects.addAll(batchResponse.map((json) => Project.fromJson(json)).toList());
        } else {
          // Sinon, récupérer tous les projets et filtrer manuellement
          final allProjectsResponse = await query.order('created_at', ascending: false);
          
          final filteredProjects = allProjectsResponse
              .where((projectJson) => currentBatch.contains(projectJson['id']))
              .toList();
          
          projects.addAll(filteredProjects.map((json) => Project.fromJson(json)).toList());
        }
      }
      
      print('RBAC: ${projects.length} projets accessibles récupérés');
      return projects;
    } catch (e) {
      print('RBAC: Erreur lors de la récupération des projets accessibles: $e');
      rethrow;
    }
  }

  // Méthodes privées pour les notifications
  
  // Envoyer des notifications pour la création d'un projet
  Future<void> _notifyProjectCreation(Project project) async {
    try {
      // Récupérer le créateur du projet
      final creatorId = project.createdBy;
      
      // Récupérer les membres de l'équipe associés au projet
      final teamMembers = await getProjectTeamMembers(project.id);
      
      // S'assurer que le créateur est inclus
      if (!teamMembers.contains(creatorId)) {
        teamMembers.add(creatorId);
      }
      
      // Créer les notifications
      await _notificationService.createProjectNotification(
        project.id,
        project.name,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications de création de projet: $e');
    }
  }
  
  // Envoyer des notifications pour un changement de statut de projet
  Future<void> _notifyProjectStatusChange(Project project) async {
    try {
      // Récupérer les membres de l'équipe associés au projet
      final teamMembers = await getProjectTeamMembers(project.id);
      
      // Créer les notifications
      await _notificationService.createProjectStatusNotification(
        project.id,
        project.name,
        project.status,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications de changement de statut: $e');
    }
  }
  
  // Envoyer des notifications pour une alerte de budget
  Future<void> _notifyProjectBudgetAlert(Project project, double percentage) async {
    try {
      // Récupérer les membres de l'équipe associés au projet
      final teamMembers = await getProjectTeamMembers(project.id);
      
      // Créer les notifications
      await _notificationService.createProjectBudgetAlert(
        project.id,
        project.name,
        percentage,
        teamMembers,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi des notifications d\'alerte de budget: $e');
    }
  }
  
  // Récupérer les membres d'un projet
  Future<List<String>> getProjectTeamMembers(String projectId) async {
    try {
      // Récupérer les équipes associées au projet
      final teamsResponse = await _client
          .from('team_projects')
          .select('team_id')
          .eq('project_id', projectId);
      
      // Si aucune équipe n'est associée, retourner uniquement le créateur
      if (teamsResponse.isEmpty) {
        final projectResponse = await _client
            .from(_projectsTable)
            .select('created_by')
            .eq('id', projectId)
            .single();
        
        return [projectResponse['created_by']];
      }
      
      // Pour chaque équipe, récupérer les membres
      final List<String> allTeamMembers = [];
      
      for (final team in teamsResponse) {
        final teamId = team['team_id'];
        final teamMembersResponse = await _client
            .from('team_members')
            .select('user_id')
            .eq('team_id', teamId)
            .eq('status', 'active');
        
        for (final member in teamMembersResponse) {
          allTeamMembers.add(member['user_id']);
        }
      }
      
      // Ajouter également le créateur du projet s'il n'est pas déjà inclus
      final projectResponse = await _client
          .from(_projectsTable)
          .select('created_by')
          .eq('id', projectId)
          .single();
      
      final creatorId = projectResponse['created_by'];
      if (!allTeamMembers.contains(creatorId)) {
        allTeamMembers.add(creatorId);
      }
      
      // Retourner une liste de membres uniques
      return allTeamMembers.toSet().toList();
    } catch (e) {
      print('Erreur lors de la récupération des membres du projet: $e');
      return [];
    }
  }
}
