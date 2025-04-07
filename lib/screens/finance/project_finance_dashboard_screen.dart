import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'dart:math';
import '../dashboard/widgets/modern_project_selector.dart';
import '../../models/project_transaction_model.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/team_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/notification_service.dart';
import '../../services/cache_service.dart';
import '../../services/role_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/permission_gated.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../projects/project_detail_screen.dart';
import '../budget/transaction_form_screen.dart';

// Wrapper pour l'écran Finance avec vérification RBAC
class ProjectFinanceDashboardScreenWrapper extends StatefulWidget {
  const ProjectFinanceDashboardScreenWrapper({Key? key}) : super(key: key);

  @override
  State<ProjectFinanceDashboardScreenWrapper> createState() => _ProjectFinanceDashboardScreenWrapperState();
}

class _ProjectFinanceDashboardScreenWrapperState extends State<ProjectFinanceDashboardScreenWrapper> {
  final ProjectService _projectService = ProjectService();
  final RoleService _roleService = RoleService();
  bool _isLoading = true;
  List<Project> _accessibleProjects = [];
  Project? _firstProject;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      print('=== RBAC DEBUG === [FinanceScreenWrapper] Vérification des permissions...');
      // Charger tous les projets auxquels l'utilisateur a accès
      final accessibleProjects = await _projectService.getAccessibleProjects();
      
      if (accessibleProjects.isEmpty) {
        // L'utilisateur n'a pas accès à aucun projet
        if (mounted) {
          setState(() {
            _isLoading = false;
            _accessibleProjects = [];
          });
        }
      } else {
        // L'utilisateur a accès à au moins un projet
        if (mounted) {
          setState(() {
            _isLoading = false;
            _accessibleProjects = accessibleProjects;
            _firstProject = accessibleProjects.first;
          });
        }
      }
    } catch (e) {
      print('=== RBAC DEBUG === [FinanceScreenWrapper] Erreur: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_accessibleProjects.isEmpty) {
      // Aucun projet accessible, afficher l'écran d'accès refusé
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accès refusé'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Vous n\'avez pas l\'autorisation d\'accéder aux finances',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      );
    }

    // Au moins un projet accessible, afficher l'écran des finances
    return ProjectFinanceDashboardScreen(
      projectId: _accessibleProjects.length == 1 ? _accessibleProjects.first.id : null,
      accessibleProjects: _accessibleProjects,
    );
  }
}

// Classe de données pour les graphiques circulaires
class ChartData {
  final String category;
  final double amount;
  final Color color;
  final String percentText;
  final String amountText;

  ChartData(this.category, this.amount, this.color, {
    required this.percentText,
    required this.amountText
  });
}

class ProjectFinanceDashboardScreen extends StatefulWidget {
  final String? projectId;
  final List<Project> accessibleProjects;

  const ProjectFinanceDashboardScreen({Key? key, this.projectId, required this.accessibleProjects}) : super(key: key);

  @override
  State<ProjectFinanceDashboardScreen> createState() => _ProjectFinanceDashboardScreenState();
}

class _ProjectFinanceDashboardScreenState extends State<ProjectFinanceDashboardScreen> with SingleTickerProviderStateMixin, RbacMixin {
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final TeamService _teamService = TeamService();
  final ProjectFinanceService _projectFinanceService = ProjectFinanceService();
  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();
  final RoleService _roleService = RoleService();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  List<ProjectTransaction> _recentTransactions = [];
  List<ProjectTransaction> _projectTransactions = [];
  List<Project> _projects = [];
  List<Project> _projectsWithBalanceAlert = [];
  
  // États pour les équipes et visualisation des finances d'équipe
  bool _isAdmin = false;
  List<dynamic> _adminTeams = []; // Changer le type de List<Team> à List<dynamic>
  
  // Sélection par projet
  String? _selectedProjectId;
  bool _showAllProjects = true; // Afficher tous les projets par défaut
  
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
  
  // Filtres
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Statistiques financières
  double _totalRevenues = 0;
  double _totalExpenses = 0;
  double _totalBalance = 0;
  
  // Variables pour le drill-down des graphiques
  String? _selectedExpenseCategory;
  String? _selectedRevenueCategory;
  bool _showExpenseSubcategories = false;
  bool _showRevenueSubcategories = false;
  
  // Contrôleurs pour gérer les états locaux des graphiques sans rebuild complet
  final ValueNotifier<String?> _selectedExpenseCategoryNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _selectedRevenueCategoryNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialiser le projet sélectionné depuis le paramètre si fourni
    if (widget.projectId != null) {
      _selectedProjectId = widget.projectId;
      _showAllProjects = false;
    }
    
    // Définir la liste des projets accessible
    _projects = widget.accessibleProjects;
    
