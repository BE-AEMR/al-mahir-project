import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/budget_model.dart';
import '../../models/project_transaction_model.dart';
import '../../services/budget_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_message.dart';
import '../../utils/constants.dart';

class BudgetDashboardScreen extends StatefulWidget {
  const BudgetDashboardScreen({Key? key}) : super(key: key);

  @override
  _BudgetDashboardScreenState createState() => _BudgetDashboardScreenState();
}

class _BudgetDashboardScreenState extends State<BudgetDashboardScreen> {
  final BudgetService _budgetService = BudgetService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Budget> _budgets = [];
  List<ProjectTransaction> _recentTransactions = [];
  Map<String, dynamic> _budgetStatistics = {};
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final budgets = await _budgetService.getAllBudgets();
      Map<String, dynamic> statistics = {};
      List<ProjectTransaction> transactions = [];
      
      if (budgets.isNotEmpty) {
        statistics = await _budgetService.getBudgetStatistics();
        
        // Récupérer les transactions récentes (limité à 10)
        transactions = await _budgetService.getAllTransactions();
        transactions = transactions.take(10).toList();
      }

      setState(() {
        _budgets = budgets;
        _budgetStatistics = statistics;
        _recentTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord financier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? ErrorMessage(message: _errorMessage!)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBudgetSummary(),
                        const SizedBox(height: 24),
                        _buildFinancialOverview(),
                        const SizedBox(height: 24),
                        _buildExpensesChart(),
                        const SizedBox(height: 24),
                        _buildRecentTransactions(),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Naviguer vers l'écran de création de budget
          // Navigator.push(context, MaterialPageRoute(builder: (context) => CreateBudgetScreen()));
        },
        child: const Icon(Icons.add),
        tooltip: 'Créer un budget',
      ),
    );
  }

  Widget _buildBudgetSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé des budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _budgets.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun budget disponible. Créez votre premier budget !',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Column(
                    children: _budgets
                        .take(3) // Afficher uniquement les 3 derniers budgets
                        .map((budget) => _buildBudgetCard(budget))
                        .toList(),
                  ),
            if (_budgets.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      // Naviguer vers la liste complète des budgets
                      // Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetListScreen()));
                    },
                    child: const Text('Voir tous les budgets'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget) {
    final double usagePercentage = budget.calculateUsagePercentage();
    final Color progressColor = usagePercentage < 70
        ? Colors.green
        : usagePercentage < 90
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          // Naviguer vers les détails du budget
          // Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget)));
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      budget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_currencyFormat.format(budget.currentAmount)} / ${_currencyFormat.format(budget.initialAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Période: ${DateFormat('dd/MM/yyyy').format(budget.startDate)} - ${DateFormat('dd/MM/yyyy').format(budget.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${usagePercentage.toStringAsFixed(1)}% utilisé',
                    style: TextStyle(
                      fontSize: 12,
                      color: progressColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialOverview() {
    final totalIncome = _budgetStatistics['total_income'] ?? 0.0;
    final totalExpense = _budgetStatistics['total_expense'] ?? 0.0;
    final netBalance = _budgetStatistics['net_balance'] ?? 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aperçu financier',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard(
                    'Entrées',
                    _currencyFormat.format(totalIncome),
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialCard(
                    'Sorties',
                    _currencyFormat.format(totalExpense),
                    Icons.arrow_downward,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFinancialCard(
              'Solde net',
              _currencyFormat.format(netBalance),
              netBalance >= 0 ? Icons.check_circle : Icons.warning,
              netBalance >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
      String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesChart() {
    final Map<String, double> expensesByCategory =
        _budgetStatistics['expenses_by_category'] ?? {};

    if (expensesByCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    // Préparer les données pour le graphique
    final List<PieChartSectionData> pieChartSections = [];
    final List<Widget> indicators = [];

    // Limiter à 5 catégories maximum pour éviter l'encombrement
    final sortedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final displayCategories = sortedCategories.take(5).toList();
    double otherAmount = 0.0;
    if (sortedCategories.length > 5) {
      for (int i = 5; i < sortedCategories.length; i++) {
        otherAmount += sortedCategories[i].value;
      }
    }

    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.grey,
    ];

    for (int i = 0; i < displayCategories.length; i++) {
      final category = displayCategories[i];
      final color = colors[i % colors.length];

      pieChartSections.add(
        PieChartSectionData(
          color: color,
          value: category.value,
          title: '',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      indicators.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.key,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(_currencyFormat.format(category.value)),
            ],
          ),
        ),
      );
    }

    // Ajouter la catégorie "Autres" si nécessaire
    if (otherAmount > 0) {
      pieChartSections.add(
        PieChartSectionData(
          color: colors[5],
          value: otherAmount,
          title: '',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      indicators.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors[5],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Autres')),
              Text(_currencyFormat.format(otherAmount)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition des dépenses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: pieChartSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: indicators,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transactions récentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Naviguer vers la liste complète des transactions
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionListScreen()));
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _recentTransactions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Aucune transaction récente'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _recentTransactions[index];
                      return _buildTransactionItem(transaction);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(ProjectTransaction transaction) {
    final bool isIncome = transaction.amount > 0;
    final Color amountColor = isIncome ? Colors.green : Colors.red;
    final IconData icon = isIncome ? Icons.arrow_upward : Icons.arrow_downward;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: amountColor.withOpacity(0.1),
        child: Icon(icon, color: amountColor),
      ),
      title: Text(
        transaction.description,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transaction.subcategory ?? transaction.category} • ${DateFormat('dd/MM/yyyy').format(transaction.transactionDate)}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Text(
        _currencyFormat.format(transaction.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
      onTap: () {
        // Afficher les détails de la transaction
        // Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionDetailScreen(transaction: transaction)));
      },
    );
  }
}
