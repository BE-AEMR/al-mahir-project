import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/project_transaction_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/team_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/team_service/team_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../projects/project_detail_screen.dart';
import 'transaction_form_screen.dart';
import 'transaction_list_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final TeamService _teamService = TeamService();
  final ProjectFinanceService _projectFinanceService = ProjectFinanceService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  List<ProjectTransaction> _recentTransactions = [];
  List<ProjectTransaction> _projectTransactions = [];
  List<Project> _projects = [];
  List<Project> _projectsWithBalanceAlert = [];
  
  // États pour les équipes et visualisation des finances d'équipe
  bool _isAdmin = false;
  List<Team> _adminTeams = [];
  
  // Nouvelle approche: sélection par projet au lieu de l'équipe
  String? _selectedProjectId;
  bool _showAllProjects = true; // Afficher tous les projets par défaut au lieu des finances équipe
  
  // Obtenir le nom du projet sélectionné
  String get _selectedProjectName {
    if (_selectedProjectId == null || _projects.isEmpty) {
      return "";
    }
    
    final project = _projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => Project(
        id: "",
        name: "Projet inconnu",
        description: "",
        status: "active",
        createdBy: "",
        createdAt: DateTime.now(),
      ),
    );
    
    return project.name;
  }
  
  // États pour les graphiques interactifs
  int? _touchedExpenseIndex;
  int? _touchedIncomeIndex;
  
  // Filtres
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Statistiques financières
  double _totalRevenues = 0;
  double _totalExpenses = 0;
  double _totalBalance = 0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _projectFinanceService.supabaseClient.auth.currentUser!.id;
      
      // Vérifier si l'utilisateur est administrateur d'une équipe
      final adminTeams = await _teamService.getUserAdminTeams(userId);
      final isAdmin = adminTeams.isNotEmpty;
      
      // Mise à jour des équipes admin de l'utilisateur
      setState(() {
        _adminTeams = adminTeams;
        _isAdmin = isAdmin;
      });
      
      // Charger les transactions selon le contexte (personnel ou équipe)
      List<ProjectTransaction> projectTransactions;
      
      if (_isAdmin && _selectedProjectId != null) {
        // Charger les transactions de l'équipe sélectionnée
        projectTransactions = await _projectFinanceService.getProjectProjectTransactions(_selectedProjectId!);
      } else {
        // Charger les transactions personnels de l'utilisateur
        projectTransactions = await _projectFinanceService.getAllProjectTransactions();
      }
      
      // Extraire les transactions récentes (les 20 dernières)
      final recentTransactions = projectTransactions.take(20).toList();
      
      // Charger les projets
      final projects = await _projectService.getAllProjects();
      
      // Trouver les projets avec solde négatif (alerte)
      final projectsWithAlert = projects.where((project) {
        // Calculer les entrées et sorties d'argent pour ce projet
        double projectIncome = 0.0;
        double projectExpenses = 0.0;
        
        for (final transaction in projectTransactions) {
          if (transaction.projectId == project.id) {
            if (transaction.isIncome) {
              projectIncome += transaction.absoluteAmount;
            } else {
              projectExpenses += transaction.absoluteAmount;
            }
          }
        }
        
        // Un projet est en alerte si ses dépenses sont supérieures à ses revenus
        return projectExpenses > projectIncome;
      }).toList();
      
      // Calculer les statistiques financières
      // Méthode 1: Calcul basé sur les current_amount des budgets et les transactions
      final totalRevenues = projectTransactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalExpenses = projectTransactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalBalance = totalRevenues - totalExpenses;
      
      setState(() {
        _projectTransactions = projectTransactions;
        _projects = projects;
        _recentTransactions = recentTransactions;
        _projectsWithBalanceAlert = projectsWithAlert;
        _totalRevenues = totalRevenues;
        _totalExpenses = totalExpenses;
        _totalBalance = totalBalance;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord financier'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isAdmin && _selectedProjectId != null ? 85 : 48),
          child: Column(
            children: [
              // Afficher le badge de projet si nécessaire
              if (_isAdmin && _selectedProjectId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Theme.of(context).primaryColor,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Projet : ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text(
                          _selectedProjectName,
                          style: const TextStyle(
                            fontSize: 12, 
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.blue.shade700,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              // TabBar pour la navigation
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3.0,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14.0,
                ),
                tabs: const [
                  Tab(text: 'Vue d\'ensemble'),
                  Tab(text: 'Finances des projets'),
                  Tab(text: 'Alertes'),
                  Tab(text: 'Transactions'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Affichage du sélecteur de projet uniquement pour les administrateurs
          if (_isAdmin) 
            IconButton(
              icon: Icon(_showAllProjects ? Icons.people_alt : Icons.people_outline),
              onPressed: _showProjectSelector,
              tooltip: 'Gérer les finances de projet',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransactionFormScreen(),
            ),
          );
          
          if (result != null) {
            _loadData();
          }
        },
        tooltip: 'Ajouter une transaction',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProjectFinancesTab(),
                _buildAlertsTab(),
                _buildTransactionsTab(),
              ],
            ),
    );
  }
  
  void _showProjectSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Choix des données financières',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Voir tous les projets'),
              leading: const Icon(Icons.people),
              onTap: () {
                setState(() {
                  _showAllProjects = true;
                  _selectedProjectId = null;
                });
                Navigator.pop(context);
                _loadData();
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Mes projets',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Liste des projets
            ..._projects.map((project) => ListTile(
              title: Text(project.name),
              leading: const Icon(Icons.group_work),
              trailing: _selectedProjectId == project.id && !_showAllProjects
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                setState(() {
                  _showAllProjects = false;
                  _selectedProjectId = project.id;
                });
                Navigator.pop(context);
                _loadData();
              },
            )).toList(),
          ],
        );
      },
    );
  }
  
  Widget _buildOverviewTab() {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de résumé financier
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Revenus',
                    currencyFormat.format(_totalRevenues),
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Dépenses',
                    currencyFormat.format(_totalExpenses),
                    Icons.arrow_downward,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Solde',
                    currencyFormat.format(_totalBalance),
                    Icons.monetization_on,
                    _totalBalance >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Graphique de répartition des dépenses
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 24),
                    _buildExpensesChart(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Graphique de répartition des entrées
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Répartition des entrées',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildIncomesChart(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Transactions récentes
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TransactionListScreen(),
                              ),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _recentTransactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text('Aucune transaction récente')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _buildTransactionItem(_recentTransactions[index]);
                          },
                        ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionFormScreen(),
                          ),
                        ).then((value) {
                          if (value != null) {
                            _loadData();
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle transaction'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesChart() {
    // Grouper les transactions par catégorie et sous-catégorie
    final Map<String, double> expensesByCategory = {};
    
    // Définition des couleurs
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    for (final transaction in _recentTransactions.where((t) => !t.isIncome)) {
      // Utiliser la sous-catégorie si disponible, sinon la catégorie
      String displayCategory;
      if (transaction.subcategory != null && transaction.subcategory!.isNotEmpty) {
        displayCategory = transaction.subcategory!;
      } else {
        // Traduire la catégorie anglaise en français pour l'affichage
        if (transaction.category == 'expense') {
          displayCategory = 'Dépense';
        } else if (transaction.category == 'income') {
          displayCategory = 'Entrée';
        } else {
          displayCategory = transaction.category;
        }
      }
      
      final amount = transaction.absoluteAmount;
      
      if (expensesByCategory.containsKey(displayCategory)) {
        expensesByCategory[displayCategory] = expensesByCategory[displayCategory]! + amount;
      } else {
        expensesByCategory[displayCategory] = amount;
      }
    }
    
    // Si aucune dépense, afficher un message
    if (expensesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune dépense pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<PieChartSectionData> sections = [];
    
    int colorIndex = 0;
    List<String> categories = expensesByCategory.keys.toList();
    expensesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalExpenses) * 100;
      final isTouched = colorIndex == _touchedExpenseIndex;
      final double radius = isTouched ? 55 : 45;
      final double fontSize = isTouched ? 16.0 : 13.0;
      final double opacity = isTouched ? 1.0 : 0.8;
      
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          color: colors[colorIndex % colors.length].withOpacity(opacity),
          radius: radius,
          titleStyle: TextStyle(
            color: colors[colorIndex % colors.length],
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 3,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          badgeWidget: null,
          titlePositionPercentageOffset: 1.8,
          showTitle: true,
        ),
      );
      
      colorIndex++;
    });
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedExpenseIndex = null;
                      return;
                    }
                    _touchedExpenseIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              centerSpaceColor: Colors.grey[100],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: expensesByCategory.entries.map((entry) {
              final index = categories.indexOf(entry.key);
              final color = colors[index % colors.length];
              final isTouched = index == _touchedExpenseIndex;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _touchedExpenseIndex = _touchedExpenseIndex == index ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isTouched ? 8.0 : 4.0),
                  decoration: BoxDecoration(
                    color: isTouched ? color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isTouched ? 16 : 12,
                        height: isTouched ? 16 : 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isTouched
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key} (${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(entry.value)})',
                        style: TextStyle(
                          fontSize: isTouched ? 14 : 13,
                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomesChart() {
    // Grouper les transactions par catégorie et sous-catégorie
    final Map<String, double> incomesByCategory = {};
    
    // Définition des couleurs
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.blueGrey,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    for (final transaction in _recentTransactions.where((t) => t.isIncome)) {
      // Utiliser la sous-catégorie si disponible, sinon la catégorie
      String displayCategory;
      if (transaction.subcategory != null && transaction.subcategory!.isNotEmpty) {
        displayCategory = transaction.subcategory!;
      } else {
        // Traduire la catégorie anglaise en français pour l'affichage
        if (transaction.category == 'expense') {
          displayCategory = 'Dépense';
        } else if (transaction.category == 'income') {
          displayCategory = 'Entrée';
        } else {
          displayCategory = transaction.category;
        }
      }
      
      final amount = transaction.absoluteAmount;
      
      if (incomesByCategory.containsKey(displayCategory)) {
        incomesByCategory[displayCategory] = incomesByCategory[displayCategory]! + amount;
      } else {
        incomesByCategory[displayCategory] = amount;
      }
    }
    
    // Si aucune entrée, afficher un message
    if (incomesByCategory.isEmpty) {
      return const Center(
        child: Text('Aucune entrée pour la période sélectionnée'),
      );
    }
    
    // Convertir en données pour le graphique
    final List<PieChartSectionData> sections = [];
    
    int colorIndex = 0;
    List<String> categories = incomesByCategory.keys.toList();
    incomesByCategory.forEach((category, amount) {
      final percentage = (amount / _totalRevenues) * 100;
      final isTouched = colorIndex == _touchedIncomeIndex;
      final double radius = isTouched ? 55 : 45;
      final double fontSize = isTouched ? 16.0 : 13.0;
      final double opacity = isTouched ? 1.0 : 0.8;
      
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          color: colors[colorIndex % colors.length].withOpacity(opacity),
          radius: radius,
          titleStyle: TextStyle(
            color: colors[colorIndex % colors.length],
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            shadows: [
              Shadow(
                color: Colors.white,
                blurRadius: 3,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          badgeWidget: null,
          titlePositionPercentageOffset: 1.8,
          showTitle: true,
        ),
      );
      
      colorIndex++;
    });
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIncomeIndex = null;
                      return;
                    }
                    _touchedIncomeIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              centerSpaceColor: Colors.grey[100],
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: incomesByCategory.entries.map((entry) {
              final index = categories.indexOf(entry.key);
              final color = colors[index % colors.length];
              final isTouched = index == _touchedIncomeIndex;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _touchedIncomeIndex = _touchedIncomeIndex == index ? null : index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(isTouched ? 8.0 : 4.0),
                  decoration: BoxDecoration(
                    color: isTouched ? color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isTouched ? 16 : 12,
                        height: isTouched ? 16 : 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isTouched
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key} (${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(entry.value)})',
                        style: TextStyle(
                          fontSize: isTouched ? 14 : 13,
                          fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(ProjectTransaction transaction) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final bool isIncome = transaction.isIncome;
    final color = isIncome ? Colors.green : Colors.red;
    
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(
          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        transaction.description,
        style: const TextStyle(fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Text(
        currencyFormat.format(transaction.absoluteAmount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionFormScreen(
              transaction: transaction,
            ),
          ),
        ).then((value) {
          if (value != null) {
            _loadData();
          }
        });
      },
    );
  }

  Widget _buildProjectFinancesTab() {
    if (_projects.isEmpty) {
      return const Center(
        child: Text('Aucun projet trouvé'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          return _buildProjectFinanceCard(_projects[index]);
        },
      ),
    );
  }
  
  Widget _buildProjectFinanceCard(Project project) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Filtrer les transactions pour ce projet
    final projectTransactionsList = _projectTransactions.where(
      (transaction) => transaction.projectId == project.id
    ).toList();
    
    // Calculer les entrées et sorties d'argent pour ce projet
    double projectIncome = 0.0;
    double projectExpenses = 0.0;
    
    for (final transaction in projectTransactionsList) {
      if (transaction.isIncome) {
        projectIncome += transaction.absoluteAmount;
      } else {
        projectExpenses += transaction.absoluteAmount;
      }
    }
    
    // Calculer le solde (revenus - dépenses)
    final balance = projectIncome - projectExpenses;
    
    // Déterminer la couleur en fonction du solde
    Color statusColor = balance >= 0 ? Colors.green : Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: balance < 0
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (balance < 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Solde négatif',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Revenus: ${currencyFormat.format(projectIncome)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Dépenses: ${currencyFormat.format(projectExpenses)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Solde: ${currencyFormat.format(balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: balance < 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${projectTransactionsList.length} transactions',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Transactions'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionListScreen(projectId: project.id),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Transaction'),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionFormScreen(
                              projectId: project.id,
                            ),
                          ),
                        );
                        
                        if (result == true) {
                          _loadData();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAlertsTab() {
    if (_projectsWithBalanceAlert.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune alerte de dépassement de budget',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tous les projets sont dans les limites budgétaires',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projectsWithBalanceAlert.length,
        itemBuilder: (context, index) {
          final project = _projectsWithBalanceAlert[index];
          return _buildBalanceAlertCard(project);
        },
      ),
    );
  }
  
  Widget _buildBalanceAlertCard(Project project) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Calculer les entrées et sorties d'argent pour ce projet
    double projectIncome = 0.0;
    double projectExpenses = 0.0;
    for (final transaction in _projectTransactions) {
      if (transaction.projectId == project.id) {
        if (transaction.isIncome) {
          projectIncome += transaction.absoluteAmount;
        } else {
          projectExpenses += transaction.absoluteAmount;
        }
      }
    }
    
    // Calculer le solde
    final balance = projectIncome - projectExpenses;
    final negativeBalance = balance < 0 ? balance.abs() : 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.red, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alerte de solde négatif: ${project.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solde négatif: ${currencyFormat.format(-negativeBalance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revenus: ${currencyFormat.format(projectIncome)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dépenses: ${currencyFormat.format(projectExpenses)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Actions recommandées:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text('• Augmenter les revenus du projet'),
            const Text('• Réduire les dépenses si possible'),
            const Text('• Vérifier les transactions récentes'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Voir les transactions'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionListScreen(projectId: project.id),
                      ),
                    ).then((_) => _loadData());
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter un revenu'),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionFormScreen(
                          projectId: project.id,
                        ),
                      ),
                    );
                    
                    if (result == true) {
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTransactionsTab() {
    if (_projectTransactions.isEmpty) {
      return const Center(
        child: Text('Aucune transaction trouvée'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _projectTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionItem(_projectTransactions[index]);
        },
      ),
    );
  }
}
