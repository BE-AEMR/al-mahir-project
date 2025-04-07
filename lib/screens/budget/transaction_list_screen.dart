import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/project_transaction_model.dart';
import '../../services/budget_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_message.dart';
import '../../utils/constants.dart';

class TransactionListScreen extends StatefulWidget {
  final String? budgetId; // Si présent, filtre les transactions pour un budget spécifique
  final String? projectId; // Si présent, filtre les transactions pour un projet spécifique
  final String? phaseId; // Si présent, filtre les transactions pour une phase spécifique
  final String? taskId; // Si présent, filtre les transactions pour une tâche spécifique

  const TransactionListScreen({
    Key? key, 
    this.budgetId,
    this.projectId,
    this.phaseId,
    this.taskId,
  }) : super(key: key);

  @override
  _TransactionListScreenState createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final BudgetService _budgetService = BudgetService();
  bool _isLoading = true;
  String? _errorMessage;
  List<ProjectTransaction> _transactions = [];
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  
  // Filtres
  String _filterCategory = 'Toutes';
  String _sortBy = 'Date (récent)';
  bool _showOnlyIncomes = false;
  bool _showOnlyExpenses = false;
  
  // Liste des catégories disponibles pour le filtre
  List<String> _categories = ['Toutes'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<ProjectTransaction> transactions;
      
      // Charger les transactions soit pour un budget spécifique, soit toutes
      if (widget.budgetId != null) {
        transactions = await _budgetService.getTransactionsByBudget(widget.budgetId!);
      } else if (widget.projectId != null) {
        transactions = await _budgetService.getTransactionsByProject(widget.projectId!);
      } else if (widget.phaseId != null) {
        transactions = await _budgetService.getTransactionsByPhase(widget.phaseId!);
      } else if (widget.taskId != null) {
        transactions = await _budgetService.getTransactionsByTask(widget.taskId!);
      } else {
        transactions = await _budgetService.getAllTransactions();
      }
      
      // Extraire toutes les catégories uniques
      Set<String> categorySet = {'Toutes'};
      for (var transaction in transactions) {
        if (transaction.category.isNotEmpty) {
          categorySet.add(transaction.category);
        }
      }
      
      setState(() {
        _transactions = transactions;
        _categories = categorySet.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des transactions: $e';
        _isLoading = false;
      });
    }
  }

  List<ProjectTransaction> _getFilteredTransactions() {
    List<ProjectTransaction> filteredList = List.from(_transactions);
    
    // Appliquer le filtre de catégorie
    if (_filterCategory != 'Toutes') {
      filteredList = filteredList.where((t) => t.category == _filterCategory).toList();
    }
    
    // Appliquer les filtres d'entrée/sortie
    if (_showOnlyIncomes && !_showOnlyExpenses) {
      filteredList = filteredList.where((t) => t.transactionType == 'income').toList();
    } else if (_showOnlyExpenses && !_showOnlyIncomes) {
      filteredList = filteredList.where((t) => t.transactionType == 'expense').toList();
    }
    
    // Appliquer le tri
    switch (_sortBy) {
      case 'Date (récent)':
        filteredList.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
        break;
      case 'Date (ancien)':
        filteredList.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
        break;
      case 'Montant (élevé)':
        filteredList.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
        break;
      case 'Montant (faible)':
        filteredList.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
        break;
      case 'Catégorie':
        filteredList.sort((a, b) => a.category.compareTo(b.category));
        break;
    }
    
    return filteredList;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filtrer les transactions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _filterCategory,
                    isExpanded: true,
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _filterCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Trier par', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _sortBy,
                    isExpanded: true,
                    items: [
                      'Date (récent)',
                      'Date (ancien)',
                      'Montant (élevé)',
                      'Montant (faible)',
                      'Catégorie'
                    ].map((sort) {
                      return DropdownMenuItem<String>(
                        value: sort,
                        child: Text(sort),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(
                    title: const Text('Entrées uniquement'),
                    value: _showOnlyIncomes,
                    onChanged: (value) {
                      setDialogState(() {
                        _showOnlyIncomes = value!;
                        if (_showOnlyIncomes) {
                          _showOnlyExpenses = false;
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text('Sorties uniquement'),
                    value: _showOnlyExpenses,
                    onChanged: (value) {
                      setDialogState(() {
                        _showOnlyExpenses = value!;
                        if (_showOnlyExpenses) {
                          _showOnlyIncomes = false;
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    // Les filtres sont déjà mis à jour dans les widgets
                  });
                  Navigator.pop(context);
                },
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.budgetId != null 
            ? 'Transactions du budget' 
            : widget.projectId != null 
              ? 'Transactions du projet' 
              : widget.phaseId != null 
                ? 'Transactions de la phase' 
                : widget.taskId != null 
                  ? 'Transactions de la tâche' 
                  : 'Toutes les transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrer',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? ErrorMessage(message: _errorMessage!)
              : _buildTransactionsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Naviguer vers l'écran de création de transaction
          // Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(budgetId: widget.budgetId)));
        },
        child: const Icon(Icons.add),
        tooltip: 'Nouvelle transaction',
      ),
    );
  }

  Widget _buildTransactionsList() {
    final filteredTransactions = _getFilteredTransactions();
    
    if (filteredTransactions.isEmpty) {
      return const Center(
        child: Text('Aucune transaction ne correspond aux critères'),
      );
    }
    
    // Calculer le total des entrées et sorties
    double totalIncomes = 0;
    double totalExpenses = 0;
    for (var transaction in filteredTransactions) {
      if (transaction.transactionType == 'income') {
        totalIncomes += transaction.amount;
      } else {
        totalExpenses += transaction.amount.abs();
      }
    }
    
    return Column(
      children: [
        // Afficher le résumé des transactions filtrées
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrées',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(totalIncomes),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sorties',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(totalExpenses),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solde',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(totalIncomes - totalExpenses),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: totalIncomes >= totalExpenses ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Liste des transactions
        Expanded(
          child: ListView.separated(
            itemCount: filteredTransactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final transaction = filteredTransactions[index];
              return _buildTransactionListItem(transaction);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionListItem(ProjectTransaction transaction) {
    final bool isIncome = transaction.transactionType == 'income';
    final Color amountColor = isIncome ? Colors.green : Colors.red;
    final IconData icon = isIncome 
        ? Icons.arrow_upward 
        : Icons.arrow_downward;
        
    // Formater la date
    final String formattedDate = DateFormat('dd/MM/yyyy').format(transaction.transactionDate);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: amountColor.withOpacity(0.1),
        child: Icon(icon, color: amountColor, size: 20),
      ),
      title: Text(
        transaction.description,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Catégorie: ${transaction.subcategory ?? transaction.category}'),
          Text('Date: $formattedDate'),
          if (transaction.projectId != null)
            Text('Projet: ${transaction.projectName ?? transaction.projectId}'),
        ],
      ),
      trailing: Text(
        _currencyFormat.format(transaction.amount),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
      isThreeLine: true,
      onTap: () {
        // Naviguer vers les détails de la transaction ou formulaire d'édition
        // Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionFormScreen(transaction: transaction)));
      },
    );
  }
}
