import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/task_history_model.dart';
import '../../models/attachment_model.dart';
import '../../models/project_transaction_model.dart';
import '../../models/task_comment_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/user_service.dart';
import '../../services/attachment_service.dart';
import '../../services/budget_service.dart';
import '../../services/task_comment_service.dart';
import '../../services/role_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/budget_summary_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/permission_gated.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../budget/transaction_form_screen.dart';
import 'task_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;
  final Function(Task)? onTaskDeleted;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final UserService _userService = UserService();
  final AttachmentService _attachmentService = AttachmentService();
  final BudgetService _budgetService = BudgetService();
  final TaskCommentService _commentService = TaskCommentService();
  final RoleService _roleService = RoleService();
  final AuthService _authService = AuthService();
  
  late Task _task;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasTaskAccess = false; // Ajout de l'état d'accès à la tâche
  List<Team> _assignedTeams = [];
  bool _loadingTeams = true;
  Map<String, String> _userDisplayNames = {};
  List<TaskHistory> _taskHistory = [];
  bool _loadingHistory = true;
  List<Attachment> _attachments = [];
  bool _loadingAttachments = true;
  List<ProjectTransaction> _taskTransactions = [];
  bool _loadingBudget = true;
  List<TaskComment> _comments = [];
  bool _loadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _checkTaskAccess(); // Vérifier les permissions d'abord
  }

  /// Vérifie si l'utilisateur a accès à la tâche
  Future<void> _checkTaskAccess() async {
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
        print('DEBUG: Utilisateur system_admin, accès à la tâche accordé');
        setState(() {
          _hasTaskAccess = true;
        });
        await _loadAllTaskData();
        return;
      }
      
      // Vérifier si l'utilisateur a une permission directe sur cette tâche dans le contexte du projet
      final hasTaskPermission = await _roleService.hasPermission(
        'read_task',
        projectId: _task.projectId
      );
      
      if (hasTaskPermission) {
        print('DEBUG: Utilisateur a une permission directe sur cette tâche');
        setState(() {
          _hasTaskAccess = true;
        });
        await _loadAllTaskData();
        return;
      }
      
      // Vérifier si l'utilisateur a un rôle associé à ce projet spécifique
      final hasProjectRole = userRolesDetails.any((role) => 
        role['project_id'] == _task.projectId
      );
      
      if (hasProjectRole) {
        print('DEBUG: Utilisateur a un rôle associé au projet de cette tâche');
        setState(() {
          _hasTaskAccess = true;
        });
        await _loadAllTaskData();
        return;
      }
      
      // Vérifier si l'utilisateur est assigné à cette tâche
      final currentUser = _authService.currentUser;
      if (currentUser != null && _task.assignedTo == currentUser.id) {
        print('DEBUG: Utilisateur est assigné à cette tâche');
        setState(() {
          _hasTaskAccess = true;
        });
        await _loadAllTaskData();
        return;
      }
      
      // Aucun accès trouvé
      setState(() {
        _hasTaskAccess = false;
        _isLoading = false;
      });
      
    } catch (e) {
      print('ERROR: Erreur lors de la vérification de l\'accès à la tâche: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la vérification de l\'accès à la tâche: $e';
        _isLoading = false;
        _hasTaskAccess = false;
      });
    }
  }

  /// Charge toutes les données liées à la tâche
  Future<void> _loadAllTaskData() async {
    try {
      // Charger toutes les données en parallèle
      await Future.wait([
        _loadAssignedTeams(),
        _loadUserDisplayNames(),
        _loadTaskHistory(),
        _loadAttachments(),
        _loadTaskBudget(),
        _loadComments()
      ]);
      
      // Une fois toutes les données chargées, mettre à jour l'état
      setState(() {
        _isLoading = false;
      });
      
      print('DEBUG: Toutes les données de la tâche chargées avec succès');
    } catch (e) {
      print('ERROR: Erreur lors du chargement des données de la tâche: $e');
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssignedTeams() async {
    try {
      final teams = await _teamService.getTeamsByTask(_task.id);
      setState(() {
        _assignedTeams = teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _loadingTeams = false;
        print('Erreur lors du chargement des équipes: $e');
      });
    }
  }

  Future<void> _loadUserDisplayNames() async {
    try {
      final userIds = <String>{_task.createdBy};
      if (_task.assignedTo != null) {
        userIds.add(_task.assignedTo!);
      }
      
      final displayNames = await _userService.getUsersDisplayNames(userIds.toList());
      setState(() {
        _userDisplayNames = displayNames;
      });
    } catch (e) {
      print('Erreur lors du chargement des noms d\'utilisateurs: $e');
    }
  }

  Future<void> _loadTaskHistory() async {
    try {
      final history = await _projectService.getTaskHistory(_task.id);
      setState(() {
        _taskHistory = history;
        _loadingHistory = false;
      });
      
      // Charger les noms des utilisateurs qui ont fait les modifications
      if (history.isNotEmpty) {
        final userIds = history.map((h) => h.userId).toSet().toList();
        final displayNames = await _userService.getUsersDisplayNames(userIds);
        setState(() {
          _userDisplayNames.addAll(displayNames);
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'historique de la tâche: $e');
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadAttachments() async {
    try {
      final attachments = await _attachmentService.getAttachmentsByTask(_task.id);
      setState(() {
        _attachments = attachments;
        _loadingAttachments = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des pièces jointes: $e');
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _loadTaskBudget() async {
    try {
      final transactions = await _budgetService.getTransactionsByTask(_task.id);
      setState(() {
        _taskTransactions = transactions;
        _loadingBudget = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du budget: $e');
      setState(() {
        _loadingBudget = false;
      });
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _commentService.getCommentsByTask(_task.id);
      setState(() {
        _comments = comments;
        _loadingComments = false;
      });
      
      // Charger les noms des utilisateurs qui ont fait les commentaires
      if (comments.isNotEmpty) {
        final userIds = comments.map((c) => c.userId).toSet().toList();
        final displayNames = await _userService.getUsersDisplayNames(userIds);
        setState(() {
          _userDisplayNames.addAll(displayNames);
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des commentaires: $e');
      setState(() {
        _loadingComments = false;
      });
    }
  }

  Future<void> _refreshTaskDetails() async {
    try {
      final updatedTask = await _projectService.getTaskById(_task.id);
      setState(() {
        _task = updatedTask;
      });
      await _loadAllTaskData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des détails de la tâche: $e';
      });
    }
  }

  Future<void> _updateTaskStatus(String status) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final updatedTask = await _projectService.updateTaskStatus(_task.id, status);
      
      setState(() {
        _task = updatedTask;
        _isLoading = false;
      });
      
      // Rafraîchir l'historique
      await _loadTaskHistory();
      
      if (widget.onTaskUpdated != null) {
        widget.onTaskUpdated!(_task);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la mise à jour du statut: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Détails de la tâche',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Erreur',
        ),
        body: _buildErrorWidget(),
      );
    }

    if (!_hasTaskAccess) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Accès refusé',
        ),
        body: _buildAccessDeniedWidget(),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: _task.title,
        showLogo: false,
        actions: [
          PermissionGated(
            permissionName: 'update_task',
            projectId: _task.projectId,
            child: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(
                        projectId: _task.projectId,
                        task: _task,
                      ),
                    ),
                  );
                  if (result == true) {
                    await _refreshTaskDetails();
                  }
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog();
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];
                
                // Toujours ajouter l'option d'édition si l'utilisateur a la permission update_task
                items.add(
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                );
                
                // Vérifier si l'utilisateur a la permission delete_task avant d'ajouter l'option supprimer
                _roleService.hasPermission('delete_task', projectId: _task.projectId).then((hasPermission) {
                  if (hasPermission) {
                    items.add(
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  }
                });
                
                return items;
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final TaskStatus status = TaskStatus.values.firstWhere(
      (s) => s.name == _task.status,
      orElse: () => TaskStatus.todo,
    );

    final TaskPriority priority = TaskPriority.fromValue(_task.priority);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _task.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priority.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _task.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Affichage de l'assignation individuelle si elle existe
                  if (_task.assignedTo != null)
                    _buildInfoRow('Assignée à', _userDisplayNames[_task.assignedTo!] ?? _task.assignedTo!),
                  
                  // Affichage des équipes assignées
                  if (_loadingTeams)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_assignedTeams.isNotEmpty) ...[
                    _buildInfoRow(
                      _assignedTeams.length > 1 ? 'Équipes assignées' : 'Équipe assignée',
                      _assignedTeams.map((team) => team.name).join(', ')
                    ),
                  ],
                  
                  if (_task.dueDate != null)
                    _buildInfoRow(
                      'Date d\'échéance',
                      _formatDate(_task.dueDate!),
                      _task.dueDate!.isBefore(DateTime.now()) ? Colors.red : null,
                    ),
                  _buildInfoRow('Créée par', _userDisplayNames[_task.createdBy] ?? _task.createdBy),
                  _buildInfoRow('Créée le', _formatDate(_task.createdAt)),
                  if (_task.updatedAt != null)
                    _buildInfoRow('Mise à jour le', _formatDate(_task.updatedAt!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PermissionGated(
            permissionName: 'change_task_status',
            projectId: _task.projectId,
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sync_alt_rounded,
                          size: 20,
                          color: Colors.grey.shade800,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Progression de la tâche',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stepper moderne (style timeline horizontal)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculer l'étape active
                        final activeIndex = TaskStatus.values.indexWhere((s) => s.name == _task.status);
                        final maxWidth = constraints.maxWidth;
                        
                        return Column(
                          children: [
                            // Ligne de progression avec indicateurs
                            SizedBox(
                              height: 36,
                              child: Stack(
                                children: [
                                  // Ligne de progression (grise)
                                  Positioned(
                                    top: 16,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  // Ligne de progression (colorée)
                                  if (activeIndex >= 0)
                                    Positioned(
                                      top: 16,
                                      left: 0,
                                      width: (maxWidth * (activeIndex / (TaskStatus.values.length - 1))),
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade400,
                                              TaskStatus.values[activeIndex].color,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  // Marqueurs d'étapes
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: TaskStatus.values.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final status = entry.value;
                                      final isActive = index <= activeIndex;
                                      final isCurrent = index == activeIndex;
                                      
                                      return InkWell(
                                        onTap: () => _updateTaskStatus(status.name),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          height: 36,
                                          width: 36,
                                          decoration: BoxDecoration(
                                            color: isActive ? status.color : Colors.white,
                                            border: Border.all(
                                              color: isActive ? status.color : Colors.grey.shade400,
                                              width: isActive ? 2 : 1,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: isCurrent ? [
                                              BoxShadow(
                                                color: status.color.withOpacity(0.4),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ] : null,
                                          ),
                                          child: Center(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 300),
                                              child: isActive 
                                                ? Icon(
                                                    isCurrent ? Icons.done_all : Icons.done,
                                                    color: Colors.white,
                                                    size: 18,
                                                    key: ValueKey('active_$index'),
                                                  )
                                                : Text(
                                                    '${index + 1}',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    key: ValueKey('inactive_$index'),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Étiquettes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: TaskStatus.values.asMap().entries.map((entry) {
                                final index = entry.key;
                                final status = entry.value;
                                final isActive = index <= activeIndex;
                                
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: Text(
                                      status.displayName,
                                      textAlign: index == 0 
                                        ? TextAlign.left 
                                        : (index == TaskStatus.values.length - 1 
                                          ? TextAlign.right 
                                          : TextAlign.center),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        color: isActive ? status.color : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Section statut actuel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: TaskStatus.values
                                .firstWhere((s) => s.name == _task.status)
                                .color
                                .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(_task.status),
                              color: TaskStatus.values
                                .firstWhere((s) => s.name == _task.status)
                                .color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statut actuel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  TaskStatus.values
                                    .firstWhere((s) => s.name == _task.status)
                                    .displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _showStatusSelectionBottomSheet(context);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Modifier'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Section budget
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      // Bouton commenté car non protégé par vérification RBAC
                      // Utiliser le bouton "Nouvelle transaction" du widget BudgetSummaryWidget à la place
                      /*
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        tooltip: 'Ajouter une transaction',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionFormScreen(
                                taskId: _task.id,
                                projectId: _task.projectId,
                                phaseId: _task.phaseId,
                              ),
                            ),
                          );
                          
                          if (result != null) {
                            await _loadTaskBudget();
                            await _refreshTaskDetails();
                          }
                        },
                      ),
                      */
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _loadingBudget
                      ? const Center(child: CircularProgressIndicator())
                      : BudgetSummaryWidget(
                          budgetAllocated: _task.budgetAllocated,
                          budgetConsumed: _task.budgetConsumed,
                          transactions: _taskTransactions,
                          projectId: _task.projectId,
                          phaseId: _task.phaseId,
                          taskId: _task.id,
                          onTransactionAdded: (transaction) async {
                            setState(() {
                              _taskTransactions.add(transaction);
                              // Mettre à jour le budget consommé si c'est une dépense
                              if (transaction.amount < 0) {
                                _task = _task.copyWith(
                                  budgetConsumed: (_task.budgetConsumed ?? 0) + transaction.amount.abs(),
                                );
                              }
                            });
                            await _loadTaskBudget();
                          },
                          onTransactionUpdated: (transaction) async {
                            setState(() {
                              final index = _taskTransactions.indexWhere((t) => t.id == transaction.id);
                              if (index != -1) {
                                _taskTransactions[index] = transaction;
                              }
                            });
                            await _loadTaskBudget();
                            await _refreshTaskDetails();
                          },
                          onTransactionDeleted: (transaction) async {
                            setState(() {
                              _taskTransactions.removeWhere((t) => t.id == transaction.id);
                            });
                            await _loadTaskBudget();
                            await _refreshTaskDetails();
                          },
                        ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          _buildAttachmentsSection(),
          
          // Section commentaires
          const SizedBox(height: 24),
          _buildCommentsSection(),
          
          // Section historique des changements
          const SizedBox(height: 24),
          _buildTaskHistorySection(),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'todo':
        return Icons.pending_outlined;
      case 'inProgress':
        return Icons.play_circle_outlined;
      case 'review':
        return Icons.rate_review_outlined;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.help_outline;
    }
  }

  void _showStatusSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Changer le statut',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...TaskStatus.values.map((status) {
                final isSelected = status.name == _task.status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      if (!isSelected) {
                        _updateTaskStatus(status.name);
                      }
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? status.color.withOpacity(0.1) : Colors.grey.shade50,
                        border: Border.all(
                          color: isSelected ? status.color : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? status.color : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? status.color.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getStatusIcon(status.name),
                              color: isSelected ? Colors.white : status.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isSelected ? status.color : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getStatusDescription(status.name),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'todo':
        return 'Tâche à démarrer';
      case 'inProgress':
        return 'Tâche en cours de réalisation';
      case 'review':
        return 'Tâche en attente de validation';
      case 'completed':
        return 'Tâche terminée et validée';
      default:
        return '';
    }
  }

  Widget _buildAttachmentsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pièces jointes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                PermissionGated(
                  permissionName: 'create_attachment',
                  projectId: _task.projectId,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'camera') {
                        _takePicture();
                      } else if (value == 'gallery') {
                        _uploadImage();
                      } else if (value == 'document') {
                        _uploadDocument();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'camera',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt),
                            SizedBox(width: 8),
                            Text('Prendre une photo'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'gallery',
                        child: Row(
                          children: [
                            Icon(Icons.photo_library),
                            SizedBox(width: 8),
                            Text('Choisir une image'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'document',
                        child: Row(
                          children: [
                            Icon(Icons.file_present),
                            SizedBox(width: 8),
                            Text('Ajouter un document'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingAttachments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_attachments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Aucune pièce jointe',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _attachments.length,
                itemBuilder: (context, index) {
                  final attachment = _attachments[index];
                  return _buildAttachmentItem(attachment);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(Attachment attachment) {
    return InkWell(
      onTap: () => _openAttachment(attachment),
      onLongPress: () => _showAttachmentOptions(attachment),
      child: Container(
        decoration: BoxDecoration(
          color: attachment.getColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: attachment.getColor().withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (attachment.type == AttachmentType.image)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              )
            else
              Icon(
                attachment.getIcon(),
                size: 40,
                color: attachment.getColor(),
              ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                attachment.name,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePicture() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.takePhoto(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la prise de photo: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _uploadImage() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.uploadImageFromGallery(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du téléchargement de l\'image: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _uploadDocument() async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      final attachment = await _attachmentService.uploadDocument(_task.id);
      
      if (attachment != null) {
        setState(() {
          _attachments.insert(0, attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du téléchargement du document: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    try {
      // Afficher l'image directement dans l'application pour les pièces jointes de type image
      if (attachment.type == AttachmentType.image) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(attachment.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final Uri url = Uri.parse(attachment.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Erreur: $error', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (attachment.type == AttachmentType.document && attachment.name.toLowerCase().endsWith('.pdf')) {
        // Utiliser WebView pour afficher le PDF directement depuis l'URL
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                // Mise à jour de l'indicateur de progression
              },
              onPageStarted: (String url) {
                // La page commence à charger
              },
              onPageFinished: (String url) {
                // La page a fini de charger
              },
              onWebResourceError: (WebResourceError error) {
                _showErrorSnackBar('Erreur lors du chargement: ${error.description}');
              },
            ),
          )
          // Pour un PDF, nous utilisons Google PDF Viewer pour une meilleure compatibilité
          ..loadRequest(
            Uri.parse('https://docs.google.com/viewer?url=${Uri.encodeComponent(attachment.url)}&embedded=true'),
          );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(attachment.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final Uri url = Uri.parse(attachment.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
              body: WebViewWidget(controller: controller),
            ),
          ),
        );
      } else {
        // Pour les autres types, essayer d'ouvrir dans le navigateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ouverture de la pièce jointe...'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        final Uri url = Uri.parse(attachment.url);
        try {
          if (await canLaunchUrl(url)) {
            final bool launched = await launchUrl(
              url,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              _showErrorSnackBar('Impossible d\'ouvrir cette pièce jointe. Veuillez essayer de la télécharger manuellement.');
            }
          } else {
            _showErrorSnackBar('L\'URL ne peut pas être ouverte: ${url.toString()}');
          }
        } catch (e) {
          _showErrorSnackBar('Erreur lors de l\'ouverture: $e');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ouverture de la pièce jointe: $e');
    }
  }

  void _showAttachmentOptions(Attachment attachment) {
    // Préparer la liste d'options
    final List<Widget> options = [
      ListTile(
        leading: const Icon(Icons.open_in_new),
        title: const Text('Ouvrir'),
        onTap: () {
          Navigator.pop(context);
          _openAttachment(attachment);
        },
      ),
      ListTile(
        leading: const Icon(Icons.share),
        title: const Text('Partager'),
        onTap: () {
          Navigator.pop(context);
          _shareAttachment(attachment);
        },
      ),
    ];
    
    // Vérifier si l'utilisateur a la permission de supprimer des pièces jointes
    _roleService.hasPermission('delete_attachment', projectId: _task.projectId).then((hasPermission) {
      if (hasPermission) {
        final deleteOption = ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _confirmDeleteAttachment(attachment);
          },
        );
        
        if (mounted) {
          setState(() {
            options.add(deleteOption);
          });
        }
      }
    });
    
    // Afficher le menu d'options
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options,
        ),
      ),
    );
  }

  Future<void> _shareAttachment(Attachment attachment) async {
    try {
      final loadingDialog = _showLoadingDialog('Préparation du partage...');
      
      // Télécharger le fichier localement pour le partage
      final response = await http.get(Uri.parse(attachment.url));
      
      if (response.statusCode == 200) {
        // Obtenir le répertoire temporaire pour stocker le fichier
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${attachment.name}';
        
        // Sauvegarder le fichier
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Récupérer les informations du projet pour un meilleur contexte de partage
        String projectInfo = 'Projet: ${_task.projectId}';
        try {
          final project = await _projectService.getProjectById(_task.projectId);
          if (project != null) {
            projectInfo = 'Projet: ${project.name}';
          }
        } catch (e) {
          // En cas d'erreur, on garde l'ID du projet
          print('Erreur lors de la récupération du nom du projet: $e');
        }
        
        // Fermer le dialogue de chargement
        Navigator.pop(context); 
        
        // Générer un message de partage contextuel
        final taskInfo = 'Tâche: ${_task.title}';
        final shareMessage = 'Pièce jointe: ${attachment.name}\n$taskInfo\n$projectInfo';
        
        // Partager le fichier
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          text: shareMessage,
          subject: 'Pièce jointe: ${attachment.name}',
        );
        
        if (result.status == ShareResultStatus.dismissed) {
          _showErrorSnackBar('Partage annulé');
        }
      } else {
        // Fermer le dialogue de chargement
        Navigator.pop(context);
        _showErrorSnackBar('Erreur lors du téléchargement du fichier pour le partage: ${response.statusCode}');
      }
    } catch (e) {
      // Gérer le cas où la boîte de dialogue est déjà fermée
      try {
        Navigator.pop(context);
      } catch (_) {}
      
      _showErrorSnackBar('Erreur lors du partage: $e');
    }
  }

  void _confirmDeleteAttachment(Attachment attachment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la pièce jointe'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette pièce jointe ? Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAttachment(attachment);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    try {
      setState(() {
        _loadingAttachments = true;
      });

      await _attachmentService.deleteAttachment(attachment);
      
      setState(() {
        _attachments.removeWhere((a) => a.id == attachment.id);
      });
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression de la pièce jointe: $e');
    } finally {
      setState(() {
        _loadingAttachments = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTaskHistorySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des modifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_taskHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Aucune modification enregistrée',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _taskHistory.map((historyEntry) => _buildHistoryItem(historyEntry)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(TaskHistory historyEntry) {
    final userName = _userDisplayNames[historyEntry.userId] ?? 'Utilisateur';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: historyEntry.getColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              historyEntry.getIcon(),
              size: 16,
              color: historyEntry.getColor(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historyEntry.getDescription(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Par $userName le ${_formatDateTime(historyEntry.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commentaires',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Zone de saisie de commentaire
            PermissionGated(
              permissionName: 'create_comment',
              projectId: _task.projectId,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: _editingCommentId != null 
                            ? 'Modifier votre commentaire...' 
                            : 'Ajouter un commentaire...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          _editingCommentId != null ? Icons.check : Icons.send,
                          color: Colors.blue,
                        ),
                        onPressed: () async {
                          if (_commentController.text.trim().isEmpty) return;
                          
                          try {
                            setState(() {
                              _loadingComments = true;
                            });
                            
                            if (_editingCommentId != null) {
                              // Mettre à jour le commentaire existant
                              await _commentService.updateComment(
                                _editingCommentId!,
                                _commentController.text.trim(),
                              );
                              setState(() {
                                _editingCommentId = null;
                              });
                            } else {
                              // Ajouter un nouveau commentaire
                              await _commentService.addComment(
                                _task.id,
                                _commentController.text.trim(),
                              );
                            }
                            
                            _commentController.clear();
                            await _loadComments();
                          } catch (e) {
                            _showErrorSnackBar('Erreur lors de l\'envoi du commentaire: $e');
                            setState(() {
                              _loadingComments = false;
                            });
                          }
                        },
                      ),
                      if (_editingCommentId != null)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              _editingCommentId = null;
                              _commentController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // Liste des commentaires
            if (_loadingComments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_comments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Aucun commentaire',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  return _buildCommentItem(_comments[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(TaskComment comment) {
    final userName = _userDisplayNames[comment.userId] ?? 'Utilisateur';
    final String currentUserId = _authService.currentUser?.id ?? '';
    final bool isCurrentUserComment = comment.userId == currentUserId;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: comment.getColor().withOpacity(0.1),
                    child: Text(
                      (_userDisplayNames[comment.userId] ?? 'User').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: comment.getColor(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _formatDateTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isCurrentUserComment) ...[
                    const SizedBox(width: 8),
                    PermissionGated(
                      permissionName: 'update_comment',
                      projectId: _task.projectId,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _editingCommentId = comment.id;
                            _commentController.text = comment.comment;
                          });
                        },
                      ),
                    ),
                    PermissionGated(
                      permissionName: 'delete_comment',
                      projectId: _task.projectId,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        onPressed: () => _confirmDeleteComment(comment),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(comment.comment),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(TaskComment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le commentaire'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce commentaire ? Cette action ne peut pas être annulée.',
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
                setState(() {
                  _loadingComments = true;
                });
                
                await _commentService.deleteComment(comment.id);
                await _loadComments();
              } catch (e) {
                _showErrorSnackBar('Erreur lors de la suppression du commentaire: $e');
                setState(() {
                  _loadingComments = false;
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? textColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textColor != null ? TextStyle(color: textColor) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette tâche ? Cette action ne peut pas être annulée.',
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
                await _projectService.deleteTask(_task.id);
                if (widget.onTaskDeleted != null) {
                  widget.onTaskDeleted!(_task);
                }
                if (mounted) {
                  Navigator.pop(context, true); // Retourner à l'écran précédent avec un résultat
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la suppression de la tâche: $e'),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Afficher un dialogue de chargement
  AlertDialog _showLoadingDialog(String message) {
    AlertDialog dialog = AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
    );
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => dialog,
    );
    
    return dialog;
  }

  /// Widget d'erreur en cas d'échec de vérification des permissions
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
              'Vous n\'avez pas l\'autorisation d\'accéder à cette tâche.\nContactez un administrateur si vous pensez qu\'il s\'agit d\'une erreur.',
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
  
  /// Widget d'erreur générique
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
            onPressed: _checkTaskAccess,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
