import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/phase_model.dart';
import '../../models/budget_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/user_service.dart';
import '../../services/role_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../../widgets/permission_gated.dart';

/// Widget qui vérifie les permissions avant d'afficher les statistiques pour éviter le flash de l'écran d'accès refusé
class StatisticsScreenWrapper extends StatefulWidget {
  const StatisticsScreenWrapper({super.key});

  @override
  State<StatisticsScreenWrapper> createState() => _StatisticsScreenWrapperState();
}

class _StatisticsScreenWrapperState extends State<StatisticsScreenWrapper> {
  final RoleService _roleService = RoleService();
  final ProjectService _projectService = ProjectService();
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// Vérifie la permission avant d'afficher l'écran
  Future<void> _checkPermission() async {
    try {
      // Vérifier si l'utilisateur a la permission globale read_all_projects
      final hasAllProjectsAccess = await _roleService.hasPermission('read_all_projects');
      
      if (hasAllProjectsAccess) {
        print('=== RBAC DEBUG === [StatisticsScreenWrapper] Utilisateur avec permission read_all_projects, accès autorisé');
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
        return;
      }
      
      // Récupérer les projets accessibles
      final projects = await _projectService.getAccessibleProjects();
      if (projects.isNotEmpty) {
        // Si l'utilisateur a au moins un projet accessible, autoriser l'accès
        print('=== RBAC DEBUG === [StatisticsScreenWrapper] Utilisateur avec ${projects.length} projets accessibles, accès autorisé');
        _projectId = projects.first.id;
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
        return;
      } else {
        print('=== RBAC DEBUG === [StatisticsScreenWrapper] Utilisateur sans projet accessible, accès refusé');
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Afficher un indicateur de chargement pendant la vérification
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (!_hasPermission) {
      // Afficher directement l'écran d'accès refusé
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accès refusé'),
          backgroundColor: const Color(0xFF1F4E5F),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, color: Colors.red, size: 80),
              const SizedBox(height: 20),
              const Text(
                'Vous n\'avez pas l\'autorisation d\'accéder aux statistiques',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Si l'utilisateur a la permission, afficher les statistiques
    return StatisticsScreen(projectId: _projectId);
  }
}

class StatisticsScreen extends StatefulWidget {
  final String? projectId;
  
  const StatisticsScreen({
    Key? key,
    this.projectId,
  }) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late TabController _tabController;
  final RoleService _roleService = RoleService();
  
  // Animation pour les transitions d'onglets
  final _pageTransitionDuration = const Duration(milliseconds: 300);
  
  // Statistiques générales
  int _totalProjects = 0;
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _inProgressTasks = 0;
  int _blockedTasks = 0;
  int _pendingTasks = 0;
  int _totalPhases = 0;
  double _completionRate = 0.0;
  
  // Données pour les graphiques et visualisations
  List<StatCardData> _statCards = [];
  List<TaskActivityData> _activityData = [];
  Map<String, int> _tasksByStatus = {};
  Map<String, int> _tasksByPriority = {};
  Map<String, List<Task>> _tasksByProject = {};
  Map<DateTime, List<Task>> _tasksByDueDate = {};
  List<ProjectProgressData> _projectProgressData = [];
  List<ProjectPhaseData> _projectPhaseData = [];
  List<ChartData> _statusData = [];
  List<ChartData> _priorityData = [];
  List<TaskTimelineData> _timelineData = [];
  
  // Période d'analyse
  String _selectedPeriod = 'Mois';
  final List<String> _periods = ['Semaine', 'Mois', 'Trimestre', 'Année'];
  
  // Animation controllers
  bool _showProjectDetails = false;
  String? _selectedProjectId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
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
      print('=== RBAC DEBUG === [StatisticsScreen] Chargement des données avec filtrage RBAC');
      final projectService = ProjectService();
      
      // Récupérer uniquement les projets accessibles selon les permissions RBAC
      final projects = await projectService.getAccessibleProjects();
      print('=== RBAC DEBUG === [StatisticsScreen] ${projects.length} projets accessibles récupérés');
      
      // Extraire les IDs des projets accessibles pour filtrer les tâches
      final projectIds = projects.map((p) => p.id).toList();
      print('=== RBAC DEBUG === [StatisticsScreen] IDs des projets accessibles: ${projectIds.join(", ")}');
      
      // Si aucun projet accessible, retourner des statistiques vides
      if (projectIds.isEmpty) {
        print('=== RBAC DEBUG === [StatisticsScreen] Aucun projet accessible, affichage de statistiques vides');
        setState(() {
          _isLoading = false;
          _totalProjects = 0;
          _totalTasks = 0;
          _totalPhases = 0;
          _completedTasks = 0;
          _inProgressTasks = 0;
          _blockedTasks = 0;
          _pendingTasks = 0;
          _completionRate = 0;
          _statCards = _createStatCards();
          _activityData = [];
          _statusData = [];
          _priorityData = [];
          _projectProgressData = [];
        });
        return;
      }
      
      // Récupérer uniquement les tâches des projets accessibles
      List<Task> tasks = [];
      if (projectIds.length == 1) {
        tasks = await projectService.getTasksByProject(projectIds[0]);
      } else {
        tasks = await projectService.getTasksForProjects(projectIds);
      }
      
      // Récupérer les phases des projets accessibles
      final phases = await projectService.getAllPhases();
      final accessiblePhases = phases.where((phase) => projectIds.contains(phase.projectId)).toList();
      
      _totalProjects = projects.length;
      _totalTasks = tasks.length;
      _totalPhases = accessiblePhases.length;
      
      // Compter les tâches par statut
      _tasksByStatus = {};
      for (final task in tasks) {
        final status = task.status;
        print('Statut trouvé: "$status"'); // Debug pour voir les statuts bruts
        _tasksByStatus[status] = (_tasksByStatus[status] ?? 0) + 1;
      }
      
      // Afficher tous les statuts trouvés pour débogage
      print('Tous les statuts trouvés: ${_tasksByStatus.keys.toList()}');
      
      _completedTasks = 0;
      _inProgressTasks = 0;
      _blockedTasks = 0;
      _pendingTasks = 0;
      
      for (final task in tasks) {
        final status = task.status;
        
        if (status.toLowerCase() == 'completed') {
          _completedTasks++;
        } else if (status == 'inProgress' || status == 'in_progress') {
          _inProgressTasks++;
        } else if (status.toLowerCase() == 'blocked') {
          _blockedTasks++;
        } else if (status.toLowerCase() == 'pending') {
          _pendingTasks++;
        }
      }
      
      // Calculer le taux de complétion
      _completionRate = _totalTasks > 0 ? (_completedTasks / _totalTasks) * 100 : 0;
      
      // Compter les tâches par priorité
      _tasksByPriority = {};
      for (final task in tasks) {
        final priority = _getPriorityText(task.priority);
        _tasksByPriority[priority] = (_tasksByPriority[priority] ?? 0) + 1;
      }
      
      // Compter les tâches par projet
      _tasksByProject = {};
      for (final task in tasks) {
        final projectId = task.projectId;
        final project = projects.firstWhere(
          (p) => p.id == projectId,
          orElse: () => Project(
            id: projectId,
            name: 'Projet inconnu',
            description: '',
            createdAt: DateTime.now(),
            updatedAt: null,
            createdBy: '',
            status: 'unknown',
          ),
        );
        
        final projectName = project.name;
        _tasksByProject[projectName] = (_tasksByProject[projectName] ?? [])..add(task);
      }
      
      // Compter les tâches par date d'échéance
      _tasksByDueDate = {};
      for (final task in tasks) {
        if (task.dueDate != null) {
          final dueDate = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          
          _tasksByDueDate[dueDate] = (_tasksByDueDate[dueDate] ?? [])..add(task);
        }
      }
      
      // Pour chaque projet, créer des données de progression
      _projectProgressData = [];
      _projectPhaseData = [];
      
      for (var project in projects) {
        final projectTasks = tasks.where((task) => task.projectId == project.id).toList();
        final completedTasks = projectTasks.where((task) => task.status == 'completed').length;
        final inProgressTasks = projectTasks.where((task) => task.status == 'inProgress' || task.status == 'in_progress').length;
        final pendingTasks = projectTasks.where((task) => task.status == 'pending').length;
        
        _projectProgressData.add(
          ProjectProgressData(
            projectName: project.name,
            completedTasks: completedTasks,
            inProgressTasks: inProgressTasks,
            pendingTasks: pendingTasks,
            totalTasks: projectTasks.length,
          ),
        );
        
        // Compter les phases par projet
        final projectPhases = accessiblePhases.where((phase) => phase.projectId == project.id).toList();
        _projectPhaseData.add(
          ProjectPhaseData(
            projectName: project.name,
            totalPhases: projectPhases.length,
            completedPhases: projectPhases.where((phase) => phase.status == 'completed').length,
          ),
        );
      }
      
      // Préparer les cartes de statistiques
      _statCards = _createStatCards();
      
      // Préparer les données pour le graphique circulaire
      _statusData = [];
      final statusColors = {
        'todo': Colors.grey,
        'inprogress': Colors.blue,
        'inProgress': Colors.blue,  // Support des deux formats
        'review': Colors.orange,
        'completed': Colors.green,
      };
      
      final statusLabels = {
        'todo': 'À faire',
        'inprogress': 'En cours',
        'inProgress': 'En cours',   // Support des deux formats
        'review': 'En révision',
        'completed': 'Terminée',
      };
      
      // Nettoyer les entrées de statut vides ou non reconnues
      Map<String, int> cleanedStatusMap = {};
      _tasksByStatus.forEach((status, count) {
        String cleanStatus = status.trim();
        // Ignorer les statuts vides
        if (cleanStatus.isEmpty) {
          return;
        }
        
        // Normaliser le statut "En cours" qui peut apparaître sous deux formats
        if (cleanStatus == 'in_progress') {
          cleanStatus = 'inProgress'; // Standardiser sur 'inProgress'
        }
        
        // Vérifier si c'est un statut reconnu
        if (statusLabels.containsKey(cleanStatus)) {
          cleanedStatusMap[cleanStatus] = (cleanedStatusMap[cleanStatus] ?? 0) + count;
        } else {
          print('Statut non reconnu ignoré: "$status"');
        }
      });
      
      // Utiliser uniquement les statuts nettoyés
      cleanedStatusMap.forEach((status, count) {
        final color = statusColors[status] ?? Colors.grey;
        final label = statusLabels[status] ?? 'Autre';
        
        _statusData.add(ChartData(
          label,
          count.toDouble(),
          color,
          text: count.toString(),
        ));
      });
      
      // Trier par ordre décroissant pour mettre les segments les plus grands en premier
      _statusData.sort((a, b) => b.y.compareTo(a.y));
      
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Génère les cartes de statistiques basées sur les données chargées
  List<StatCardData> _createStatCards() {
    return [
      StatCardData(
        title: 'Projets',
        value: _totalProjects,
        icon: Icons.folder,
        color: Colors.blue,
        suffix: 'projets',
      ),
      StatCardData(
        title: 'Tâches',
        value: _totalTasks,
        icon: Icons.task_alt,
        color: Colors.purple,
        suffix: 'tâches',
      ),
      StatCardData(
        title: 'Taux de complétion',
        value: _completionRate.toInt(),
        icon: Icons.pie_chart,
        color: Colors.orange,
        suffix: '%',
      ),
      StatCardData(
        title: 'Phases',
        value: _totalPhases,
        icon: Icons.view_timeline,
        color: Colors.purple,
        suffix: 'phases',
      ),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    // Afficher directement le contenu sans RbacGatedScreen
    // puisque le StatisticsScreenWrapper a déjà vérifié les permissions
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
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
            Tab(text: 'Aperçu'),
            Tab(text: 'Projets'),
            Tab(text: 'Activité'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildProjectsTab(),
                _buildActivityTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de statistiques
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Projets',
                    '$_totalProjects',
                    Icons.folder,
                    Colors.blue,
                    '$_totalPhases phases',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Tâches',
                    '$_totalTasks',
                    Icons.task_alt,
                    Colors.purple,
                    '${_completionRate.toStringAsFixed(1)}% complétées',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Complétées',
                    '$_completedTasks',
                    Icons.check_circle,
                    Colors.green,
                    'sur $_totalTasks tâches',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    '$_inProgressTasks',
                    Icons.pending_actions,
                    Colors.blue,
                    'sur $_totalTasks tâches',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Graphiques
            _buildInteractiveStatusChart(),
            
            const SizedBox(height: 24),
            
            _buildEnhancedPriorityChart(),
            
            const SizedBox(height: 24),
            
            _buildEnhancedTimelineChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, [String subtitle = '']) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de statistiques
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Projets',
                    '$_totalProjects',
                    Icons.folder,
                    Colors.blue,
                    '$_totalPhases phases',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Tâches',
                    '$_totalTasks',
                    Icons.task_alt,
                    Colors.purple,
                    '${_completionRate.toStringAsFixed(1)}% complétées',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Complétées',
                    '$_completedTasks',
                    Icons.check_circle,
                    Colors.green,
                    'sur $_totalTasks tâches',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    '$_inProgressTasks',
                    Icons.pending_actions,
                    Colors.blue,
                    'sur $_totalTasks tâches',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Graphiques
            _buildProjectProgressChart(),
            
            const SizedBox(height: 24),
            
            _buildProjectPhasesChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de statistiques
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Projets',
                    '$_totalProjects',
                    Icons.folder,
                    Colors.blue,
                    '$_totalPhases phases',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Tâches',
                    '$_totalTasks',
                    Icons.task_alt,
                    Colors.purple,
                    '${_completionRate.toStringAsFixed(1)}% complétées',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Complétées',
                    '$_completedTasks',
                    Icons.check_circle,
                    Colors.green,
                    'sur $_totalTasks tâches',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'En cours',
                    '$_inProgressTasks',
                    Icons.pending_actions,
                    Colors.blue,
                    'sur $_totalTasks tâches',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Graphiques
            _buildEnhancedTimelineChart(),
            
            const SizedBox(height: 24),
            
            _buildCompletionTrendsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPhasesChart() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(
            majorGridLines: const MajorGridLines(width: 0),
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
          primaryYAxis: NumericAxis(
            axisLine: const AxisLine(width: 0),
            labelFormat: '{value}',
            title: AxisTitle(text: 'Nombre de phases'),
          ),
          series: <CartesianSeries>[
            ColumnSeries<ProjectPhaseData, String>(
              dataSource: _projectPhaseData,
              xValueMapper: (ProjectPhaseData data, _) => data.projectName,
              yValueMapper: (ProjectPhaseData data, _) => data.totalPhases,
              pointColorMapper: (ProjectPhaseData data, _) => 
                  Color.fromRGBO(
                      (data.projectName.hashCode * 40) % 255, 
                      (data.projectName.hashCode * 70) % 255, 
                      (data.projectName.hashCode * 90) % 255, 
                      1),
              dataLabelMapper: (ProjectPhaseData data, _) => '${data.totalPhases}',
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.outer,
              ),
              width: 0.6,
              spacing: 0.1,
              borderRadius: BorderRadius.circular(8),
              animationDuration: 1200,
            ),
          ],
          tooltipBehavior: TooltipBehavior(enable: true),
        ),
      ),
    );
  }

  Widget _buildCompletionTrendsChart() {
    final now = DateTime.now();
    final weekData = [
      {'jour': 'Lun', 'ajoutées': 4, 'complétées': 2},
      {'jour': 'Mar', 'ajoutées': 3, 'complétées': 4},
      {'jour': 'Mer', 'ajoutées': 5, 'complétées': 3},
      {'jour': 'Jeu', 'ajoutées': 2, 'complétées': 5},
      {'jour': 'Ven', 'ajoutées': 4, 'complétées': 3},
      {'jour': 'Sam', 'ajoutées': 1, 'complétées': 2},
      {'jour': 'Dim', 'ajoutées': 0, 'complétées': 1},
    ];
    
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(),
          tooltipBehavior: TooltipBehavior(enable: true),
          legend: Legend(isVisible: true),
          series: <CartesianSeries>[
            LineSeries<Map<String, dynamic>, String>(
              dataSource: weekData,
              xValueMapper: (data, _) => data['jour'],
              yValueMapper: (data, _) => data['ajoutées'],
              name: 'Tâches ajoutées',
              color: Colors.blue,
              markerSettings: const MarkerSettings(isVisible: true),
            ),
            LineSeries<Map<String, dynamic>, String>(
              dataSource: weekData,
              xValueMapper: (data, _) => data['jour'],
              yValueMapper: (data, _) => data['complétées'],
              name: 'Tâches complétées',
              color: Colors.green,
              markerSettings: const MarkerSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectProgressChart() {
    if (_tasksByProject.isEmpty) {
      return _buildEmptyChart('Aucun projet avec des tâches');
    }
    
    // Limiter à 5 projets maximum pour la lisibilité
    final Map<String, int> topProjects = {};
    final sortedProjects = _tasksByProject.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    
    for (int i = 0; i < sortedProjects.length && i < 5; i++) {
      topProjects[sortedProjects[i].key] = sortedProjects[i].value.length;
    }
    
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Nombre de tâches'),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, int>, String>(
                    dataSource: topProjects.entries.toList(),
                    xValueMapper: (entry, _) => entry.key,
                    yValueMapper: (entry, _) => entry.value,
                    name: 'Tâches',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                    ),
                    pointColorMapper: (entry, index) => 
                        Colors.primaries[index % Colors.primaries.length],
                    onPointTap: (ChartPointDetails details) {
                      // Afficher détails du projet
                      final projectName = topProjects.keys.elementAt(details.pointIndex!);
                      setState(() {
                        _showProjectDetails = true;
                        _selectedProjectId = projectName;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        
        if (_showProjectDetails && _selectedProjectId != null) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Détails du projet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showProjectDetails = false;
                            _selectedProjectId = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Animation de progression
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 0.7),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Progression globale'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(10),
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text('${(value * 100).toInt()}%'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveStatusChart() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCircularChart(
          title: ChartTitle(
            text: 'Répartition des tâches',
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
            overflowMode: LegendItemOverflowMode.wrap,
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CircularSeries<ChartData, String>>[
            DoughnutSeries<ChartData, String>(
              dataSource: _statusData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              dataLabelMapper: (ChartData data, _) => data.text,
              pointColorMapper: (ChartData data, _) => data.color,
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
              explodeIndex: 0,
              explodeOffset: '5%',
              explodeGesture: ActivationMode.singleTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPriorityChart() {
    if (_totalTasks == 0) {
      return _buildEmptyChart('Aucune tâche disponible');
    }
    
    final List<ChartData> chartData = [];
    
    final priorityColors = {
      'Faible': Colors.green,
      'Normale': Colors.blue,
      'Élevée': Colors.orange,
      'Urgente': Colors.red,
    };
    
    _tasksByPriority.forEach((priority, count) {
      final color = priorityColors[priority] ?? Colors.grey;
      chartData.add(ChartData(
        priority,
        count.toDouble(),
        color,
        text: '$count',
      ));
    });
    
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: CategoryAxis(
            majorGridLines: const MajorGridLines(width: 0),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          primaryYAxis: NumericAxis(
            axisLine: const AxisLine(width: 0),
            labelFormat: '{value}',
            majorTickLines: const MajorTickLines(size: 0),
          ),
          series: <CartesianSeries>[
            ColumnSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              pointColorMapper: (ChartData data, _) => data.color,
              dataLabelMapper: (ChartData data, _) => data.text,
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.outer,
              ),
              width: 0.6,
              spacing: 0.2,
              borderRadius: BorderRadius.circular(10),
              animationDuration: 1200,
            ),
          ],
          tooltipBehavior: TooltipBehavior(enable: true),
        ),
      ),
    );
  }

  Widget _buildEnhancedTimelineChart() {
    if (_tasksByDueDate.isEmpty) {
      return _buildEmptyChart('Aucune tâche avec date d\'échéance');
    }
    
    // Trier les dates et limiter aux 30 prochains jours
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));
    
    final Map<DateTime, int> filteredDates = {};
    _tasksByDueDate.forEach((date, tasks) {
      if (date.isAfter(now) && date.isBefore(thirtyDaysLater)) {
        filteredDates[date] = tasks.length;
      }
    });
    
    if (filteredDates.isEmpty) {
      return _buildEmptyChart('Aucune tâche dans les 30 prochains jours');
    }
    
    // Créer les données pour le graphique
    final List<TaskTimelineData> timelineData = [];
    final sortedDates = filteredDates.keys.toList()..sort();
    
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      timelineData.add(TaskTimelineData(
        date: date,
        count: filteredDates[date]!,
      ));
    }
    
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat('dd/MM'),
            intervalType: DateTimeIntervalType.days,
            majorGridLines: const MajorGridLines(width: 0),
            title: AxisTitle(text: 'Date d\'échéance'),
          ),
          primaryYAxis: NumericAxis(
            axisLine: const AxisLine(width: 0),
            labelFormat: '{value}',
            majorTickLines: const MajorTickLines(size: 0),
            title: AxisTitle(text: 'Nombre de tâches'),
          ),
          series: <CartesianSeries>[
            ColumnSeries<TaskTimelineData, DateTime>(
              dataSource: timelineData,
              xValueMapper: (TaskTimelineData data, _) => data.date,
              yValueMapper: (TaskTimelineData data, _) => data.count,
              pointColorMapper: (TaskTimelineData data, _) => 
                data.isOverdue ? Colors.redAccent : const Color(0xFF1F4E5F),
              dataLabelMapper: (TaskTimelineData data, _) => '${data.count}',
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.top,
              ),
              width: 0.6,
              borderRadius: BorderRadius.circular(4),
              animationDuration: 1200,
            ),
          ],
          tooltipBehavior: TooltipBehavior(enable: true),
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return SizedBox(
      height: 250,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bar_chart_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 0:
        return 'Faible';
      case 1:
        return 'Normale';
      case 2:
        return 'Élevée';
      case 3:
        return 'Urgente';
      default:
        return 'Inconnue';
    }
  }

  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: StatisticsScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (StatisticsScreen) =====');
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
      
      // Vérifier spécifiquement la permission pour l'écran des statistiques
      final hasStatisticsAccess = await _roleService.hasPermission('read_all_projects');
      print('\nPermission "read_all_projects" (accès statistiques): ${hasStatisticsAccess ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }
}

// Classes de données pour les visualisations
class StatCardData {
  final IconData icon;
  final String title;
  final dynamic value;
  final Color color;
  final String? secondaryValue;
  final String? suffix;

  StatCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.secondaryValue,
    this.suffix,
  });
}

class TaskActivityData {
  final DateTime date;
  final int count;

  TaskActivityData({
    required this.date,
    required this.count,
  });
}

class ChartData {
  final String x;
  final double y;
  final Color color;
  final String text;

  ChartData(this.x, this.y, this.color, {this.text = ''});
}

class TaskTimelineData {
  final DateTime date;
  final int count;
  final bool isOverdue;

  TaskTimelineData({
    required this.date,
    required this.count,
    this.isOverdue = false,
  });
}

class ProjectProgressData {
  final String projectName;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int totalTasks;
  
  ProjectProgressData({
    required this.projectName,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.totalTasks,
  });
}

class ProjectPhaseData {
  final String projectName;
  final int totalPhases;
  final int completedPhases;
  
  ProjectPhaseData({
    required this.projectName,
    required this.totalPhases,
    required this.completedPhases,
  });
}
