import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/project_service/project_service.dart';
import '../../services/role_service.dart';
import '../../models/task_model.dart';
import '../../widgets/islamic_patterns.dart';
import '../../widgets/permission_gated.dart';
import '../../widgets/rbac_gated_screen.dart';

/// Widget qui vérifie les permissions avant d'afficher le calendrier pour éviter le flash de l'écran d'accès refusé
class CalendarScreenWrapper extends StatefulWidget {
  const CalendarScreenWrapper({super.key});

  @override
  State<CalendarScreenWrapper> createState() => _CalendarScreenWrapperState();
}

class _CalendarScreenWrapperState extends State<CalendarScreenWrapper> {
  final RoleService _roleService = RoleService();
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
      // Récupérer le premier projet accessible
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        bool hasProject = false;
        
        // 1. Vérifier d'abord via l'ancien système (project_id dans user_roles)
        final directProjectsResponse = await Supabase.instance.client
            .from('user_roles')
            .select('project_id')
            .eq('user_id', userId)
            .not('project_id', 'is', null)
            .limit(1);
        
        if (directProjectsResponse.isNotEmpty) {
          _projectId = directProjectsResponse[0]['project_id'] as String;
          hasProject = true;
        } else {
          // 2. Si aucun projet trouvé, vérifier via user_role_projects
          
          // D'abord, récupérer les IDs des rôles de l'utilisateur
          final userRolesResponse = await Supabase.instance.client
              .from('user_roles')
              .select('id')
              .eq('user_id', userId)
              .limit(10);  // Limiter pour éviter une requête trop large
          
          if (userRolesResponse.isNotEmpty) {
            // Pour chaque rôle, vérifier s'il a des projets associés
            for (final roleData in userRolesResponse) {
              final roleId = roleData['id'] as String;
              
              final linkedProjectsResponse = await Supabase.instance.client
                  .from('user_role_projects')
                  .select('project_id')
                  .eq('user_role_id', roleId)
                  .limit(1);
              
              if (linkedProjectsResponse.isNotEmpty) {
                _projectId = linkedProjectsResponse[0]['project_id'] as String;
                hasProject = true;
                break;  // Arrêter dès qu'on trouve un projet
              }
            }
          }
        }
        
        // Vérifier la permission seulement si on a trouvé un projet
        if (hasProject) {
          _hasPermission = await _roleService.hasPermission('read_task', projectId: _projectId);
        } else {
          // Vérifier si l'utilisateur a la permission globale
          _hasPermission = await _roleService.hasPermission('read_task');
        }
      }
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
    } finally {
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
                'Vous n\'avez pas l\'autorisation d\'accéder au calendrier',
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
    
    // Si l'utilisateur a la permission, afficher le calendrier avec le bon contexte de projet
    return CalendarScreen(projectId: _projectId);
  }
}

class CalendarScreen extends StatefulWidget {
  final String? projectId;
  
  const CalendarScreen({
    super.key, 
    this.projectId,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ProjectService _projectService = ProjectService();
  final RoleService _roleService = RoleService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  List<Task> _allTasks = [];
  Map<DateTime, List<Task>> _events = {};
  List<Task> _selectedEvents = [];
  
  bool _isLoading = true;
  String? _firstAccessibleProjectId;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserAccessibleProjectId();
    _loadTasks();
    
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }

  /// Récupère le premier projet accessible à l'utilisateur pour le contexte RBAC
  Future<void> _loadUserAccessibleProjectId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('=== RBAC DEBUG === [CalendarScreen] Aucun utilisateur connecté, aucun projet accessible');
        return;
      }
      
      print('=== RBAC DEBUG === [CalendarScreen] Récupération du premier projet accessible pour contexte RBAC');
      final accessibleProjectsResponse = await Supabase.instance.client
          .from('user_roles')
          .select('project_id')
          .eq('user_id', userId)
          .not('project_id', 'is', null)
          .limit(1);
      
