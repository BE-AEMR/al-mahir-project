import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project_transaction_model.dart';
import '../screens/budget/transaction_form_screen.dart';
import '../screens/budget/transaction_list_screen.dart';
import '../services/role_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetSummaryWidget extends StatelessWidget {
  final double? budgetAllocated;
  final double? budgetConsumed;
  final List<ProjectTransaction>? transactions;
  final String? projectId;
  final String? phaseId;
  final String? taskId;
  final bool showAddButton;
  final VoidCallback? onAddPressed;
  final VoidCallback? onTap;
  final Function(ProjectTransaction)? onTransactionAdded;
  final Function(ProjectTransaction)? onTransactionUpdated;
  final Function(ProjectTransaction)? onTransactionDeleted;

  const BudgetSummaryWidget({
    Key? key,
    this.budgetAllocated,
    this.budgetConsumed,
    this.transactions,
    this.projectId,
    this.phaseId,
    this.taskId,
    this.showAddButton = false,
    this.onAddPressed,
    this.onTap,
    this.onTransactionAdded,
    this.onTransactionUpdated,
    this.onTransactionDeleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Calculer les montants à partir des transactions si elles sont fournies
    double allocated = budgetAllocated ?? 0;
    double consumed = budgetConsumed ?? 0;
    
    if (transactions != null && transactions!.isNotEmpty) {
      // Les entrées (positives) sont des allocations de budget
      final allocations = transactions!.where((t) => t.amount > 0);
      if (allocations.isNotEmpty) {
        allocated = allocations.fold(0, (sum, t) => sum + t.amount);
      }
      
      // Les sorties (négatives) sont des dépenses
      final expenses = transactions!.where((t) => t.amount < 0);
      if (expenses.isNotEmpty) {
        consumed = expenses.fold(0, (sum, t) => sum + t.amount.abs());
      }
    }
    
    final double remaining = allocated - consumed;
    final double usagePercentage = allocated > 0 
        ? (consumed / allocated * 100).clamp(0, 100) 
        : 0;
    
    final Color progressColor = usagePercentage < 70
        ? Colors.green
        : usagePercentage < 90
            ? Colors.orange
            : Colors.red;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Résumé du budget',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Bouton commenté car remplacé par le bouton "Nouvelle transaction" avec vérification RBAC
                    /*
                    if (showAddButton && onAddPressed != null)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        onPressed: onAddPressed,
                        tooltip: 'Allouer un budget',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    */
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBudgetInfoItem(
                        'Alloué',
                        currencyFormat.format(allocated),
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildBudgetInfoItem(
                        'Consommé',
                        currencyFormat.format(consumed),
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildBudgetInfoItem(
                        'Restant',
                        currencyFormat.format(remaining),
                        remaining >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Utilisation'),
                        Text(
                          '${usagePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: usagePercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (transactions != null && transactions!.isNotEmpty) 
            _buildTransactionsList(context),
          if (projectId != null)
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    // Vérifier la permission create_transaction avant d'ouvrir le formulaire
                    final roleService = RoleService();
                    final hasPermission = await roleService.hasPermission('create_transaction', projectId: projectId);
                    
                    if (!hasPermission) {
                      // Si l'utilisateur n'a pas la permission, afficher un message d'erreur
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vous n\'avez pas la permission de créer une transaction'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Si l'utilisateur a la permission, ouvrir le formulaire
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionFormScreen(
                            projectId: projectId,
                            phaseId: phaseId,
                            taskId: taskId,
                          ),
                        ),
                      ).then((result) {
                        if (result != null) {
                          if (result is ProjectTransaction && onTransactionAdded != null) {
                            // Transaction créée ou mise à jour
                            onTransactionAdded!(result);
                          } else if (result is Map && result['deleted'] == true && onTransactionDeleted != null) {
                            // Transaction supprimée
                            final String transactionId = result['transactionId'];
                            final deletedTransaction = transactions?.firstWhere(
                              (t) => t.id == transactionId,
                              orElse: () => ProjectTransaction(
                                id: transactionId,
                                projectId: projectId ?? '',
                                projectName: '',
                                amount: 0,
                                description: '',
                                transactionDate: DateTime.now(),
                                category: 'other',
                                createdAt: DateTime.now(),
                                createdBy: '',
                                transactionType: 'expense',
                              ),
                            );
                            if (deletedTransaction != null) {
                              onTransactionDeleted!(deletedTransaction);
                            }
                          }
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle transaction'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    // Vérifier la permission read_all_transactions avant d'ouvrir la liste
                    final roleService = RoleService();
                    final hasPermission = await roleService.hasPermission('read_all_transactions', projectId: projectId);
                    
                    if (!hasPermission) {
                      // Si l'utilisateur n'a pas la permission, afficher un message d'erreur
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vous n\'avez pas la permission de voir toutes les transactions'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Si l'utilisateur a la permission, ouvrir la liste
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionListScreen(
                            projectId: projectId,
                            phaseId: phaseId,
                            taskId: taskId,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('Voir toutes les transactions'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    if (transactions == null || transactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Afficher seulement les 3 dernières transactions
    final recentTransactions = transactions!.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Transactions récentes',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentTransactions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final transaction = recentTransactions[index];
            final bool isIncome = transaction.amount > 0;
            final Color amountColor = isIncome ? Colors.green : Colors.red;
            
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: amountColor.withOpacity(0.1),
                radius: 16,
                child: Icon(
                  isIncome ? Icons.arrow_upward : Icons.arrow_downward, 
                  color: amountColor,
                  size: 16,
                ),
              ),
              title: Text(
                transaction.description,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Text(
                currencyFormat.format(transaction.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              onTap: () async {
                // Vérifier la permission read_transaction avant d'ouvrir le formulaire
                final roleService = RoleService();
                final hasPermission = await roleService.hasPermission('update_transaction', projectId: transaction.projectId);
                
                if (!hasPermission) {
                  // Si l'utilisateur n'a pas la permission, afficher un message d'erreur
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vous n\'avez pas la permission de modifier cette transaction'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                
                // Si l'utilisateur a la permission, ouvrir le formulaire
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(
                        transaction: transaction,
                      ),
                    ),
                  ).then((updatedTransaction) {
                    if (updatedTransaction != null) {
                      if (onTransactionUpdated != null) {
                        onTransactionUpdated!(updatedTransaction);
                      }
                    }
                  });
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBudgetInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
