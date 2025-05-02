import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/phase_model.dart';
import '../../models/project_transaction_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/user_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/budget_service.dart';
import '../../services/role_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../../widgets/budget_summary_widget.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../../widgets/permission_gated.dart';
import '../tasks/task_form_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../budget/budget_allocation_screen.dart';
import '../budget/transaction_form_screen.dart';
import 'phases/phases_screen.dart';
import 'project_form_screen.dart';
import '../../widgets/custom_app_bar.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final UserService _userService = UserService();
  final PhaseService _phaseService = PhaseService();
  final BudgetService _budgetService = BudgetService();
  final RoleService _roleService = RoleService();
  
  Project? _project;
  List<Task> _tasks = [];
  List<Team> _projectTeams = [];
  List<Phase> _projectPhases = [];
  List<ProjectTransaction> _projectTransactions = [];
  
  bool _isLoading = true;
  bool _isLoadingTeams = true;
  bool _isLoadingPhases = true;
  bool _isLoadingBudget = true;
  bool _hasProjectAccess = false; 
  String? _errorMessage;
  
  // État des phases dépliées/repliées
  final Map<String, bool> _expandedPhases = {};
  
  // Cartes des filtres et recherche par phase - stocke les états de filtre pour chaque phase
  final Map<String, String> _searchQueries = {};
  final Map<String, String?> _statusFilters = {};
  final Map<String, String?> _priorityFilters = {};
  final Map<String, String?> _sortOptions = {};
  
  // Variables pour les tâches sans phase
  String _noPhaseSearchQuery = '';
  String? _noPhaseStatusFilter;
  String? _noPhasePriorityFilter;
  String? _noPhaseSortOption = 'newest';

  // Map pour stocker les noms d'utilisateurs
  Map<String, String> _userDisplayNames = {};
  List<Team> _assignedTeams = [];
  
  @override
  void initState() {
    super.initState();
    _checkProjectAccess(); 
  }

  /// Vérifie si l'utilisateur a accès au projet actuel
  Future<void> _checkProjectAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Récupérer les rôles de l'utilisateur avec les projets associés
      final userRolesDetails = await _roleService.getUserRolesDetails();
      
      // Vérifier si l'utilisateur a un rôle system_admin (accès global)
      final isSystemAdmin = userRolesDetails.any((role) => role['role_name'] == 'system_admin');
      
      // Si l'utilisateur est admin système, il a un accès complet
      if (isSystemAdmin) {
        print('DEBUG: Utilisateur system_admin, accès au projet accordé');
        setState(() {
          _hasProjectAccess = true;
        });
        _loadProjectDetails(); 
        return;
      }
      
      // Vérifier si l'utilisateur a une permission directe sur ce projet spécifique
      final hasProjectPermission = await _roleService.hasPermission(
        'read_project',
        projectId: widget.projectId
      );
      
      if (hasProjectPermission) {
        print('DEBUG: Utilisateur a une permission directe sur ce projet');
        setState(() {
          _hasProjectAccess = true;
        });
        _loadProjectDetails(); 
        return;
      }
      
      // Vérifier si l'utilisateur a un rôle associé à ce projet spécifique
      final hasProjectRole = userRolesDetails.any((role) => 
        role['project_id'] == widget.projectId
      );
      
      if (hasProjectRole) {
        print('DEBUG: Utilisateur a un rôle associé à ce projet');
        setState(() {
          _hasProjectAccess = true;
        });
        _loadProjectDetails(); 
        return;
      }
      
      // Vérifier si l'utilisateur pourrait accéder via une équipe associée au projet
      final hasTeamAccess = await _checkTeamProjectAccess();
      
      if (hasTeamAccess) {
        setState(() {
          _hasProjectAccess = true;
        });
        _loadProjectDetails(); 
        return;
      }
      
      // Aucun accès trouvé
      setState(() {
        _hasProjectAccess = false;
        _isLoading = false;
      });
      
    } catch (e) {
      print('ERROR: Erreur lors de la vérification de l\'accès au projet: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la vérification de l\'accès au projet: $e';
        _isLoading = false;
        _hasProjectAccess = false;
      });
    }
  }
  
  /// Vérifie si l'utilisateur a accès au projet via une équipe
  Future<bool> _checkTeamProjectAccess() async {
    try {
      // Récupérer les équipes associées au projet
      final projectTeams = await _teamService.getTeamsByProject(widget.projectId);
      
      if (projectTeams.isEmpty) {
        return false;
      }
      
      // Vérifier pour chaque équipe si l'utilisateur a la permission read_project dans cette équipe
      for (final team in projectTeams) {
        final hasTeamPermission = await _roleService.hasPermission(
          'read_project',
          teamId: team.id
        );
        
        if (hasTeamPermission) {
          print('DEBUG: Utilisateur a accès au projet via l\'équipe ${team.id}');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('ERROR: Erreur lors de la vérification de l\'accès via équipes: $e');
      return false;
    }
  }

  Future<void> _loadProjectDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final project = await _projectService.getProjectById(widget.projectId);
      final tasks = await _projectService.getTasksByProject(widget.projectId);
      
      setState(() {
        _project = project;
        _tasks = tasks;
        _isLoading = false;
      });
      
      // Récupérer tous les IDs d'utilisateurs (créateurs et assignés)
      final Set<String> userIds = {project.createdBy};
      for (final task in tasks) {
        userIds.add(task.createdBy);
        if (task.assignedTo != null) {
          userIds.add(task.assignedTo!);
        }
      }
      
      // Récupérer les noms d'affichage en une seule requête
      final userDisplayNames = await _userService.getUsersDisplayNames(userIds.toList());
      setState(() {
        _userDisplayNames = userDisplayNames;
      });
      
      // Charger les équipes et les phases en parallèle
      _loadProjectTeams();
      
      // Charger les phases en premier, puis le budget après, car la mise à jour du budget
      // dépend des phases déjà chargées
      await _loadProjectPhases();
      _loadProjectBudget();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement du projet: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadProjectTeams() async {
    setState(() {
      _isLoadingTeams = true;
    });
    
    try {
      final teams = await _teamService.getTeamsByProject(widget.projectId);
      setState(() {
        _projectTeams = teams;
        _isLoadingTeams = false;
        _assignedTeams = teams;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des équipes: $e';
        _isLoadingTeams = false;
      });
    }
  }

  Future<void> _loadProjectPhases() async {
    if (_project == null) return;

    setState(() {
      _isLoadingPhases = true;
    });

    try {
      final phases = await _phaseService.getPhasesByProject(_project!.id);
      
      setState(() {
        _projectPhases = phases;
        _isLoadingPhases = false;
        
        // Initialiser toutes les phases comme repliées par défaut
        for (var phase in _projectPhases) {
          _expandedPhases[phase.id] = false;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingPhases = false;
        _errorMessage = 'Erreur lors du chargement des phases: $e';
      });
    }
  }

  Future<void> _loadProjectBudget() async {
    if (_project == null) return;

    setState(() {
      _isLoadingBudget = true;
    });

    try {
      final transactions = await _budgetService.getTransactionsByProject(_project!.id);
      
      setState(() {
        _projectTransactions = transactions;
        _isLoadingBudget = false;
        
        // Mettre à jour les budgets des phases avec les données de transactions
        _updatePhasesBudgetFromTransactions();
      });
    } catch (e) {
      setState(() {
        _isLoadingBudget = false;
        _errorMessage = 'Erreur lors du chargement du budget: $e';
      });
    }
  }

  // Méthode pour calculer et mettre à jour les budgets des phases à partir des transactions
  void _updatePhasesBudgetFromTransactions() {
    // Créer une map pour suivre les transactions de chaque phase
    Map<String, List<ProjectTransaction>> transactionsByPhase = {};
    
    // Regrouper les transactions par phase
    for (var transaction in _projectTransactions) {
      if (transaction.phaseId != null) {
        if (!transactionsByPhase.containsKey(transaction.phaseId)) {
          transactionsByPhase[transaction.phaseId!] = [];
        }
        transactionsByPhase[transaction.phaseId!]!.add(transaction);
      }
    }
    
    // Mettre à jour les données budgétaires pour chaque phase
    List<Phase> updatedPhases = [];
    
    for (var phase in _projectPhases) {
      double budgetAllocated = phase.budgetAllocated ?? 0;
      double budgetConsumed = phase.budgetConsumed ?? 0;
      
      // Si la phase a des transactions, recalculer ses données budgétaires
      if (transactionsByPhase.containsKey(phase.id)) {
        final phaseTransactions = transactionsByPhase[phase.id]!;
        
        // Pour le budget alloué, utiliser soit la valeur existante, soit calculer à partir des revenus
        if (budgetAllocated == 0) {
          double allocatedFromTransactions = phaseTransactions
              .where((tx) => tx.isIncome)
              .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
          
          if (allocatedFromTransactions > 0) {
            budgetAllocated = allocatedFromTransactions;
          }
        }
        
        // Pour le budget consommé, utiliser soit la valeur existante, soit calculer à partir des dépenses
        // IMPORTANT: Assurons-nous que budgetConsumed est bien la valeur CONSOMMÉE (dépensée) et non le reste
        budgetConsumed = phaseTransactions
            .where((tx) => !tx.isIncome)
            .fold(0.0, (sum, tx) => sum + tx.absoluteAmount);
      }
      
      // Si le budget alloué est toujours 0 mais que nous avons un budget de projet, allouer une part égale à chaque phase
      if (budgetAllocated == 0 && _project!.budgetAllocated != null && _project!.budgetAllocated! > 0) {
        budgetAllocated = _project!.budgetAllocated! / _projectPhases.length;
      }
      
      // Mettre à jour la phase avec les nouvelles valeurs budgétaires
      updatedPhases.add(phase.copyWith(
        budgetAllocated: budgetAllocated,
        budgetConsumed: budgetConsumed,
      ));
    }
    
    // Mettre à jour la liste des phases
    setState(() {
      _projectPhases = updatedPhases;
    });
  }

  // Méthode pour filtrer les tâches en fonction des critères de recherche et de filtrage
  List<Task> _filterTasks(List<Task> tasks, String searchQuery, String? statusFilter, String? priorityFilter, String? sortOption) {
    // Si tous les filtres sont vides, retourner la liste originale
    if (searchQuery.isEmpty && statusFilter == null && priorityFilter == null && (sortOption == null || sortOption.isEmpty)) {
      return tasks;
    }
    
    // Filtrer par terme de recherche
    var filteredTasks = tasks;
    if (searchQuery.isNotEmpty) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      filteredTasks = filteredTasks.where((task) {
        return task.title.toLowerCase().contains(lowerCaseQuery) || 
               (task.description?.toLowerCase().contains(lowerCaseQuery) ?? false);
      }).toList();
    }
    
    // Filtrer par statut
    if (statusFilter != null && statusFilter.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) {
        // Gestion des différentes syntaxes pour "En cours"
        if (statusFilter == 'in_progress') {
          return task.status == 'in_progress' || task.status == 'inProgress';
        }
        return task.status == statusFilter;
      }).toList();
    }
    
    // Filtrer par priorité
    if (priorityFilter != null && priorityFilter.isNotEmpty) {
      // Conversion de la chaîne de priorité en valeur numérique
      int? priorityValue;
      switch (priorityFilter) {
        case 'low':
          priorityValue = 0; // TaskPriority.low.value
          break;
        case 'medium':
          priorityValue = 1; // TaskPriority.medium.value
          break;
        case 'high':
          priorityValue = 2; // TaskPriority.high.value
          break;
        case 'urgent':
          priorityValue = 3; // TaskPriority.urgent.value
          break;
      }
      
      if (priorityValue != null) {
        filteredTasks = filteredTasks.where((task) => task.priority == priorityValue).toList();
      }
    }
    
    // Trier les tâches
    if (sortOption != null && sortOption.isNotEmpty) {
      switch (sortOption) {
        case 'newest':
          filteredTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'oldest':
          filteredTasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'deadline_asc':
          filteredTasks.sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            return a.dueDate!.compareTo(b.dueDate!);
          });
          break;
        case 'deadline_desc':
          filteredTasks.sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            return b.dueDate!.compareTo(a.dueDate!);
          });
          break;
      }
    }
    
    return filteredTasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _project?.name ?? 'Détails du projet',
        actions: _hasProjectAccess && _project != null ? [
          // Action d'édition (si l'utilisateur a la permission)
          PermissionGated(
            permissionName: 'update_project',
            projectId: widget.projectId,
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectFormScreen(project: _project),
                  ),
                );
                if (result == true) {
                  _loadProjectDetails();
                }
              },
            ),
          ),
          // Action de suppression (si l'utilisateur a la permission)
          PermissionGated(
            permissionName: 'delete_project',
            projectId: widget.projectId,
            child: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmationDialog();
              },
            ),
          ),
        ] : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : !_hasProjectAccess
                  ? _buildAccessDeniedWidget()
                  : _buildProjectDetails(),
      floatingActionButton: _hasProjectAccess && _project != null
        ? PermissionGated(
            permissionName: 'create_phase',
            projectId: widget.projectId,
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhasesScreen(
                      project: _project!,
                    ),
                  ),
                );
                if (result == true) {
                  _loadProjectPhases();
                }
              },
              tooltip: 'Ajouter une phase',
              child: const Icon(Icons.add),
            ),
          )
        : null,
    );
  }
  
  Widget _buildAccessDeniedWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Accès refusé',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Vous n\'avez pas l\'autorisation d\'accéder à ce projet.\nContactez un administrateur si vous pensez qu\'il s\'agit d\'une erreur.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? 'Une erreur inconnue est survenue',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkProjectAccess,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProjectDetails() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadProjectDetails();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProjectHeader(),
            const SizedBox(height: 16),
            _buildProjectInfo(),
            const SizedBox(height: 24),
            _buildPhasesWithTasksSection(),
            const SizedBox(height: 24),
            _buildBudgetSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader() {
    // Calculer les statistiques du projet
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((task) => 
        TaskStatus.fromValue(task.status) == TaskStatus.completed).length;
    final totalPhases = _projectPhases.length;
    final completedPhases = _projectPhases.where((phase) => 
        PhaseStatus.fromValue(phase.status) == PhaseStatus.completed).length;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _project!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_project!.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _project!.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  'Phases',
                  '$completedPhases/$totalPhases',
                  Icons.layers,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Tâches',
                  '$completedTasks/$totalTasks',
                  Icons.task_alt,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Équipes',
                  '${_projectTeams.length}',
                  Icons.people,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Créé par', _userDisplayNames[_project!.createdBy] ?? _project!.createdBy),
            _buildInfoRow('Créé le', _formatDate(_project!.createdAt)),
            if (_project!.updatedAt != null)
              _buildInfoRow('Mis à jour le', _formatDate(_project!.updatedAt!)),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Section des équipes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Équipes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_projectTeams.isNotEmpty)
                  Text(
                    '${_projectTeams.length}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingTeams
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _projectTeams.isEmpty
                    ? const Text(
                        'Aucune équipe assignée à ce projet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _projectTeams.map((team) => Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              team.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          label: Text(team.name),
                          backgroundColor: Colors.grey[200],
                        )).toList(),
                      ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhasesWithTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Phases et Tâches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isLoadingPhases && _projectPhases.isEmpty)
              PermissionGated(
                permissionName: 'create_phase',
                projectId: widget.projectId,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhasesScreen(
                          project: _project!,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadProjectPhases();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une phase'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingPhases)
          const Center(child: CircularProgressIndicator())
        else if (_projectPhases.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune phase définie pour ce projet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les phases vous permettent d\'organiser votre projet en étapes distinctes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhasesScreen(
                            project: _project!,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadProjectPhases();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une phase'),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _projectPhases.length,
            (index) => _buildPhaseWithTasksCard(_projectPhases[index]),
          ),
        
        // Afficher les tâches sans phase à la fin
        if (!_isLoading && _tasks.isNotEmpty)
          Column(
            children: [
              const SizedBox(height: 24),
              _buildTasksWithoutPhaseSection(),
            ],
          ),
      ],
    );
  }

  Widget _buildPhaseWithTasksCard(Phase phase) {
    final phaseStatus = PhaseStatus.fromValue(phase.status);
    final tasks = _tasks.where((task) => task.phaseId == phase.id).toList();
    final completedTasks = tasks.where((task) => TaskStatus.fromValue(task.status) == TaskStatus.completed).length;
    
    // Vérifier si cette phase est dépliée ou repliée
    final isExpanded = _expandedPhases[phase.id] ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: phaseStatus.getColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la phase - cliquable pour replier/déplier
          InkWell(
            onTap: () {
              setState(() {
                _expandedPhases[phase.id] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: phaseStatus.getColor().withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: phaseStatus.getColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                phase.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: phaseStatus.getColor().withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: phaseStatus.getColor(),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                phaseStatus.getText(),
                                style: TextStyle(
                                  color: phaseStatus.getColor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (phase.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            phase.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Icône de flèche pour indiquer l'état replié/déplié
                  IconButton(
                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _expandedPhases[phase.id] = !isExpanded;
                      });
                    },
                  ),
                  PermissionGated(
                    permissionName: 'update_phase',
                    projectId: phase.projectId,
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhasesScreen(
                              project: _project!,
                              initialPhase: phase,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadProjectPhases();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Progression de la phase - toujours visible
          if (tasks.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, isExpanded ? 0 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progression: $completedTasks/${tasks.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${(completedTasks / tasks.length * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: tasks.isEmpty ? 0 : completedTasks / tasks.length,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(phaseStatus.getColor()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Budget de la phase - si des données budgétaires sont disponibles
          if (phase.budgetAllocated != null && phase.budgetAllocated! > 0 && phase.budgetConsumed != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, isExpanded ? 0 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget: ${phase.budgetConsumed!.toStringAsFixed(0)}/${phase.budgetAllocated!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${(phase.budgetConsumed! / phase.budgetAllocated! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getBudgetColor(phase.budgetConsumed! / phase.budgetAllocated! * 100),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: phase.budgetConsumed! / phase.budgetAllocated!,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(_getBudgetColor(phase.budgetConsumed! / phase.budgetAllocated! * 100)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Liste des tâches - visible uniquement si déplié
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTasksSection(phase),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(Phase phase) {
    // Récupérer toutes les tâches de cette phase
    final allPhaseTasks = _tasks.where((task) => task.phaseId == phase.id).toList();
    
    // Initialiser les filtres pour cette phase si nécessaire
    if (!_searchQueries.containsKey(phase.id)) {
      _searchQueries[phase.id] = '';
    }
    if (!_statusFilters.containsKey(phase.id)) {
      _statusFilters[phase.id] = null;
    }
    if (!_priorityFilters.containsKey(phase.id)) {
      _priorityFilters[phase.id] = null;
    }
    if (!_sortOptions.containsKey(phase.id)) {
      _sortOptions[phase.id] = 'newest';
    }
    
    // Appliquer les filtres et le tri
    final tasks = _filterTasks(
      allPhaseTasks,
      _searchQueries[phase.id] ?? '',
      _statusFilters[phase.id],
      _priorityFilters[phase.id],
      _sortOptions[phase.id],
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tâches (${allPhaseTasks.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                // Vérifier la permission avant d'ouvrir le formulaire d'ajout de tâche
                final hasPermission = await _roleService.hasPermission('create_task', projectId: _project!.id);
                if (!hasPermission) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vous n\'avez pas la permission de créer une tâche'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskFormScreen(projectId: _project!.id, phaseId: phase.id),
                  ),
                );
                if (result == true) {
                  _loadProjectDetails();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher des tâches...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQueries[phase.id] = value;
              });
            },
            controller: TextEditingController(text: _searchQueries[phase.id]),
          ),
        ),
        
        // Options de filtrage et tri
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtre par statut
                Container(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: PopupMenuButton<String?>(
                    initialValue: _statusFilters[phase.id],
                    onSelected: (value) {
                      setState(() {
                        _statusFilters[phase.id] = value == 'all' ? null : value;
                      });
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String?>(
                        value: null,
                        child: Text('Tous les statuts'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'todo',
                        child: Text('À faire'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'in_progress',
                        child: Text('En cours'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'review',
                        child: Text('En révision'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'completed',
                        child: Text('Terminée'),
                      ),
                    ],
                    child: Chip(
                      label: Text(
                        _statusFilters[phase.id] == null
                            ? 'Statut'
                            : _statusFilters[phase.id] == 'todo'
                                ? 'À faire'
                                : _statusFilters[phase.id] == 'in_progress'
                                    ? 'En cours'
                                    : _statusFilters[phase.id] == 'review'
                                        ? 'En révision'
                                        : 'Terminée',
                      ),
                      deleteIcon: _statusFilters[phase.id] == null
                          ? null
                          : const Icon(Icons.close, size: 18),
                      onDeleted: _statusFilters[phase.id] == null
                          ? null
                          : () {
                              setState(() {
                                _statusFilters[phase.id] = null;
                              });
                            },
                    ),
                  ),
                ),
                
                // Filtre par priorité
                Container(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: PopupMenuButton<String?>(
                    initialValue: _priorityFilters[phase.id],
                    onSelected: (value) {
                      setState(() {
                        _priorityFilters[phase.id] = value == 'all' ? null : value;
                      });
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String?>(
                        value: null,
                        child: Text('Toutes les priorités'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'low',
                        child: Text('Basse'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'medium',
                        child: Text('Moyenne'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'high',
                        child: Text('Haute'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'urgent',
                        child: Text('Urgente'),
                      ),
                    ],
                    child: Chip(
                      label: Text(
                        _priorityFilters[phase.id] == null
                            ? 'Priorité'
                            : _priorityFilters[phase.id] == 'low'
                                ? 'Basse'
                                : _priorityFilters[phase.id] == 'medium'
                                    ? 'Moyenne'
                                    : _priorityFilters[phase.id] == 'high'
                                        ? 'Haute'
                                        : 'Urgente',
                      ),
                      deleteIcon: _priorityFilters[phase.id] == null
                          ? null
                          : const Icon(Icons.close, size: 18),
                      onDeleted: _priorityFilters[phase.id] == null
                          ? null
                          : () {
                              setState(() {
                                _priorityFilters[phase.id] = null;
                              });
                            },
                    ),
                  ),
                ),
                
                // Options de tri
                Container(
                  child: PopupMenuButton<String>(
                    initialValue: _sortOptions[phase.id],
                    onSelected: (value) {
                      setState(() {
                        _sortOptions[phase.id] = value;
                      });
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'newest',
                        child: Text('Plus récent d\'abord'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'oldest',
                        child: Text('Plus ancien d\'abord'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'deadline_asc',
                        child: Text('Échéance (croissant)'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'deadline_desc',
                        child: Text('Échéance (décroissant)'),
                      ),
                    ],
                    child: Chip(
                      label: Text(
                        _sortOptions[phase.id] == 'newest'
                            ? 'Plus récent'
                            : _sortOptions[phase.id] == 'oldest'
                                ? 'Plus ancien'
                                : _sortOptions[phase.id] == 'deadline_asc'
                                    ? 'Échéance ↑'
                                    : 'Échéance ↓',
                      ),
                    ),
                  ),
                ),
                
                // Bouton pour réinitialiser les filtres
                if (_searchQueries[phase.id]!.isNotEmpty ||
                    _statusFilters[phase.id] != null ||
                    _priorityFilters[phase.id] != null ||
                    _sortOptions[phase.id] != 'newest')
                  Container(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQueries[phase.id] = '';
                          _statusFilters[phase.id] = null;
                          _priorityFilters[phase.id] = null;
                          _sortOptions[phase.id] = 'newest';
                        });
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        if (allPhaseTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Aucune tâche pour cette phase',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Aucune tâche ne correspond aux critères de recherche',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          ),
      ],
    );
  }

  Widget _buildTasksWithoutPhaseSection() {
    // Récupérer toutes les tâches sans phase
    final allTasksWithoutPhase = _tasks.where((task) => task.phaseId == null).toList();
    
    if (allTasksWithoutPhase.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Appliquer les filtres et le tri
    final tasksWithoutPhase = _filterTasks(
      allTasksWithoutPhase,
      _noPhaseSearchQuery,
      _noPhaseStatusFilter,
      _noPhasePriorityFilter,
      _noPhaseSortOption,
    );
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tâches sans phase (${allTasksWithoutPhase.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  // Vérifier la permission avant d'ouvrir le formulaire d'ajout de tâche
                  final hasPermission = await _roleService.hasPermission('create_task', projectId: _project!.id);
                  if (!hasPermission) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vous n\'avez pas la permission de créer une tâche'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                  
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(projectId: _project!.id),
                    ),
                  );
                  if (result == true) {
                    _loadProjectDetails();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher des tâches...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _noPhaseSearchQuery = value;
                });
              },
              controller: TextEditingController(text: _noPhaseSearchQuery),
            ),
          ),
          
          // Options de filtrage et tri
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Filtre par statut
                  Container(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PopupMenuButton<String?>(
                      initialValue: _noPhaseStatusFilter,
                      onSelected: (value) {
                        setState(() {
                          _noPhaseStatusFilter = value == 'all' ? null : value;
                        });
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('Tous les statuts'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'todo',
                          child: Text('À faire'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'in_progress',
                          child: Text('En cours'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'review',
                          child: Text('En révision'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'completed',
                          child: Text('Terminée'),
                        ),
                      ],
                      child: Chip(
                        label: Text(
                          _noPhaseStatusFilter == null
                              ? 'Statut'
                              : _noPhaseStatusFilter == 'todo'
                                  ? 'À faire'
                                  : _noPhaseStatusFilter == 'in_progress'
                                      ? 'En cours'
                                      : _noPhaseStatusFilter == 'review'
                                          ? 'En révision'
                                          : 'Terminée',
                        ),
                        deleteIcon: _noPhaseStatusFilter == null
                            ? null
                            : const Icon(Icons.close, size: 18),
                        onDeleted: _noPhaseStatusFilter == null
                            ? null
                            : () {
                                setState(() {
                                  _noPhaseStatusFilter = null;
                                });
                              },
                      ),
                    ),
                  ),
                  
                  // Filtre par priorité
                  Container(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: PopupMenuButton<String?>(
                      initialValue: _noPhasePriorityFilter,
                      onSelected: (value) {
                        setState(() {
                          _noPhasePriorityFilter = value == 'all' ? null : value;
                        });
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('Toutes les priorités'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'low',
                          child: Text('Basse'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'medium',
                          child: Text('Moyenne'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'high',
                          child: Text('Haute'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'urgent',
                          child: Text('Urgente'),
                        ),
                      ],
                      child: Chip(
                        label: Text(
                          _noPhasePriorityFilter == null
                              ? 'Priorité'
                              : _noPhasePriorityFilter == 'low'
                                  ? 'Basse'
                                  : _noPhasePriorityFilter == 'medium'
                                      ? 'Moyenne'
                                      : _noPhasePriorityFilter == 'high'
                                          ? 'Haute'
                                          : 'Urgente',
                        ),
                        deleteIcon: _noPhasePriorityFilter == null
                            ? null
                            : const Icon(Icons.close, size: 18),
                        onDeleted: _noPhasePriorityFilter == null
                            ? null
                            : () {
                                setState(() {
                                  _noPhasePriorityFilter = null;
                                });
                              },
                      ),
                    ),
                  ),
                  
                  // Options de tri
                  Container(
                    child: PopupMenuButton<String>(
                      initialValue: _noPhaseSortOption,
                      onSelected: (value) {
                        setState(() {
                          _noPhaseSortOption = value;
                        });
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'newest',
                          child: Text('Plus récent d\'abord'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'oldest',
                          child: Text('Plus ancien d\'abord'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'deadline_asc',
                          child: Text('Échéance (croissant)'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'deadline_desc',
                          child: Text('Échéance (décroissant)'),
                        ),
                      ],
                      child: Chip(
                        label: Text(
                          _noPhaseSortOption == 'newest'
                              ? 'Plus récent'
                              : _noPhaseSortOption == 'oldest'
                                  ? 'Plus ancien'
                                  : _noPhaseSortOption == 'deadline_asc'
                                      ? 'Échéance ↑'
                                      : 'Échéance ↓',
                        ),
                      ),
                    ),
                  ),
                  
                  // Bouton pour réinitialiser les filtres
                  if (_noPhaseSearchQuery.isNotEmpty ||
                      _noPhaseStatusFilter != null ||
                      _noPhasePriorityFilter != null ||
                      _noPhaseSortOption != 'newest')
                    Container(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _noPhaseSearchQuery = '';
                            _noPhaseStatusFilter = null;
                            _noPhasePriorityFilter = null;
                            _noPhaseSortOption = 'newest';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          if (tasksWithoutPhase.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Aucune tâche ne correspond aux critères de recherche',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasksWithoutPhase.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(tasksWithoutPhase[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final TaskStatus status = TaskStatus.fromValue(task.status);
    final TaskPriority priority = TaskPriority.fromValue(task.priority);
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Vérifier la permission avant d'ouvrir les détails de la tâche
          final hasPermission = await _roleService.hasPermission('read_task', projectId: task.projectId);
          if (!hasPermission) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vous n\'avez pas la permission de voir cette tâche'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                task: task,
                onTaskUpdated: (updatedTask) {
                  setState(() {
                    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
                    if (index != -1) {
                      _tasks[index] = updatedTask;
                    }
                  });
                },
                onTaskDeleted: (deletedTask) {
                  setState(() {
                    _tasks.removeWhere((t) => t.id == deletedTask.id);
                  });
                },
              ),
            ),
          );
          if (result == true) {
            _loadProjectDetails();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicateur de statut
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4, right: 8),
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: status == TaskStatus.completed 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                  decorationColor: Colors.grey,
                                  color: status == TaskStatus.completed 
                                      ? Colors.grey 
                                      : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status.color.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.assignedTo != null 
                              ? _userDisplayNames[task.assignedTo] ?? 'Utilisateur'
                              : 'Non assigné',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.event, 
                          size: 16, 
                          color: task.dueDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(task.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: task.dueDate!.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: priority.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: priority.color.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  priority.displayName,
                  style: TextStyle(
                    color: priority.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce projet ? Cette action supprimera également toutes les tâches associées et ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _projectService.deleteProject(_project!.id);
                if (mounted) {
                  Navigator.pop(context, true); // Retourner à l'écran précédent avec un résultat
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression du projet: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Budget',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Le bouton "Ajouter un budget" a été supprimé car nous utilisons maintenant une approche par projet
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingBudget)
          const Center(child: CircularProgressIndicator())
        else if (_projectTransactions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.attach_money,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune transaction financière pour ce projet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les transactions vous permettent de gérer les revenus et dépenses de votre projet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionFormScreen(
                            projectId: _project!.id,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadProjectBudget();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une transaction'),
                  ),
                ],
              ),
            ),
          )
        else
          BudgetSummaryWidget(
            transactions: _projectTransactions,
            onTransactionAdded: (transaction) {
              setState(() {
                _projectTransactions.add(transaction);
              });
            },
            onTransactionUpdated: (transaction) {
              setState(() {
                final index = _projectTransactions.indexWhere((t) => t.id == transaction.id);
                if (index != -1) {
                  _projectTransactions[index] = transaction;
                }
              });
            },
            onTransactionDeleted: (transaction) {
              setState(() {
                _projectTransactions.removeWhere((t) => t.id == transaction.id);
              });
            },
          ),
      ],
    );
  }

  Color _getBudgetColor(double usagePercentage) {
    if (usagePercentage < 50) {
      return Colors.green; // Moins de 50% du budget utilisé : vert
    } else if (usagePercentage < 75) {
      return Colors.orange; // Entre 50% et 75% : orange
    } else {
      return Colors.red; // Plus de 75% : rouge
    }
  }
}