      if (accessibleProjectsResponse.isNotEmpty) {
        _firstAccessibleProjectId = accessibleProjectsResponse[0]['project_id'] as String;
        print('=== RBAC DEBUG === [CalendarScreen] Premier projet accessible trouvé: $_firstAccessibleProjectId');
      } else {
        print('=== RBAC DEBUG === [CalendarScreen] Aucun projet accessible trouvé');
      }
    } catch (e) {
      print('=== RBAC DEBUG === [CalendarScreen] Erreur lors de la récupération du projet accessible: $e');
    }
  }

  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: CalendarScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (CalendarScreen) =====');
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
      
      // Vérifier spécifiquement la permission pour l'écran du calendrier
      final hasCalendarAccess = await _roleService.hasPermission('read_task');
      print('\nPermission "read_task" (accès calendrier): ${hasCalendarAccess ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }

  /// Charge les tâches depuis le service
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('\n=== RBAC DEBUG === [CalendarScreen] Chargement des tâches avec filtrage RBAC');
      
      // Récupérer l'ID de l'utilisateur actuel
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('=== RBAC DEBUG === [CalendarScreen] Aucun utilisateur connecté, aucune tâche chargée');
        setState(() {
          _allTasks = [];
          _events = {};
          _isLoading = false;
        });
        return;
      }
      
      // Récupérer les projets auxquels l'utilisateur a accès via ses rôles
      print('=== RBAC DEBUG === [CalendarScreen] Récupération des projets accessibles pour l\'utilisateur');
      
      // 1. Récupérer les projets via l'ancien système (project_id dans user_roles)
      final directProjectsResponse = await Supabase.instance.client
          .from('user_roles')
          .select('project_id')
          .eq('user_id', userId)
          .not('project_id', 'is', null);
      
      final directProjectIds = directProjectsResponse
          .map((item) => item['project_id'] as String)
          .toList();
      
      // 2. Récupérer les projets accessibles via la nouvelle table user_role_projects
      final userRolesResponse = await Supabase.instance.client
          .from('user_roles')
          .select('id')
          .eq('user_id', userId);
      
      final userRoleIds = userRolesResponse
          .map((json) => json['id'] as String)
          .toList();
      
      List<String> linkedProjectIds = [];
      
      // Pour chaque rôle, récupérer les projets associés
      for (final roleId in userRoleIds) {
        final roleProjectsResponse = await Supabase.instance.client
            .from('user_role_projects')
            .select('project_id')
            .eq('user_role_id', roleId);
        
        final roleProjects = roleProjectsResponse
            .map((json) => json['project_id'] as String)
            .toList();
        
        linkedProjectIds.addAll(roleProjects);
      }
      
      // 3. Combiner tous les IDs de projet (supprimer les doublons avec toSet().toList())
      final accessibleProjectIds = [...directProjectIds, ...linkedProjectIds].toSet().toList();
      
      print('=== RBAC DEBUG === [CalendarScreen] Projets accessibles: ${accessibleProjectIds.join(", ")}');
      
      // Si l'utilisateur est un admin système, charger toutes les tâches
      final isAdmin = await _roleService.hasPermission('read_all_projects');
      
      List<Task> tasks;
      if (isAdmin) {
        print('=== RBAC DEBUG === [CalendarScreen] Utilisateur admin, chargement de toutes les tâches');
        tasks = await _projectService.getAllTasks();
      } else if (accessibleProjectIds.isEmpty) {
        print('=== RBAC DEBUG === [CalendarScreen] Aucun projet accessible, aucune tâche chargée');
        setState(() {
          _allTasks = [];
          _events = {};
          _isLoading = false;
        });
        return;
      } else {
        print('=== RBAC DEBUG === [CalendarScreen] Chargement des tâches pour les projets accessibles');
        tasks = await _projectService.getTasksForProjects(accessibleProjectIds);
      }
      
      // Organiser les tâches par date d'échéance
      final events = <DateTime, List<Task>>{};
      
      for (final task in tasks) {
        if (task.dueDate != null) {
          final date = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          
          if (events[date] != null) {
            events[date]!.add(task);
          } else {
            events[date] = [task];
          }
        }
      }
      
      setState(() {
        _allTasks = tasks;
        _events = events;
        _isLoading = false;
        
        // Sélectionner les événements du jour actuel
        if (_selectedDay != null) {
          _selectedEvents = _getEventsForDay(_selectedDay!);
        }
      });
      
      print('=== RBAC DEBUG === [CalendarScreen] ${tasks.length} tâches chargées');
    } catch (e) {
      print('=== RBAC DEBUG === [CalendarScreen] Erreur lors du chargement des tâches: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des tâches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  List<Task> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }
  
  // Obtenir la couleur de priorité la plus élevée pour un jour donné
  Color _getMarkerColorForDay(DateTime day) {
    final tasks = _getEventsForDay(day);
    if (tasks.isEmpty) return const Color(0xFF1F4E5F); // Couleur par défaut
    
    // Trouver la priorité la plus élevée parmi les tâches du jour
    int highestPriority = 0;
    for (final task in tasks) {
      final priority = task.priority;
      if (priority > highestPriority) {
        highestPriority = priority;
      }
    }
    
    // Retourner la couleur correspondant à la priorité la plus élevée
    return TaskPriority.fromValue(highestPriority).color;
  }
  
  // Générer les marqueurs pour un jour donné avec les couleurs de priorité
  List<Widget> _buildEventsMarkerForDay(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return [];
    
    // Regrouper les tâches par priorité
    final Map<int, int> priorityCounts = {};
    for (final task in events) {
      final priority = task.priority;
      priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
    }
    
    // Créer un marqueur pour chaque priorité présente (au maximum 3)
    final List<Widget> markers = [];
    // Trier les priorités de la plus haute à la plus basse
    final sortedPriorities = priorityCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // Limiter à 3 marqueurs au maximum
    final displayPriorities = sortedPriorities.take(3).toList();
    
    for (final priority in displayPriorities) {
      markers.add(
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TaskPriority.fromValue(priority).color,
          ),
        ),
      );
    }
    
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: CalendarScreen.build() - Début');
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return RbacGatedScreen(
      permissionName: 'read_task',
      projectId: widget.projectId, // Ajout du contexte de projet pour la vérification RBAC
      onAccessDenied: () {
        print('DEBUG: CalendarScreen - onAccessDenied appelé');
        // Afficher seulement un message dans la console sans redirection automatique
        print('DEBUG: CalendarScreen - Accès refusé, affichage de l\'écran d\'accès refusé');
      },
      accessDeniedWidget: Scaffold(
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
                'Vous n\'avez pas l\'autorisation d\'accéder au calendrier',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigation à la page d'accueil
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calendrier'),
          backgroundColor: const Color(0xFF1F4E5F),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTasks,
              tooltip: 'Actualiser',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 24.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 28),
                          const SizedBox(width: 16),
                          Text(
                            'Calendrier',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadTasks,
                            tooltip: 'Actualiser',
                          ),
                        ],
                      ),
                    ),
                    
                    // Calendrier
                    Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 24.0,
                        vertical: 8.0,
                      ),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          eventLoader: _getEventsForDay,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                              _selectedEvents = _getEventsForDay(selectedDay);
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isEmpty) return null;
                              
                              return Positioned(
                                bottom: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _buildEventsMarkerForDay(date),
                                ),
                              );
                            },
                          ),
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 3,
                            markerSize: 8,
                            markerDecoration: const BoxDecoration(
                              color: Color(0xFF1F4E5F),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: const Color(0xFF1F4E5F).withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFF1F4E5F),
                              shape: BoxShape.circle,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonDecoration: BoxDecoration(
                              color: const Color(0xFF1F4E5F),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            formatButtonTextStyle: const TextStyle(color: Colors.white),
                            titleCentered: true,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Titre de la section des événements
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16.0 : 28.0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedDay != null
                                ? 'Tâches du ${DateFormat.yMMMMd('fr_FR').format(_selectedDay!)}'
                                : 'Sélectionnez une date',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedEvents.length} tâche${_selectedEvents.length != 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Liste des événements du jour sélectionné
                    Expanded(
                      child: _selectedEvents.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.of(context).size.height * 0.3,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20),
                                    Container(
                                      width: 100,
                                      height: 100,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          IslamicPatternBackground(),
                                          const Icon(
                                            Icons.event_busy,
                                            size: 36,
                                            color: Color(0xFF1F4E5F),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aucune tâche pour cette date',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                      child: Text(
                                        'Sélectionnez une autre date ou ajoutez une nouvelle tâche',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12.0 : 24.0,
                              ),
                              itemCount: _selectedEvents.length,
                              itemBuilder: (context, index) {
                                final task = _selectedEvents[index];
                                return _buildTaskCard(task);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildTaskCard(Task task) {
    // Déterminer la couleur en fonction de la priorité
    final priorityColors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    
    final priorityColor = task.priority >= 0 && task.priority < priorityColors.length
        ? priorityColors[task.priority]
        : Colors.grey;
    
    // Déterminer l'icône en fonction du statut
    IconData statusIcon;
    Color statusColor;
    
    switch (task.status.toLowerCase()) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusIcon = Icons.pending;
        statusColor = Colors.orange;
        break;
      case 'blocked':
        statusIcon = Icons.block;
        statusColor = Colors.red;
        break;
      default:
        statusIcon = Icons.circle_outlined;
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.2),
          child: Icon(
            statusIcon,
            color: statusColor,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              task.description.isNotEmpty
                  ? task.description
                  : 'Aucune description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  task.dueDate != null
                      ? DateFormat.yMMMd('fr_FR').format(task.dueDate!)
                      : 'Pas de date limite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: priorityColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            _getPriorityText(task.priority),
            style: TextStyle(
              color: priorityColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () async {
          // Vérifier si l'utilisateur a la permission de voir les détails de la tâche
          final hasReadTaskPermission = await _roleService.hasPermission(
            'read_task',
            projectId: task.projectId,
          );
          
          if (!hasReadTaskPermission) {
            print('=== RBAC DEBUG === [CalendarScreen] Accès refusé aux détails de la tâche: ${task.id}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vous n\'avez pas la permission de voir les détails de cette tâche'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          if (mounted) {
            print('=== RBAC DEBUG === [CalendarScreen] Accès autorisé aux détails de la tâche: ${task.id}');
            // Naviguer vers les détails de la tâche
            Navigator.pushNamed(
              context,
              '/task_details',
              arguments: {'taskId': task.id},
            );
          }
        },
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
}
