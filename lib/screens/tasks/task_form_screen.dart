import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../models/phase_model.dart';
import '../../models/team_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../../widgets/permission_gated.dart';

class TaskFormScreen extends StatefulWidget {
  final String projectId;
  final Task? task;
  final String? phaseId;

  const TaskFormScreen({
    super.key,
    required this.projectId,
    this.task,
    this.phaseId,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  
  String _status = TaskStatus.todo.name;
  int _priority = TaskPriority.medium.value;
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedPhaseId;
  List<Phase> _phases = [];
  bool _loadingPhases = true;
  
  // Nouvelles variables pour la gestion des équipes
  bool _assignToTeam = false;
  List<Team> _teams = [];
  String? _selectedTeamId;
  bool _loadingTeams = true;
  
  // Nouvelles variables pour la liste des membres
  List<Map<String, dynamic>> _teamMembers = [];
  String? _selectedMemberId;
  bool _loadingTeamMembers = true;

  @override
  void initState() {
    super.initState();
    _loadPhases();
    _loadTeams();
    _loadTeamMembers();
    
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      if (widget.task!.assignedTo != null) {
        _selectedMemberId = widget.task!.assignedTo;
        _assignToTeam = false;
      } else {
        _assignToTeam = true;
        _loadTeamForTask(widget.task!.id);
      }
      _status = widget.task!.status;
      _priority = widget.task!.priority;
      _dueDate = widget.task!.dueDate;
      _selectedPhaseId = widget.task!.phaseId;
    } else if (widget.phaseId != null) {
      _selectedPhaseId = widget.phaseId;
    }
  }

  Future<void> _loadTeamForTask(String taskId) async {
    try {
      final teams = await _teamService.getTeamsByTask(taskId);
      if (teams.isNotEmpty) {
        setState(() {
          _selectedTeamId = teams.first.id;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'équipe assignée: $e');
    }
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await _teamService.getTeamsByProject(widget.projectId);
      setState(() {
        _teams = teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _loadingTeams = false;
        _errorMessage = 'Erreur lors du chargement des équipes: $e';
      });
    }
  }

  Future<void> _loadTeamMembers() async {
    try {
      final members = await _teamService.getProjectTeamMembers(widget.projectId);
      setState(() {
        _teamMembers = members;
        _loadingTeamMembers = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des membres: $e');
      setState(() {
        _teamMembers = [];
        _loadingTeamMembers = false;
        _errorMessage = 'Erreur lors du chargement des membres: $e';
      });
    }
  }

  Future<void> _loadPhases() async {
    try {
      final phases = await _phaseService.getPhasesByProject(widget.projectId);
      setState(() {
        _phases = phases;
        _loadingPhases = false;
      });
    } catch (e) {
      setState(() {
        _loadingPhases = false;
        _errorMessage = 'Erreur lors du chargement des phases: $e';
      });
    }
  }

  // Méthode pour s'assurer qu'il n'y a pas de doublons dans la liste des membres
  List<Map<String, dynamic>> _getUniqueMembers() {
    final Map<String, Map<String, dynamic>> uniqueMembers = {};
    
    for (var member in _teamMembers) {
      final id = member['id'] as String;
      if (!uniqueMembers.containsKey(id)) {
        uniqueMembers[id] = member;
      }
    }
    
    return uniqueMembers.values.toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.getCurrentUserIdSync();
      if (userId == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      String? taskId;

      if (widget.task == null) {
        // Créer une nouvelle tâche
        final newTask = Task(
          id: Uuid().v4(), // Générer un ID unique
          projectId: widget.projectId,
          phaseId: _selectedPhaseId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          createdAt: DateTime.now(),
          assignedTo: _assignToTeam ? null : _selectedMemberId,
          createdBy: userId,
          status: _status,
          priority: _priority,
          dueDate: _dueDate,
        );

        final createdTask = await _projectService.createTask(newTask);
        taskId = createdTask.id;
      } else {
        // Récupérer l'ancienne tâche pour comparer les changements
        final oldTask = widget.task!;
        
        // Créer la tâche mise à jour
        final updatedTask = oldTask.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          updatedAt: DateTime.now(),
          assignedTo: _assignToTeam ? null : _selectedMemberId,
          status: _status,
          priority: _priority,
          dueDate: _dueDate,
          phaseId: _selectedPhaseId,
        );

        // Utiliser la méthode updateTask mise à jour qui prend en compte les changements
        await _projectService.updateTask(updatedTask, oldTask: oldTask);
        taskId = oldTask.id;
      }

      // Gérer l'assignation d'équipe si nécessaire
      if (_assignToTeam && _selectedTeamId != null) {
        // D'abord supprimer toutes les associations d'équipes existantes
        await _teamService.removeAllTeamsFromTask(taskId);
        
        // Puis ajouter la nouvelle association
        await _teamService.assignTaskToTeam(taskId, _selectedTeamId!);
      }

      if (mounted) {
        Navigator.pop(context, true); // Retourner à l'écran précédent avec un résultat
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'enregistrement de la tâche: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDueDate() async {
    // S'assurer que la date initiale n'est pas antérieure à la date minimale
    final DateTime now = DateTime.now();
    final DateTime initialDate = (_dueDate != null && _dueDate!.isAfter(now))
        ? _dueDate!
        : now;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && pickedDate != _dueDate) {
      setState(() {
        _dueDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionName = widget.task == null ? 'create_task' : 'update_task';
    
    return RbacGatedScreen(
      permissionName: permissionName,
      projectId: widget.projectId,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.task == null ? 'Nouvelle tâche' : 'Modifier la tâche'),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre de la tâche',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un titre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Contrôle d'assignation avec permission 'assign_task'
            PermissionGated(
              permissionName: 'assign_task',
              projectId: widget.projectId,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ajout d'un switch pour choisir entre assignation individuelle ou équipe
                  SwitchListTile(
                    title: const Text('Assigner à une équipe'),
                    value: _assignToTeam,
                    onChanged: (value) {
                      setState(() {
                        _assignToTeam = value;
                      });
                    },
                  ),
                  
                  // Afficher le champ approprié selon le choix d'assignation
                  if (!_assignToTeam) ...[
                    if (_loadingTeamMembers)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Membre assigné',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedMemberId,
                        hint: const Text('Sélectionner un membre'),
                        items: _getUniqueMembers().map((member) {
                          // Générer une clé unique basée sur l'ID du membre
                          final String memberId = member['id'] as String;
                          
                          return DropdownMenuItem<String>(
                            key: ValueKey('member-$memberId'), // Ajouter une clé unique
                            value: memberId,
                            child: Text("${member['fullName']} (${member['email']})"),
                          );
                        }).toList(),
                        validator: (value) {
                          if (!_assignToTeam && value == null) {
                            return 'Veuillez sélectionner un membre';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedMemberId = value;
                          });
                        },
                      ),
                    ],
                  ] else ...[
                    if (_loadingTeams)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Équipe assignée',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedTeamId,
                        hint: const Text('Sélectionner une équipe'),
                        items: _teams.map((team) {
                          return DropdownMenuItem<String>(
                            key: ValueKey('team-${team.id}'),
                            value: team.id,
                            child: Text(team.name),
                          );
                        }).toList(),
                        validator: (value) {
                          if (_assignToTeam && value == null) {
                            return 'Veuillez sélectionner une équipe';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedTeamId = value;
                          });
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                    ),
                    items: TaskStatus.values.map((status) {
                      return DropdownMenuItem<String>(
                        value: status.name,
                        child: Text(status.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  // Contrôle de priorité avec permission 'change_task_priority'
                  child: PermissionGated(
                    permissionName: 'change_task_priority',
                    projectId: widget.projectId,
                    child: DropdownButtonFormField<int>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priorité',
                        border: OutlineInputBorder(),
                      ),
                      items: TaskPriority.values.map((priority) {
                        return DropdownMenuItem<int>(
                          value: priority.value,
                          child: Text(priority.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _priority = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingPhases)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_phases.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Phase',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                value: _selectedPhaseId,
                hint: const Text('Sélectionner une phase'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Aucune phase'),
                  ),
                  ..._phases.map((phase) => DropdownMenuItem<String>(
                    value: phase.id,
                    child: Text(phase.name),
                  )).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPhaseId = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDueDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date d\'échéance',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _dueDate == null
                        ? null
                        : () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dueDate == null
                          ? 'Sélectionner une date'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.task == null ? 'Créer la tâche' : 'Enregistrer les modifications',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
