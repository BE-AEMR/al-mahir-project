import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../models/budget_transaction_model.dart';
import '../models/budget_allocation_model.dart';

class BudgetService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  
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

  // Récupérer tous les budgets créés par l'utilisateur actuel
  Future<List<Budget>> getAllBudgets() async {
    try {
      final isAdmin = await isUserAdmin();
      
      if (isAdmin) {
        // Si l'utilisateur est un administrateur, récupérer tous les budgets
        final response = await _supabase
            .from('budgets')
            .select()
            .order('start_date', ascending: false);
            
        return response.map<Budget>((json) => Budget.fromJson(json)).toList();
      } else {
        // Sinon, récupérer uniquement les budgets créés par l'utilisateur actuel
        final userId = _supabase.auth.currentUser!.id;
        
        final response = await _supabase
            .from('budgets')
            .select()
            .eq('created_by', userId)
            .order('start_date', ascending: false);
            
        return response.map<Budget>((json) => Budget.fromJson(json)).toList();
      }
    } catch (e) {
      print('Erreur lors de la récupération des budgets: $e');
      rethrow;
    }
  }

  // Récupérer tous les budgets (alias de getAllBudgets pour maintenir la compatibilité)
  Future<List<Budget>> getBudgets() async {
    return getAllBudgets();
  }

  // Récupérer un budget par son ID
  Future<Budget> getBudgetById(String budgetId) async {
    try {
      final response = await _supabase
          .from('budgets')
          .select()
          .eq('id', budgetId)
          .single();

      return Budget.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération du budget: $e');
      rethrow;
    }
  }

  // Créer un nouveau budget
  Future<Budget> createBudget(
    String name,
    String description,
    double initialAmount,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final budgetId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final budget = Budget(
        id: budgetId,
        name: name,
        description: description,
        initialAmount: initialAmount,
        currentAmount: initialAmount, // Initialement le montant actuel est égal au montant initial
        startDate: startDate,
        endDate: endDate,
        createdAt: now,
        createdBy: userId,
      );

      await _supabase.from('budgets').insert(budget.toJson());
      return budget;
    } catch (e) {
      print('Erreur lors de la création du budget: $e');
      rethrow;
    }
  }

  // Mettre à jour un budget
  Future<void> updateBudget(Budget budget) async {
    try {
      final updatedBudget = budget.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('budgets')
          .update(updatedBudget.toJson())
          .eq('id', budget.id);
    } catch (e) {
      print('Erreur lors de la mise à jour du budget: $e');
      rethrow;
    }
  }

  // Supprimer un budget
  Future<void> deleteBudget(String budgetId) async {
    try {
      await _supabase.from('budgets').delete().eq('id', budgetId);
    } catch (e) {
      print('Erreur lors de la suppression du budget: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions d'un budget
  Future<List<BudgetTransaction>> getTransactionsByBudget(String budgetId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('budget_id', budgetId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions de l'utilisateur actuel
  Future<List<BudgetTransaction>> getAllTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      rethrow;
    }
  }

  // Récupérer les transactions récentes (pour le tableau de bord)
  Future<List<BudgetTransaction>> getRecentTransactions(int limit) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('created_by', userId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions récentes: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par projet
  Future<List<BudgetTransaction>> getTransactionsByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('project_id', projectId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour le projet: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par phase
  Future<List<BudgetTransaction>> getTransactionsByPhase(String phaseId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('phase_id', phaseId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la phase: $e');
      rethrow;
    }
  }

  // Récupérer les transactions par tâche
  Future<List<BudgetTransaction>> getTransactionsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('task_id', taskId)
          .order('transaction_date', ascending: false);

      return response.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions pour la tâche: $e');
      rethrow;
    }
  }

  // Récupérer les budgets d'une équipe
  Future<List<Budget>> getTeamBudgets(String teamId) async {
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
      
      // Récupérer les budgets liés à ces projets via les allocations
      final allocationsResponse = await _supabase
          .from('budget_allocations')
          .select('budget_id')
          .in_('project_id', projectIds);
      
      final budgetIds = allocationsResponse.map<String>((json) => json['budget_id'] as String).toList();
      
      if (budgetIds.isEmpty) {
        return [];
      }
      
      // Récupérer les détails des budgets
      final budgetsResponse = await _supabase
          .from('budgets')
          .select()
          .in_('id', budgetIds)
          .order('start_date', ascending: false);
      
      return budgetsResponse.map<Budget>((json) => Budget.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des budgets de l\'équipe: $e');
      rethrow;
    }
  }

  // Récupérer les transactions d'une équipe
  Future<List<BudgetTransaction>> getTeamTransactions(String teamId) async {
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
      
      // Récupérer les transactions liées à ces projets
      final transactionsResponse = await _supabase
          .from('budget_transactions')
          .select()
          .in_('project_id', projectIds)
          .order('transaction_date', ascending: false);
      
      return transactionsResponse.map<BudgetTransaction>((json) => BudgetTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions de l\'équipe: $e');
      rethrow;
    }
  }

  // Créer une nouvelle transaction
  Future<BudgetTransaction> createTransaction(
    String? budgetId,
    String? projectId,
    String? phaseId,
    String? taskId,
    double amount,
    String description,
    DateTime transactionDate,
    String category,
    String? subcategory,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final transactionId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final transaction = BudgetTransaction(
        id: transactionId,
        budgetId: budgetId,
        projectId: projectId,
        phaseId: phaseId,
        taskId: taskId,
        amount: amount,
        description: description,
        transactionDate: transactionDate,
        category: category,
        subcategory: subcategory,
        createdAt: now,
        createdBy: userId,
      );

      await _supabase.from('budget_transactions').insert(transaction.toJson());

      // Mettre à jour le montant actuel du budget si un budget est spécifié
      if (budgetId != null) {
        final budget = await getBudgetById(budgetId);
        double newAmount;
        if (category == 'expense') {
          newAmount = budget.currentAmount - amount;
        } else {
          newAmount = budget.currentAmount + amount;
        }

        final updatedBudget = budget.copyWith(
          currentAmount: newAmount,
          updatedAt: now,
        );

        await updateBudget(updatedBudget);
      }

      return transaction;
    } catch (e) {
      print('Erreur lors de la création de la transaction: $e');
      rethrow;
    }
  }

  // Mettre à jour une transaction
  Future<void> updateTransaction(BudgetTransaction transaction) async {
    try {
      // Récupérer l'ancienne transaction pour calculer la différence
      final oldTransaction = await getTransactionById(transaction.id);
      final now = DateTime.now().toUtc();
      final updatedTransaction = transaction.copyWith(
        updatedAt: now,
      );

      await _supabase
          .from('budget_transactions')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);

      // Mettre à jour le montant actuel du budget si nécessaire
      if (transaction.budgetId != null) {
        final budget = await getBudgetById(transaction.budgetId!);
        double newAmount = budget.currentAmount;

        // Annuler l'effet de l'ancienne transaction
        if (oldTransaction.category == 'expense') {
          newAmount += oldTransaction.amount;
        } else {
          newAmount -= oldTransaction.amount;
        }

        // Appliquer l'effet de la nouvelle transaction
        if (transaction.category == 'expense') {
          newAmount -= transaction.amount;
        } else {
          newAmount += transaction.amount;
        }

        final updatedBudget = budget.copyWith(
          currentAmount: newAmount,
          updatedAt: now,
        );

        await updateBudget(updatedBudget);
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de la transaction: $e');
      rethrow;
    }
  }

  // Supprimer une transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      // Récupérer la transaction avant de la supprimer pour mettre à jour le budget
      final transaction = await getTransactionById(transactionId);
      final now = DateTime.now().toUtc();

      await _supabase
          .from('budget_transactions')
          .delete()
          .eq('id', transactionId);

      // Mettre à jour le montant actuel du budget si nécessaire
      if (transaction.budgetId != null) {
        final budget = await getBudgetById(transaction.budgetId!);
        double newAmount = budget.currentAmount;

        // Annuler l'effet de la transaction supprimée
        if (transaction.category == 'expense') {
          newAmount += transaction.amount;
        } else {
          newAmount -= transaction.amount;
        }

        final updatedBudget = budget.copyWith(
          currentAmount: newAmount,
          updatedAt: now,
        );

        await updateBudget(updatedBudget);
      }
    } catch (e) {
      print('Erreur lors de la suppression de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer une transaction par son ID
  Future<BudgetTransaction> getTransactionById(String transactionId) async {
    try {
      final response = await _supabase
          .from('budget_transactions')
          .select()
          .eq('id', transactionId)
          .single();

      return BudgetTransaction.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer les allocations de budget par budget
  Future<List<BudgetAllocation>> getAllocationsByBudget(String budgetId) async {
    try {
      final response = await _supabase
          .from('budget_allocations')
          .select()
          .eq('budget_id', budgetId)
          .order('created_at', ascending: false);

      return response.map<BudgetAllocation>((json) => BudgetAllocation.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des allocations: $e');
      rethrow;
    }
  }

  // Récupérer les allocations de budget par projet
  Future<List<BudgetAllocation>> getAllocationsByProject(String projectId) async {
    try {
      final response = await _supabase
          .from('budget_allocations')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return response.map<BudgetAllocation>((json) => BudgetAllocation.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des allocations pour le projet: $e');
      rethrow;
    }
  }

  // Créer une nouvelle allocation de budget
  Future<BudgetAllocation> createAllocation(
    String budgetId,
    String projectId,
    double amount,
    String description,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final allocationId = _uuid.v4();
      final now = DateTime.now().toUtc();

      final allocation = BudgetAllocation(
        id: allocationId,
        budgetId: budgetId,
        projectId: projectId,
        amount: amount,
        description: description,
        allocationDate: now,
        createdAt: now,
        createdBy: userId,
      );

      await _supabase.from('budget_allocations').insert(allocation.toJson());
      return allocation;
    } catch (e) {
      print('Erreur lors de la création de l\'allocation: $e');
      rethrow;
    }
  }

  // Allouer un budget à un projet (alias pour createAllocation)
  Future<BudgetAllocation> allocateBudgetToProject(
    String budgetId,
    String projectId,
    double amount,
    String description,
  ) async {
    return createAllocation(budgetId, projectId, amount, description);
  }

  // Mettre à jour une allocation de budget
  Future<void> updateAllocation(BudgetAllocation allocation) async {
    try {
      final updatedAllocation = allocation.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      await _supabase
          .from('budget_allocations')
          .update(updatedAllocation.toJson())
          .eq('id', allocation.id);
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'allocation: $e');
      rethrow;
    }
  }

  // Supprimer une allocation de budget
  Future<void> deleteAllocation(String allocationId) async {
    try {
      await _supabase
          .from('budget_allocations')
          .delete()
          .eq('id', allocationId);
    } catch (e) {
      print('Erreur lors de la suppression de l\'allocation: $e');
      rethrow;
    }
  }

  // Récupérer une allocation par son ID
  Future<BudgetAllocation> getAllocationById(String allocationId) async {
    try {
      final response = await _supabase
          .from('budget_allocations')
          .select()
          .eq('id', allocationId)
          .single();

      return BudgetAllocation.fromJson(response);
    } catch (e) {
      print('Erreur lors de la récupération de l\'allocation: $e');
      rethrow;
    }
  }
}