    _loadData();
    
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }
  
  @override
  void dispose() {
    // Libération des ressources
    _tabController.dispose();
    _selectedExpenseCategoryNotifier.dispose();
    _selectedRevenueCategoryNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 1. Vérifier si des données complètes sont disponibles dans le cache
      final cachedProjects = _cacheService.getCachedProjects();
      final cachedTransactions = _cacheService.getCachedTransactions(null);
      
      // Si nous avons les données principales en cache
      if (cachedProjects != null && cachedProjects.isNotEmpty && 
          cachedTransactions != null && cachedTransactions.isNotEmpty) {
        
        // Convertir les données JSON du cache en objets
        final projects = cachedProjects.map((json) => Project.fromJson(json)).toList();
        final projectTransactions = cachedTransactions.map((json) => ProjectTransaction.fromJson(json)).toList();
        
        // Filtrer les transactions selon le contexte (projet spécifique ou tous les projets)
        List<ProjectTransaction> filteredTransactions = projectTransactions;
        if (_selectedProjectId != null) {
          filteredTransactions = projectTransactions
              .where((t) => t.projectId == _selectedProjectId)
              .toList();
        }
        
        // Extraire les transactions récentes (les 20 dernières)
        final recentTransactions = filteredTransactions.take(20).toList();
        
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
        final totalRevenues = filteredTransactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
        final totalExpenses = filteredTransactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
        final totalBalance = totalRevenues - totalExpenses;
        
        // Mise à jour de l'UI avec les données du cache
        setState(() {
          _projectTransactions = filteredTransactions;
          _projects = projects;
          _recentTransactions = recentTransactions;
          _projectsWithBalanceAlert = projectsWithAlert;
          _totalRevenues = totalRevenues;
          _totalExpenses = totalExpenses;
          _totalBalance = totalBalance;
        });
        
        // Simuler un chargement bref pour permettre l'animation des graphiques
        // Maintenir _isLoading à true pendant un court instant
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
        
        // Vérifier si l'utilisateur est administrateur d'une équipe en arrière-plan
        _checkAdminStatusInBackground();
        
        // Charger les données fraîches en arrière-plan (sans bloquer l'interface)
        _loadDataInBackground();
        return;
      }
      
      // Si aucune donnée en cache, charger normalement
      await _loadDataFromServer();
      
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
  
  // Vérification du statut d'administrateur en arrière-plan
  Future<void> _checkAdminStatusInBackground() async {
    try {
      final userId = _projectFinanceService.supabaseClient.auth.currentUser!.id;
      final adminTeams = await _teamService.getUserAdminTeams(userId);
      
      if (mounted) {
        setState(() {
          _adminTeams = adminTeams;
          _isAdmin = adminTeams.isNotEmpty;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification du statut admin: $e');
    }
  }
  
  // Chargement des données à partir du serveur
  Future<void> _loadDataFromServer() async {
    try {
      print('=== RBAC DEBUG === [FinanceScreen] Chargement des données avec filtrage RBAC');
      final userId = _projectFinanceService.supabaseClient.auth.currentUser!.id;
      
      // Vérifier si l'utilisateur a accès à plusieurs projets
      final hasMultipleProjects = widget.accessibleProjects.length > 1;
      final isAdmin = await _projectFinanceService.isUserAdmin(); // Utiliser ProjectFinanceService à la place de TeamService
      
      // Utiliser ce statut pour contrôler l'affichage du sélecteur de projet
      final showProjectSelector = hasMultipleProjects || isAdmin;
      
      // Récupérer les équipes administrées si nécessaire
      final adminTeams = isAdmin ? await _teamService.getUserAdminTeams(userId) : [];
      
      // Charger les transactions selon le contexte (projet spécifique ou tous les projets accessibles)
      List<ProjectTransaction> projectTransactions;
      
      if (_selectedProjectId != null) {
        // Charger les transactions du projet sélectionné
        print('=== RBAC DEBUG === [FinanceScreen] Chargement des transactions du projet $_selectedProjectId');
        projectTransactions = await _projectFinanceService.getProjectProjectTransactions(_selectedProjectId!);
      } else {
        // Charger toutes les transactions auxquelles l'utilisateur a accès via RBAC
        print('=== RBAC DEBUG === [FinanceScreen] Chargement de toutes les transactions accessibles');
        projectTransactions = await _projectFinanceService.getAccessibleTransactions();
      }
      
      // Extraire les transactions récentes (les 20 dernières)
      final recentTransactions = projectTransactions.take(20).toList();
      
      // Les projets sont déjà filtrés via le wrapper RBAC
      final projects = widget.accessibleProjects;
      print('=== RBAC DEBUG === [FinanceScreen] ${projects.length} projets accessibles');
      
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
      final totalRevenues = projectTransactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalExpenses = projectTransactions.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.absoluteAmount);
      final totalBalance = totalRevenues - totalExpenses;
      
      // Créer des notifications pour les projets en alerte (solde négatif)
      for (final project in projectsWithAlert) {
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
        
        final projectBalance = projectIncome - projectExpenses;
        
        // Créer une notification pour le solde négatif
        if (projectBalance < 0) {
          await _notificationService.createProjectBalanceAlertNotification(
            project.id,
            project.name,
            projectBalance,
            userId,
          );
        }
      }
      
      // Mettre en cache les données pour la prochaine fois
      if (projects.isNotEmpty) {
        _cacheService.cacheProjects(projects.map((p) => p.toJson()).toList());
      }
      
      if (projectTransactions.isNotEmpty) {
        _cacheService.cacheTransactions(null, projectTransactions.map((t) => t.toJson()).toList());
      }
      
      setState(() {
        _adminTeams = adminTeams;
        _isAdmin = showProjectSelector; // Utiliser cette valeur pour contrôler l'affichage du sélecteur
        _projectTransactions = projectTransactions;
        // Les projets sont déjà définis depuis le constructeur
        _recentTransactions = recentTransactions;
        _projectsWithBalanceAlert = projectsWithAlert;
        _totalRevenues = totalRevenues;
        _totalExpenses = totalExpenses;
        _totalBalance = totalBalance;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données du serveur: $e');
      throw e;
    }
  }
  
  // Chargement des données en arrière-plan
  Future<void> _loadDataInBackground() async {
    try {
      await _loadDataFromServer();
    } catch (e) {
      // Silencieux pour ne pas perturber l'utilisateur
      print('Erreur lors du chargement en arrière-plan: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            //const Text('Finances'),
            if (_selectedProjectId != null && _selectedProjectName.isNotEmpty)
              Text(
                '$_selectedProjectName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isAdmin && _selectedProjectId != null ? 48 : 48),
          child: Column(
            children: [
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
          // Affichage du sélecteur de projet uniquement pour les administrateurs qui peuvent gérer les budgets
          PermissionGated(
            permissionName: 'read_transaction',
            child: ProjectSelectorButton(
              onPressed: _showProjectSelector,
              showAllProjects: _showAllProjects,
              projectName: _selectedProjectName,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: PermissionGated(
        permissionName: 'create_transaction',
        projectId: _selectedProjectId,
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionFormScreen(
                  projectId: _selectedProjectId,
                ),
              ),
            );
            
            if (result != null) {
              _loadData();
            }
          },
          child: const Icon(Icons.add),
          tooltip: 'Ajouter une transaction',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProjectFinancesTab(),
                _buildAlertsTab(),
                PermissionGated(
                  permissionName: 'read_transaction',
                  projectId: _selectedProjectId,
                  child: _buildTransactionsTab(),
                ),
              ],
            ),
    );
  }
  
  // Méthode pour afficher le sélecteur de projet
  void _showProjectSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: ModernProjectSelector(
              projects: _projects,
              selectedProjectId: _selectedProjectId,
              showAllProjects: _showAllProjects,
              onProjectSelected: (projectId, showAll) {
                setState(() {
                  _showAllProjects = showAll;
                  _selectedProjectId = projectId;
                });
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }
  
  // Widget pour la carte de statistiques
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  // Onglet Vue d'ensemble
  Widget _buildOverviewTab() {
    return PermissionGated(
      permissionName: 'read_transaction',
      projectId: _selectedProjectId,
      child: RefreshIndicator(
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
                      NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(_totalRevenues),
                      Icons.arrow_upward,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Dépenses',
                      NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(_totalExpenses),
                      Icons.arrow_downward,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Solde',
                      NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(_totalBalance),
                      Icons.monetization_on,
                      _totalBalance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Graphique de répartition des dépenses
              PermissionGated(
                permissionName: 'read_transaction',
                projectId: _selectedProjectId,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildExpensesChart(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Graphique de répartition des revenus
              PermissionGated(
                permissionName: 'read_transaction',
                projectId: _selectedProjectId,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildIncomesChart(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Transactions récentes
              PermissionGated(
                permissionName: 'read_transaction',
                projectId: _selectedProjectId,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                            PermissionGated(
                              permissionName: 'read_transaction',
                              projectId: _selectedProjectId,
                              child: TextButton(
                                onPressed: () {
                                  // Aller à l'onglet Transactions
                                  _tabController.animateTo(3);
                                },
                                child: const Text('Voir tout'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRecentTransactionsList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // La méthode dispose a été déplacée plus haut
  
  // Méthode pour construire le graphique des dépenses avec gestion optimisée de l'état
  Widget _buildExpensesChart() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setLocalState) {
        // Titre différent selon le mode
        String chartTitle = _showExpenseSubcategories 
            ? 'Sous-catégories de $_selectedExpenseCategory' 
            : 'Répartition des dépenses';
        
        // Grouper les dépenses selon le mode actuel
        final Map<String, double> expensesByCategory = {};
        
        for (final transaction in _projectTransactions) {
          if (!transaction.isIncome) {
            // En mode sous-catégories, on filtre par catégorie principale
            if (_showExpenseSubcategories) {
              if (transaction.category == _selectedExpenseCategory && transaction.subcategory != null) {
                final subcategory = transaction.subcategory!;
                if (expensesByCategory.containsKey(subcategory)) {
                  expensesByCategory[subcategory] = expensesByCategory[subcategory]! + transaction.absoluteAmount;
                } else {
                  expensesByCategory[subcategory] = transaction.absoluteAmount;
                }
              }
            } else {
              // Mode normal: grouper par catégorie principale
              final category = transaction.category;
              if (expensesByCategory.containsKey(category)) {
                expensesByCategory[category] = expensesByCategory[category]! + transaction.absoluteAmount;
              } else {
                expensesByCategory[category] = transaction.absoluteAmount;
              }
            }
          }
        }
        
        // Couleurs pour le graphique
        final List<Color> colors = [
          Colors.blue,
          Colors.red,
          Colors.green,
          Colors.purple,
          Colors.orange,
          Colors.teal,
          Colors.pink,
          Colors.amber,
          Colors.indigo,
          Colors.brown,
        ];
        
        if (expensesByCategory.isEmpty) {
          // Message différent selon le mode
          String emptyMessage = _showExpenseSubcategories
              ? 'Aucune sous-catégorie pour $_selectedExpenseCategory'
              : 'Aucune dépense pour la période sélectionnée';
          
          return Column(
            children: [
              if (_showExpenseSubcategories)
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour aux catégories'),
                    onPressed: () {
                      print('=== [CHART_DRILL_DOWN] [EXPENSES] Retour aux catégories principales');
                      setLocalState(() {
                        _showExpenseSubcategories = false;
                        _selectedExpenseCategory = null;
                        _selectedExpenseCategoryNotifier.value = null;
                      });
                    },
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(emptyMessage),
                ),
              ),
            ],
          );
        }
        
        // Convertir en données pour le graphique
        final List<ChartData> chartData = [];
        
        // Calculer le montant total pour les pourcentages
        double totalAmount = expensesByCategory.values.fold(0.0, (sum, amount) => sum + amount);
        
        int colorIndex = 0;
        expensesByCategory.forEach((category, amount) {
          final percentage = (amount / totalAmount) * 100;
          final chartDataItem = ChartData(
            category,
            amount,
            colors[colorIndex % colors.length],
            percentText: '${percentage.toStringAsFixed(1)}%',
            amountText: NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount),
          );
          
          chartData.add(chartDataItem);
          colorIndex++;
        });
        
        // Trouver l'index de la catégorie sélectionnée pour l'animation d'explosion
        int explodeIndex = 0; // Par défaut c'est le premier élément
        if (_selectedExpenseCategory != null && !_showExpenseSubcategories) {
          final selectedIndex = chartData.indexWhere((data) => data.category == _selectedExpenseCategory);
          if (selectedIndex >= 0) {
            explodeIndex = selectedIndex;
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              // Déterminer taille de la police en fonction de la largeur disponible
              double titleFontSize = constraints.maxWidth < 400 ? 14.0 : 
                                     constraints.maxWidth < 600 ? 16.0 : 18.0;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Titre avec largeur limitée et text overflow
                  Expanded(
                    flex: 3,
                    child: Text(
                      chartTitle,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: _showExpenseSubcategories ? 2 : 1,
                    ),
                  ),
                  // Bouton de retour responsif
                  if (_showExpenseSubcategories) 
                    Flexible(
                      flex: 2,
                      child: constraints.maxWidth < 400 ?
                        // Version compacte pour petits écrans
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Retour aux catégories',
                          onPressed: () {
                            print('=== [CHART_DRILL_DOWN] [EXPENSES] Retour aux catégories principales via bouton');
                            setLocalState(() {
                              _showExpenseSubcategories = false;
                              _selectedExpenseCategory = null;
                              _selectedExpenseCategoryNotifier.value = null;
                            });
                          },
                        ) :
                        // Version complète pour écrans moyens et grands
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Retour'),
                          onPressed: () {
                            print('=== [CHART_DRILL_DOWN] [EXPENSES] Retour aux catégories principales via bouton');
                            setLocalState(() {
                              _showExpenseSubcategories = false;
                              _selectedExpenseCategory = null;
                              _selectedExpenseCategoryNotifier.value = null;
                            });
                          },
                        ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 24),
            // ValueListenableBuilder pour réagir aux changements de sélection sans recharger tout
            ValueListenableBuilder<String?>(
              valueListenable: _selectedExpenseCategoryNotifier,
              builder: (context, selectedCategory, _) {
                print('=== [CHART_DRILL_DOWN] [EXPENSES] Construction du graphique: ' + 
                      'catégorie sélectionnée = ${selectedCategory ?? "aucune"}, ' + 
                      'mode sous-catégories = $_showExpenseSubcategories');
                
                return SfCircularChart(
                  series: <CircularSeries>[
                    PieSeries<ChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (data, _) => data.category,
                      yValueMapper: (data, _) => data.amount, 
                      pointColorMapper: (data, _) => data.color,
                      dataLabelMapper: (data, _) => data.percentText,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        connectorLineSettings: ConnectorLineSettings(
                          type: ConnectorType.curve,
                          length: '10%',
                        ),
                      ),
                      enableTooltip: true,
                      animationDuration: 1200,
                      explode: true,
                      explodeIndex: explodeIndex,
                      explodeOffset: '5%',
                      explodeGesture: ActivationMode.singleTap,
                      onPointTap: (ChartPointDetails details) {
                        print('=== [CHART_DRILL_DOWN] [EXPENSES] Tap sur un point du graphique');
                        
                        if (details.pointIndex != null && !_showExpenseSubcategories) {
                          final categoryName = chartData[details.pointIndex!].category;
                          print('=== [CHART_DRILL_DOWN] [EXPENSES] Catégorie cliquée: $categoryName');
                          print('=== [CHART_DRILL_DOWN] [EXPENSES] Catégorie déjà sélectionnée: $_selectedExpenseCategory');
                          
                          if (categoryName == _selectedExpenseCategory) {
                            print('=== [CHART_DRILL_DOWN] [EXPENSES] Détecté second clic sur $categoryName');
                            
                            // Vérifier si cette catégorie a des sous-catégories
                            final transactions = _projectTransactions.where(
                              (t) => !t.isIncome && 
                                    t.category == categoryName && 
                                    t.subcategory != null
                            ).toList();
                            
                            print('=== [CHART_DRILL_DOWN] [EXPENSES] Transactions avec sous-catégories: ${transactions.length}');
                            
                            if (transactions.isNotEmpty) {
                              final subcategories = transactions.map((t) => t.subcategory!).toSet().toList();
                              print('=== [CHART_DRILL_DOWN] [EXPENSES] Sous-catégories: $subcategories');
                              
                              setLocalState(() {
                                print('=== [CHART_DRILL_DOWN] [EXPENSES] Activation des sous-catégories');
                                _showExpenseSubcategories = true;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Aucune sous-catégorie pour $categoryName'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // Premier clic, on marque la catégorie comme sélectionnée
                            print('=== [CHART_DRILL_DOWN] [EXPENSES] Premier clic sur $categoryName');
                            setLocalState(() {
                              _selectedExpenseCategory = categoryName;
                              _selectedExpenseCategoryNotifier.value = categoryName;
                            });
                          }
                        }
                      },
                    ),
                  ],
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  // Méthode pour construire le graphique des revenus avec gestion optimisée de l'état
  Widget _buildIncomesChart() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setLocalState) {
        String chartTitle = _showRevenueSubcategories
            ? 'Sous-catégories de $_selectedRevenueCategory'
            : 'Répartition des revenus';
        
        // Grouper les revenus selon le mode actuel
        final Map<String, double> revenuesByCategory = {};
        
        for (final transaction in _projectTransactions) {
          if (transaction.isIncome) {
            if (_showRevenueSubcategories) {
              if (transaction.category == _selectedRevenueCategory && transaction.subcategory != null) {
                final subcategory = transaction.subcategory!;
                if (revenuesByCategory.containsKey(subcategory)) {
                  revenuesByCategory[subcategory] = revenuesByCategory[subcategory]! + transaction.absoluteAmount;
                } else {
                  revenuesByCategory[subcategory] = transaction.absoluteAmount;
                }
              }
            } else {
              final category = transaction.category;
              if (revenuesByCategory.containsKey(category)) {
                revenuesByCategory[category] = revenuesByCategory[category]! + transaction.absoluteAmount;
              } else {
                revenuesByCategory[category] = transaction.absoluteAmount;
              }
            }
          }
        }
        
        final List<Color> colors = [
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.amber,
          Colors.pink,
          Colors.indigo,
          Colors.cyan,
          Colors.brown,
        ];
        
        if (revenuesByCategory.isEmpty) {
          String emptyMessage = _showRevenueSubcategories
              ? 'Aucune sous-catégorie pour $_selectedRevenueCategory'
              : 'Aucun revenu pour la période sélectionnée';
          
          return Column(
            children: [
              if (_showRevenueSubcategories)
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Retour aux catégories'),
                    onPressed: () {
                      print('=== [CHART_DRILL_DOWN] [REVENUES] Retour aux catégories principales');
                      setLocalState(() {
                        _showRevenueSubcategories = false;
                        _selectedRevenueCategory = null;
                        _selectedRevenueCategoryNotifier.value = null;
                      });
                    },
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(emptyMessage),
                ),
              ),
            ],
          );
        }
        
        final List<ChartData> chartData = [];
        double totalAmount = revenuesByCategory.values.fold(0.0, (sum, amount) => sum + amount);
        
        int colorIndex = 0;
        revenuesByCategory.forEach((category, amount) {
          final percentage = (amount / totalAmount) * 100;
          final chartDataItem = ChartData(
            category,
            amount,
            colors[colorIndex % colors.length],
            percentText: '${percentage.toStringAsFixed(1)}%',
            amountText: NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount),
          );
          
          chartData.add(chartDataItem);
          colorIndex++;
        });
        
        // Trouver l'index de la catégorie sélectionnée pour l'animation d'explosion
        int explodeIndex = 0; // Par défaut c'est le premier élément
        if (_selectedRevenueCategory != null && !_showRevenueSubcategories) {
          final selectedIndex = chartData.indexWhere((data) => data.category == _selectedRevenueCategory);
          if (selectedIndex >= 0) {
            explodeIndex = selectedIndex;
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              // Déterminer taille de la police en fonction de la largeur disponible
              double titleFontSize = constraints.maxWidth < 400 ? 14.0 : 
                                     constraints.maxWidth < 600 ? 16.0 : 18.0;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Titre avec largeur limitée et text overflow
                  Expanded(
                    flex: 3,
                    child: Text(
                      chartTitle,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: _showRevenueSubcategories ? 2 : 1,
                    ),
                  ),
                  // Bouton de retour responsif
                  if (_showRevenueSubcategories) 
                    Flexible(
                      flex: 2,
                      child: constraints.maxWidth < 400 ?
                        // Version compacte pour petits écrans
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Retour aux catégories',
                          onPressed: () {
                            print('=== [CHART_DRILL_DOWN] [REVENUES] Retour aux catégories principales via bouton');
                            setLocalState(() {
                              _showRevenueSubcategories = false;
                              _selectedRevenueCategory = null;
                              _selectedRevenueCategoryNotifier.value = null;
                            });
                          },
                        ) :
                        // Version complète pour écrans moyens et grands
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Retour'),
                          onPressed: () {
                            print('=== [CHART_DRILL_DOWN] [REVENUES] Retour aux catégories principales via bouton');
                            setLocalState(() {
                              _showRevenueSubcategories = false;
                              _selectedRevenueCategory = null;
                              _selectedRevenueCategoryNotifier.value = null;
                            });
                          },
                        ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 24),
            // ValueListenableBuilder pour réagir aux changements de sélection sans recharger tout
            ValueListenableBuilder<String?>(
              valueListenable: _selectedRevenueCategoryNotifier,
              builder: (context, selectedCategory, _) {
                print('=== [CHART_DRILL_DOWN] [REVENUES] Construction du graphique: ' + 
                      'catégorie sélectionnée = ${selectedCategory ?? "aucune"}, ' + 
                      'mode sous-catégories = $_showRevenueSubcategories');
                
                return SfCircularChart(
                  series: <CircularSeries>[
                    PieSeries<ChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (data, _) => data.category,
                      yValueMapper: (data, _) => data.amount, 
                      pointColorMapper: (data, _) => data.color,
                      dataLabelMapper: (data, _) => data.percentText,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        connectorLineSettings: ConnectorLineSettings(
                          type: ConnectorType.curve,
                          length: '10%',
                        ),
                      ),
                      enableTooltip: true,
                      animationDuration: 1200,
                      explode: true,
                      explodeIndex: explodeIndex,
                      explodeOffset: '5%',
                      explodeGesture: ActivationMode.singleTap,
                      onPointTap: (ChartPointDetails details) {
                        print('=== [CHART_DRILL_DOWN] [REVENUES] Tap sur un point du graphique');
                        
                        if (details.pointIndex != null && !_showRevenueSubcategories) {
                          final categoryName = chartData[details.pointIndex!].category;
                          print('=== [CHART_DRILL_DOWN] [REVENUES] Catégorie cliquée: $categoryName');
                          print('=== [CHART_DRILL_DOWN] [REVENUES] Catégorie déjà sélectionnée: $_selectedRevenueCategory');
                          
                          if (categoryName == _selectedRevenueCategory) {
                            print('=== [CHART_DRILL_DOWN] [REVENUES] Détecté second clic sur $categoryName');
                            
                            final transactions = _projectTransactions.where(
                              (t) => t.isIncome && 
                                    t.category == categoryName && 
                                    t.subcategory != null
                            ).toList();
                            
                            print('=== [CHART_DRILL_DOWN] [REVENUES] Transactions avec sous-catégories: ${transactions.length}');
                            
                            if (transactions.isNotEmpty) {
                              final subcategories = transactions.map((t) => t.subcategory!).toSet().toList();
                              print('=== [CHART_DRILL_DOWN] [REVENUES] Sous-catégories: $subcategories');
                              
                              setLocalState(() {
                                print('=== [CHART_DRILL_DOWN] [REVENUES] Activation des sous-catégories');
                                _showRevenueSubcategories = true;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Aucune sous-catégorie pour $categoryName'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // Premier clic, on marque la catégorie comme sélectionnée
                            print('=== [CHART_DRILL_DOWN] [REVENUES] Premier clic sur $categoryName');
                            setLocalState(() {
                              _selectedRevenueCategory = categoryName;
                              _selectedRevenueCategoryNotifier.value = categoryName;
                            });
                          }
                        }
                      },
                    ),
                  ],
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                  ),
                  tooltipBehavior: TooltipBehavior(enable: true),
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  // Méthode pour construire la liste des transactions récentes
  Widget _buildRecentTransactionsList() {
    if (_recentTransactions.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Aucune transaction récente'),
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentTransactions.length > 5 ? 5 : _recentTransactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final transaction = _recentTransactions[index];
        
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: transaction.isIncome ? Colors.green[100] : Colors.red[100],
            child: Icon(
              transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: transaction.isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            transaction.description.isNotEmpty ? transaction.description : 'Transaction sans description',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: transaction.projectName.isNotEmpty
              ? Text(
                  transaction.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              : null,
          trailing: SizedBox(
            width: 100, // Largeur fixe pour avoir assez d'espace
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Montant avec une largeur contrainte
                Expanded(
                  child: Text(
                    '${transaction.isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(transaction.absoluteAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: transaction.isIncome ? Colors.green : Colors.red,
                      fontSize: 14, // Légèrement plus petit
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Actions regroupées dans une colonne plus compacte
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton modifier avec taille réduite
                    PermissionGated(
                      permissionName: 'update_transaction',
                      projectId: transaction.projectId,
                      child: SizedBox(
                        height: 20,
                        width: 24,
                        child: IconButton(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransactionFormScreen(
                                  transaction: transaction,
                                ),
                              ),
                            );
                            
                            if (result != null) {
                              _loadData();
                            }
                          },
                          tooltip: 'Modifier',
                        ),
                      ),
                    ),
                    SizedBox(height: 4), // Petit espacement
                    // Bouton supprimer avec taille réduite
                    PermissionGated(
                      permissionName: 'delete_transaction',
                      projectId: transaction.projectId,
                      child: SizedBox(
                        height: 20,
                        width: 24,
                        child: IconButton(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirmation'),
                                content: const Text('Êtes-vous sûr de vouloir supprimer cette transaction ?'),
                                actions: [
                                  TextButton(
                                    child: const Text('Annuler'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  TextButton(
                                    child: const Text('Supprimer'),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      try {
                                        await _projectFinanceService.deleteTransaction(transaction.id);
                                        _loadData();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Transaction supprimée avec succès'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Erreur lors de la suppression: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: 'Supprimer',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Remplacer onTap par un gestionnaire qui vérifie d'abord les permissions
          onTap: () async {
            final hasPermission = await _roleService.hasPermission(
              'update_transaction',
              projectId: transaction.projectId,
            );
            
            if (hasPermission) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionFormScreen(
                    transaction: transaction,
                  ),
                ),
              );
              
              if (result != null) {
                _loadData();
              }
            }
          },
        );
      },
    );
  }
  
  // Onglet Finances des projets
  Widget _buildProjectFinancesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: _projects.isEmpty
          ? const Center(child: Text('Aucun projet trouvé'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return _buildProjectFinanceCard(project);
              },
            ),
    );
  }
  
  // Méthode pour construire la carte de finance d'un projet
  Widget _buildProjectFinanceCard(Project project) {
    // Calculer les revenus et dépenses pour ce projet
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
    
    final projectBalance = projectIncome - projectExpenses;
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Déterminer si le projet est en alerte (solde négatif)
    final bool isInAlert = projectBalance < 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isInAlert
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (isInAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Solde négatif',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du projet
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            project.description.isNotEmpty 
                                ? project.description 
                                : 'Aucune description',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Cartes de statistiques financières du projet
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Revenus',
                        currencyFormat.format(projectIncome),
                        Icons.arrow_upward,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Dépenses',
                        currencyFormat.format(projectExpenses),
                        Icons.arrow_downward,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Solde',
                        currencyFormat.format(projectBalance),
                        Icons.monetization_on,
                        projectBalance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Historique'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueGrey,
                        side: BorderSide(color: Colors.blueGrey.shade200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        // Filtrer les transactions par projet et aller à l'onglet Transactions
                        setState(() {
                          _selectedProjectId = project.id;
                          _showAllProjects = false;
                        });
                        _loadData();
                        _tabController.animateTo(3); // Aller à l'onglet Transactions
                      },
                    ),
                    const SizedBox(width: 8),
                    PermissionGated(
                      permissionName: 'create_transaction',
                      projectId: project.id,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Transaction'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          // Ajouter une transaction pour ce projet
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionFormScreen(
                                projectId: project.id,
                                initialProjectId: project.id,
                              ),
                            ),
                          );
                          
                          if (result != null) {
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Onglet Alertes
  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: _projectsWithBalanceAlert.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune alerte',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tous vos projets ont un solde positif',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _projectsWithBalanceAlert.length,
              itemBuilder: (context, index) {
                final project = _projectsWithBalanceAlert[index];
                
                // Calculer les revenus et dépenses pour ce projet
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
                
                final projectBalance = projectIncome - projectExpenses;
                final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
                
                // Déterminer si le projet est en alerte (solde négatif)
                final bool isInAlert = projectBalance < 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isInAlert
                        ? BorderSide(color: Colors.red.shade300, width: 1.5)
                        : BorderSide.none,
                  ),
                  child: Column(
                    children: [
                      if (isInAlert)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Alerte: Solde négatif',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: Text(
                                    project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Solde: ${currencyFormat.format(projectBalance)}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Détails des finances
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _buildFinanceDetailRow(
                                    'Revenus',
                                    currencyFormat.format(projectIncome),
                                    Icons.arrow_upward,
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFinanceDetailRow(
                                    'Dépenses',
                                    currencyFormat.format(projectExpenses),
                                    Icons.arrow_downward,
                                    Colors.red,
                                  ),
                                  const Divider(height: 16),
                                  _buildFinanceDetailRow(
                                    'Différence',
                                    currencyFormat.format(projectBalance),
                                    Icons.warning,
                                    Colors.red.shade700,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('Voir détails'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
                                    side: BorderSide(color: Colors.blueGrey.shade200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedProjectId = project.id;
                                      _showAllProjects = false;
                                    });
                                    _loadData();
                                    _tabController.animateTo(3); // Aller à l'onglet Transactions
                                  },
                                ),
                                PermissionGated(
                                  permissionName: 'create_transaction',
                                  projectId: project.id,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Ajouter un revenu'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () async {
                                      // Ajouter une transaction pour ce projet
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TransactionFormScreen(
                                            projectId: project.id,
                                            initialProjectId: project.id,
                                          ),
                                        ),
                                      );
                                      
                                      if (result != null) {
                                        _loadData();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
  
  // Widget pour afficher une ligne détaillée des finances
  Widget _buildFinanceDetailRow(String label, String value, IconData icon, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? color : Colors.grey[800],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
  
  // Onglet Transactions
  Widget _buildTransactionsTab() {
    if (_projectTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune transaction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des transactions pour voir l\'historique ici',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            PermissionGated(
              permissionName: 'create_transaction',
              projectId: _selectedProjectId,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une transaction'),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(
                        projectId: _selectedProjectId,
                      ),
                    ),
                  );
                  
                  if (result != null) {
                    _loadData();
                  }
                },
              ),
            ),
          ],
        ),
      );
    }
    
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Options de filtre
          Container(
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtre de date (à implémenter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Filtrer par type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: 'Toutes'),
                    Tab(text: 'Revenus'),
                    Tab(text: 'Dépenses'),
                  ],
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: TabBarView(
              children: [
                // Toutes les transactions
                _buildTransactionsList(_projectTransactions),
                // Revenus uniquement
                _buildTransactionsList(_projectTransactions.where((t) => t.isIncome).toList()),
                // Dépenses uniquement
                _buildTransactionsList(_projectTransactions.where((t) => !t.isIncome).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Méthode pour construire la liste des transactions
  Widget _buildTransactionsList(List<ProjectTransaction> transactions) {
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    
    // Obtenir la largeur de l'écran pour calculer les tailles responsive
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculer les tailles de texte en fonction de la largeur d'écran
    final double fontSizeAmount = screenWidth < 360 ? 12 : (screenWidth < 400 ? 13 : 14);
    final double iconSize = screenWidth < 360 ? 14 : 16;
    final double widthTrailing = screenWidth < 360 ? 85 : (screenWidth < 400 ? 95 : 100);
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: 1,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth < 360 ? 8 : 16, 
                vertical: screenWidth < 360 ? 4 : 8
              ),
              leading: CircleAvatar(
                backgroundColor: transaction.isIncome ? Colors.green[100] : Colors.red[100],
                child: Icon(
                  transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: transaction.isIncome ? Colors.green : Colors.red,
                ),
              ),
              title: Text(
                transaction.description.isNotEmpty ? transaction.description : 'Transaction sans description',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: screenWidth < 360 ? 13 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category, size: screenWidth < 360 ? 10 : 12, color: Colors.grey[600]),
                      SizedBox(width: screenWidth < 360 ? 2 : 4),
                      Expanded(
                        child: Text(
                          transaction.category,
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 10 : 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: screenWidth < 360 ? 6 : 12),
                      Icon(Icons.calendar_today, size: screenWidth < 360 ? 10 : 12, color: Colors.grey[600]),
                      SizedBox(width: screenWidth < 360 ? 2 : 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(transaction.transactionDate),
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 10 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (transaction.projectName.isNotEmpty)
                    SizedBox(height: screenWidth < 360 ? 2 : 4),
                  if (transaction.projectName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.group_work, size: screenWidth < 360 ? 10 : 12, color: Colors.grey[600]),
                        SizedBox(width: screenWidth < 360 ? 2 : 4),
                        Expanded(
                          child: Text(
                            transaction.projectName,
                            style: TextStyle(
                              fontSize: screenWidth < 360 ? 10 : 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: SizedBox(
                width: widthTrailing, // Largeur adaptative
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Montant avec une largeur contrainte
                    Expanded(
                      child: Text(
                        '${transaction.isIncome ? '+' : '-'}${currencyFormat.format(transaction.absoluteAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: transaction.isIncome ? Colors.green : Colors.red,
                          fontSize: fontSizeAmount, // Taille de police adaptative
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Actions regroupées dans une colonne plus compacte
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bouton modifier avec taille réduite
                        PermissionGated(
                          permissionName: 'update_transaction',
                          projectId: transaction.projectId,
                          child: SizedBox(
                            height: 20,
                            width: 24,
                            child: IconButton(
                              iconSize: iconSize, // Taille d'icône adaptative
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionFormScreen(
                                      transaction: transaction,
                                    ),
                                  ),
                                );
                                
                                if (result != null) {
                                  _loadData();
                                }
                              },
                              tooltip: 'Modifier',
                            ),
                          ),
                        ),
                        SizedBox(height: 4), // Petit espacement
                        // Bouton supprimer avec taille réduite
                        PermissionGated(
                          permissionName: 'delete_transaction',
                          projectId: transaction.projectId,
                          child: SizedBox(
                            height: 20,
                            width: 24,
                            child: IconButton(
                              iconSize: iconSize, // Taille d'icône adaptative
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmation'),
                                    content: const Text('Êtes-vous sûr de vouloir supprimer cette transaction ?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('Annuler'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      TextButton(
                                        child: const Text('Supprimer'),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          try {
                                            await _projectFinanceService.deleteTransaction(transaction.id);
                                            _loadData();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Transaction supprimée avec succès'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Erreur lors de la suppression: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              tooltip: 'Supprimer',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remplacer onTap par un gestionnaire qui vérifie d'abord les permissions
              onTap: () async {
                final hasPermission = await _roleService.hasPermission(
                  'update_transaction',
                  projectId: transaction.projectId,
                );
                
                if (hasPermission) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransactionFormScreen(
                        transaction: transaction,
                      ),
                    ),
                  );
                  
                  if (result != null) {
                    _loadData();
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }
  
  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: [FinanceScreen] - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (FinanceScreen) =====');
      print('ID utilisateur: ${user.id}');
      print('Email: ${user.email}');
      
      // Récupérer le profil utilisateur
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      if (profileResponse != null) {
        print('Nom: ${profileResponse['first_name']} ${profileResponse['last_name']}');
      }
      
      // Récupérer les rôles de l'utilisateur
      final userRolesResponse = await Supabase.instance.client
          .from('user_roles')
          .select('role_id, roles (name, description), team_id, project_id')
          .eq('user_id', user.id);
      
      print('\nRôles attribués:');
      if (userRolesResponse != null && userRolesResponse.isNotEmpty) {
        for (var roleData in userRolesResponse) {
          final roleName = roleData['roles']['name'];
          final roleDesc = roleData['roles']['description'];
          final teamId = roleData['team_id'];
          final projectId = roleData['project_id'];
          
          print('- Rôle: $roleName ($roleDesc)');
          if (teamId != null) print('  → Équipe: $teamId');
          if (projectId != null) print('  → Projet: $projectId');
          
          // Récupérer toutes les permissions pour ce rôle
          final rolePermissions = await Supabase.instance.client
              .from('role_permissions')
              .select('permissions (name, description)')
              .eq('role_id', roleData['role_id']);
          
          if (rolePermissions != null && rolePermissions.isNotEmpty) {
            print('  Permissions:');
            for (var permData in rolePermissions) {
              final permName = permData['permissions']['name'];
              final permDesc = permData['permissions']['description'];
              print('    • $permName: $permDesc');
            }
          }
        }
      } else {
        print('Aucun rôle attribué à cet utilisateur.');
      }
      
      // Vérifier spécifiquement la permission pour l'écran des finances
      final hasFinanceAccess = await _roleService.hasPermission('read_transaction');
      print('\nPermission "read_transaction" (accès finances): ${hasFinanceAccess ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }
}
