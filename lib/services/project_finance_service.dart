import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project_transaction_model.dart';
import '../models/project_model.dart';
import 'project_service/project_service.dart';
import 'notification_service.dart';
import 'role_service.dart';

class ProjectFinanceService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  final ProjectService _projectService = ProjectService();
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();
  
  // Exposer le client Supabase pour permettre l'accès à l'utilisateur courant
  SupabaseClient get supabaseClient => _supabase;

  // Vérifier si l'utilisateur actuel est un administrateur d'une équipe
  Future<bool> isUserAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }
      
      // Vérifier si l'utilisateur est administrateur d'au moins une équipe
      final response = await _supabase
          .from('team_members')
          .select()
          .eq('user_id', userId)
          .eq('role', 'admin')
          .eq('status', 'active');
      
      return response.isNotEmpty; // Utilisateur est admin s'il a au moins une équipe où il est admin
    } catch (e) {
      print('Erreur lors de la vérification du statut d\'administrateur: $e');
      return false;
    }
  }

  // Récupérer toutes les transactions pour un projet spécifique
  Future<List<ProjectTransaction>> getProjectTransactions(String projectId) async {
    try {
      // Récupérer les informations du projet pour avoir le nom
      final project = await _projectService.getProjectById(projectId);
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('project_id', projectId)
          .order('transaction_date', ascending: false);

      final transactions = response.map<ProjectTransaction>((json) {
        // Ajouter le nom du projet aux données JSON
        json['project_name'] = project.name;
        return ProjectTransaction.fromJson(json);
      }).toList();

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions pour un projet spécifique
  Future<List<ProjectTransaction>> getProjectProjectTransactions(String projectId) async {
    try {
      // Récupérer les informations du projet pour avoir le nom
      final project = await _projectService.getProjectById(projectId);
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('project_id', projectId)
          .order('transaction_date', ascending: false);

      final transactions = response.map<ProjectTransaction>((json) {
        // Ajouter le nom du projet aux données JSON
        json['project_name'] = project.name;
        return ProjectTransaction.fromJson(json);
      }).toList();

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      return [];
    }
  }

  // Récupérer toutes les transactions de l'utilisateur actuel
  Future<List<ProjectTransaction>> getAllTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer les transactions récentes (pour le tableau de bord)
  Future<List<ProjectTransaction>> getRecentTransactions(int limit) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions récentes: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par phase
  Future<List<ProjectTransaction>> getTransactionsByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('phase_id', phaseId)
          .order('transaction_date', ascending: false);

      // Récupérer les projets et phases associés pour enrichir les données
      final List<ProjectTransaction> transactions = [];
      
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la phase: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par tâche
  Future<List<ProjectTransaction>> getTransactionsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('budget_transactions') // Utilisation de la table existante
          .select()
          .eq('task_id', taskId)
          .order('transaction_date', ascending: false);

      // Récupérer les projets, phases et tâches associés pour enrichir les données
      final List<ProjectTransaction> transactions = [];
      
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la tâche: $e');
      rethrow;
    }
  }

  // Récupérer les transactions d'une équipe
  Future<List<ProjectTransaction>> getTeamTransactions(String teamId) async {
    try {
      // Récupérer les projets associés à l'équipe
      final projectsResponse = await _supabase
          .from('team_projects')
          .select('project_id')
          .eq('team_id', teamId);
      
      final projectIds = projectsResponse.map<String>((json) => json['project_id'] as String).toList();
      
      if (projectIds.isEmpty) {
        return [];
      }
      
      // Récupérer les transactions liées à ces projets individuellement
      List<ProjectTransaction> transactions = [];
      for (final projectId in projectIds) {
        final project = await _projectService.getProjectById(projectId);
        
        final response = await _supabase
            .from('budget_transactions') // Utilisation de la table existante
            .select()
            .eq('project_id', projectId)
            .order('transaction_date', ascending: false);
            
        for (final json in response) {
          json['project_name'] = project.name;
          transactions.add(ProjectTransaction.fromJson(json));
        }
      }
      
      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions de l\'équipe: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions de projet
  Future<List<ProjectTransaction>> getAllProjectTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Vérifier si l'utilisateur est un administrateur
      final isAdmin = await isUserAdmin();
      
      List<String> projectIds = [];
      
      // 1. Récupérer les projets créés par l'utilisateur
      final createdProjectsResponse = await _supabase
          .from('projects')
          .select('id')
          .eq('created_by', userId);
      
      for (var project in createdProjectsResponse) {
        projectIds.add(project['id'] as String);
      }
      
      // 2. Récupérer les équipes dont l'utilisateur est membre
      final teamsResponse = await _supabase
          .from('team_members')
          .select('team_id')
          .eq('user_id', userId)
          .eq('status', 'active');
      
      if (teamsResponse.isNotEmpty) {
        final teamIds = teamsResponse.map<String>((t) => t['team_id'] as String).toList();
        
        // 3. Récupérer les projets associés à ces équipes via la table team_projects
        final teamProjectsResponse = await _supabase
            .from('team_projects')
            .select('project_id')
            .inFilter('team_id', teamIds);
        
        for (var project in teamProjectsResponse) {
          if (!projectIds.contains(project['project_id'])) {
            projectIds.add(project['project_id'] as String);
          }
        }
      }
      
      // Si l'utilisateur est un administrateur global, il peut voir tous les projets
      if (isAdmin) {
        final allProjectsResponse = await _supabase
            .from('projects')
            .select('id');
            
        for (var project in allProjectsResponse) {
          if (!projectIds.contains(project['id'])) {
            projectIds.add(project['id'] as String);
          }
        }
      }
      
      // Si aucun projet n'est accessible, retourner une liste vide
      if (projectIds.isEmpty) {
        return [];
      }
      
      // print('DEBUG ProjectFinanceService: Projets accessibles pour l\'utilisateur ${userId}: ${projectIds.join(', ')}');
      
      // Récupérer les transactions liées à ces projets
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .inFilter('project_id', projectIds)
          .order('transaction_date', ascending: false);

      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          try {
            final project = await _projectService.getProjectById(json['project_id']);
            json['project_name'] = project.name;
          } catch (e) {
            json['project_name'] = 'Projet inconnu';
          }
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }

      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération de toutes les transactions: $e');
      return [];
    }
  }

  // Récupérer toutes les transactions accessibles à l'utilisateur selon ses permissions RBAC
  Future<List<ProjectTransaction>> getAccessibleTransactions() async {
    try {
      print('RBAC: Récupération des transactions accessibles à l\'utilisateur');
      final userId = _supabase.auth.currentUser!.id;
      
      // Récupérer les projets accessibles via RBAC
      final accessibleProjects = await _projectService.getAccessibleProjects();
      if (accessibleProjects.isEmpty) {
        print('RBAC: Aucun projet accessible pour l\'utilisateur');
        return [];
      }
      
      print('RBAC: ${accessibleProjects.length} projets accessibles trouvés');
      final List<String> projectIds = accessibleProjects.map((p) => p.id).toList();
      
      // Récupérer les transactions pour ces projets
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .inFilter('project_id', projectIds)
          .order('transaction_date', ascending: false);
      
      final List<ProjectTransaction> transactions = [];
      
      // Récupérer les noms des projets pour chaque transaction
      for (final json in response) {
        if (json['project_id'] != null) {
          // Trouver le projet dans la liste des projets accessibles
          final matchingProject = accessibleProjects.firstWhere(
            (p) => p.id == json['project_id'],
            orElse: () => Project(
              id: json['project_id'],
              name: 'Projet inconnu',
              description: '',
              status: 'active',
              createdBy: '',
              createdAt: DateTime.now(),
            ),
          );
          
          json['project_name'] = matchingProject.name;
        } else {
          json['project_name'] = 'Projet non spécifié';
        }
        
        transactions.add(ProjectTransaction.fromJson(json));
      }
      
      print('RBAC: ${transactions.length} transactions accessibles récupérées');
      return transactions;
    } catch (e) {
      print('Erreur lors de la récupération des transactions accessibles: $e');
      return [];
    }
  }

  // Créer une nouvelle transaction de projet
  Future<ProjectTransaction> createTransaction(
    String projectId,
    String? phaseId,
    String? taskId,
    double amount,
    String description,
    DateTime transactionDate,
    String category,
    String? subcategory, {
    String? notes, // Ajout du paramètre notes optionnel
  }) async {
    try {
      // Vérifier si l'utilisateur a la permission de créer une transaction
      final hasPermission = await _roleService.hasPermission(
        'create_transaction',
        projectId: projectId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de créer une transaction pour ce projet');
      }
      
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now().toUtc();
      final transactionId = _uuid.v4();
      
      // Récupérer des informations supplémentaires pour l'affichage
      String projectName = 'Projet inconnu';
      String? phaseName;
      String? taskName;
      
      try {
        final project = await _projectService.getProjectById(projectId);
        projectName = project.name;
        
        // Calculer le nouveau solde du projet
        List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(projectId);
        
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in projectTransactions) {
          if (transaction.isIncome) {
            projectIncome += transaction.absoluteAmount;
          } else {
            projectExpenses += transaction.absoluteAmount;
          }
        }
        
        // Ajouter la transaction actuelle
        // Déterminer le type de transaction (income/expense) selon le montant
        String transactionType = amount >= 0 ? 'income' : 'expense';
        
        if (transactionType == 'income') {
          projectIncome += amount.abs();
        } else {
          projectExpenses += amount.abs();
        }
        
        // Calculer le solde
        double projectBalance = projectIncome - projectExpenses;
        
        // Créer une notification si le solde devient négatif
        if (projectBalance < 0) {
          _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            project.createdBy,
          );
        }
      } catch (e) {
        print('Erreur lors de la récupération du projet: $e');
      }
      
      if (phaseId != null) {
        try {
          final phaseResponse = await _supabase
              .from('phases')
              .select()
              .eq('id', phaseId)
              .single();
          
          phaseName = phaseResponse['name'];
        } catch (e) {
          print('Erreur lors de la récupération de la phase: $e');
        }
      }
      
      if (taskId != null) {
        try {
          final taskResponse = await _supabase
              .from('tasks')
              .select()
              .eq('id', taskId)
              .single();
          
          taskName = taskResponse['name'];
        } catch (e) {
          print('Erreur lors de la récupération de la tâche: $e');
        }
      }

      // Déterminer le type de transaction (income/expense) selon le montant
      String transactionType = amount >= 0 ? 'income' : 'expense';

      final transaction = ProjectTransaction(
        id: transactionId,
        projectId: projectId,
        projectName: projectName,
        phaseId: phaseId,
        phaseName: phaseName,
        taskId: taskId,
        taskName: taskName,
        amount: amount, // Le montant peut être positif ou négatif
        description: description,
        notes: notes, // Ajout des notes
        transactionDate: transactionDate,
        transactionType: transactionType, // 'income' ou 'expense'
        category: category, // Anciennement subcategory
        subcategory: subcategory, // Nouvelle sous-catégorie
        createdAt: now,
        createdBy: userId,
      );

      // Convertir en format compatible avec la table existante
      final jsonData = transaction.toJson();
      
      // Adapter les noms de champs pour la base de données
      final dbData = {
        'id': jsonData['id'],
        'project_id': jsonData['project_id'],
        'phase_id': jsonData['phase_id'],
        'task_id': jsonData['task_id'],
        'amount': jsonData['amount'],
        'description': jsonData['description'],
        'notes': jsonData['notes'], // Ajout des notes dans les données
        'transaction_date': jsonData['transaction_date'],
        'transaction_type': jsonData['transaction_type'], // Mise à jour
        'category': jsonData['category'],
        'subcategory': jsonData['subcategory'],
        'created_at': jsonData['created_at'],
        'updated_at': jsonData['updated_at'],
        'created_by': jsonData['created_by'],
      };

      await _supabase.from('budget_transactions').insert(dbData);

      return transaction;
    } catch (e) {
      print('Erreur lors de la création de la transaction: $e');
      rethrow;
    }
  }

  // Mettre à jour une transaction
  Future<void> updateTransaction(ProjectTransaction transaction) async {
    try {
      // Vérifier si l'utilisateur a la permission de mettre à jour une transaction
      final hasPermission = await _roleService.hasPermission(
        'update_transaction',
        projectId: transaction.projectId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de modifier cette transaction');
      }
      
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now().toUtc();
      
      // Recalculer le solde du projet après la mise à jour
      List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(transaction.projectId);
      
      double projectIncome = 0.0;
      double projectExpenses = 0.0;
      
      // Exclure la transaction actuelle car elle sera remplacée
      for (final tx in projectTransactions) {
        if (tx.id != transaction.id) {
          if (tx.isIncome) {
            projectIncome += tx.absoluteAmount;
          } else {
            projectExpenses += tx.absoluteAmount;
          }
        }
      }
      
      // Ajouter la transaction mise à jour
      if (transaction.isIncome) {
        projectIncome += transaction.absoluteAmount;
      } else {
        projectExpenses += transaction.absoluteAmount;
      }
      
      // Calculer le nouveau solde
      double projectBalance = projectIncome - projectExpenses;
      
      // Si le solde devient négatif, envoyer une alerte
      if (projectBalance < 0) {
        try {
          final project = await _projectService.getProjectById(transaction.projectId);
          _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            project.createdBy,
          );
        } catch (e) {
          print('Erreur lors de la notification de solde négatif: $e');
        }
      }
      
      // Adapter pour la table existante
      final updatedData = {
        'project_id': transaction.projectId,
        'phase_id': transaction.phaseId,
        'task_id': transaction.taskId,
        'amount': transaction.amount,
        'description': transaction.description,
        'notes': transaction.notes, // Ajout des notes dans la mise à jour
        'transaction_date': transaction.transactionDate.toIso8601String(),
        'transaction_type': transaction.transactionType, // Mise à jour
        'category': transaction.category,
        'subcategory': transaction.subcategory,
        'updated_at': now.toIso8601String(),
      };

      await _supabase
          .from('budget_transactions')
          .update(updatedData)
          .eq('id', transaction.id);
    } catch (e) {
      print('Erreur lors de la mise à jour de la transaction: $e');
      rethrow;
    }
  }

  // Supprimer une transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      // Récupérer la transaction avant de la supprimer pour mettre à jour le projet
      final transactionResponse = await _supabase
          .from('budget_transactions')
          .select()
          .eq('id', transactionId)
          .single();
      
      final projectId = transactionResponse['project_id'] as String?;
      
      if (projectId == null) {
        throw Exception('Transaction invalide : projet non spécifié');
      }
      
      // Vérifier si l'utilisateur a la permission de supprimer une transaction
      final hasPermission = await _roleService.hasPermission(
        'delete_transaction', 
        projectId: projectId,
      );
      
      if (!hasPermission) {
        throw Exception('Vous n\'avez pas l\'autorisation de supprimer cette transaction');
      }
      
      final amount = transactionResponse['amount'] as double;
      final category = transactionResponse['transaction_type'] as String;
      
      // Calculer l'impact sur le solde du projet
      if (projectId != null) {
        try {
          // Recalculer le solde après la suppression de cette transaction
          List<ProjectTransaction> projectTransactions = await getProjectProjectTransactions(projectId);
          
          double projectIncome = 0.0;
          double projectExpenses = 0.0;
          
          for (final transaction in projectTransactions) {
            // Exclure la transaction en cours de suppression
            if (transaction.id != transactionId) {
              if (transaction.isIncome) {
                projectIncome += transaction.absoluteAmount;
              } else {
                projectExpenses += transaction.absoluteAmount;
              }
            }
          }
          
          // Calculer le nouveau solde
          double projectBalance = projectIncome - projectExpenses;
          
          // Si le solde devient négatif après la suppression, envoyer une alerte
          if (projectBalance < 0) {
            final project = await _projectService.getProjectById(projectId);
            _notificationService.createProjectBalanceAlertNotification(
              project.id,
              project.name,
              projectBalance,
              project.createdBy,
            );
          }
        } catch (e) {
          print('Erreur lors de la mise à jour du solde du projet: $e');
        }
      }

      await _supabase
          .from('budget_transactions')
          .delete()
          .eq('id', transactionId);
    } catch (e) {
      print('Erreur lors de la suppression de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer une transaction par son ID
  Future<ProjectTransaction> getTransactionById(String transactionId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('id', transactionId)
          .single();

      String projectName = 'Projet non spécifié';
      if (response['project_id'] != null) {
        try {
          final project = await _projectService.getProjectById(response['project_id']);
          projectName = project.name;
        } catch (e) {
          print('Erreur lors de la récupération du projet: $e');
        }
      }
      
      response['project_name'] = projectName;
      
      return ProjectTransaction.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la transaction: $e');
      rethrow;
    }
  }
  
  // Calculer le solde actuel d'un projet
  Future<double> calculateProjectBalance(String projectId) async {
    try {
      final transactions = await getProjectTransactions(projectId);
      double balance = 0;
      
      for (final transaction in transactions) {
        balance += transaction.amount;
      }
      
      return balance;
    } catch (e) {
      print('Erreur lors du calcul du solde du projet: $e');
      rethrow;
    }
  }
  
  // Obtenir des statistiques financières pour un projet
  Future<Map<String, dynamic>> getProjectFinanceStatistics(String projectId) async {
    try {
      final transactions = await getProjectTransactions(projectId);
      
      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> expensesByCategory = {};
      Map<String, double> incomesByCategory = {};
      
      for (final transaction in transactions) {
        if (transaction.isIncome) {
          totalIncome += transaction.amount;
          
          final category = transaction.subcategory ?? transaction.category;
          incomesByCategory[category] = (incomesByCategory[category] ?? 0) + transaction.amount;
        } else {
          totalExpense += transaction.amount.abs();
          
          final category = transaction.subcategory ?? transaction.category;
          expensesByCategory[category] = (expensesByCategory[category] ?? 0) + transaction.amount.abs();
        }
      }
      
      return {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'balance': totalIncome - totalExpense,
        'expenses_by_category': expensesByCategory,
        'incomes_by_category': incomesByCategory,
      };
    } catch (e) {
      print('Erreur lors de la récupération des statistiques financières: $e');
      rethrow;
    }
  }
}
