import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';

class ProjectFormScreen extends StatefulWidget {
  final Project? project;

  const ProjectFormScreen({
    super.key,
    this.project,
  });

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _plannedBudgetController = TextEditingController();
  
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  
  String _status = ProjectStatus.active.name;
  bool _isLoading = false;
  String? _errorMessage;
  
  List<Team> _userTeams = [];
  List<String> _selectedTeamIds = [];
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _loadUserTeams();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description;
      _status = widget.project!.status;
      
      if (widget.project!.plannedBudget != null && widget.project!.plannedBudget! > 0) {
        _plannedBudgetController.text = widget.project!.plannedBudget!.toString();
      }
      
      _loadProjectTeams();
    }
  }

  Future<void> _loadUserTeams() async {
    setState(() {
      _isLoadingTeams = true;
    });
    
    try {
      final teams = await _teamService.getUserTeams();
      setState(() {
        _userTeams = teams;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des équipes: $e';
        _isLoadingTeams = false;
      });
    }
  }
  
  Future<void> _loadProjectTeams() async {
    try {
      if (widget.project != null) {
        final projectTeams = await _teamService.getTeamsByProject(widget.project!.id);
        setState(() {
          _selectedTeamIds = projectTeams.map((team) => team.id).toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des équipes du projet: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _plannedBudgetController.dispose();
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      double? plannedBudget;
      if (_plannedBudgetController.text.isNotEmpty) {
        try {
          plannedBudget = double.parse(_plannedBudgetController.text.replaceAll(',', '.'));
        } catch (e) {
          setState(() {
            _errorMessage = 'Le budget prévu doit être un nombre valide';
            _isLoading = false;
          });
          return;
        }
      }

      Project? savedProject;
      
      if (widget.project == null) {
        final newProject = Project(
          id: Uuid().v4(), 
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          createdAt: DateTime.now(),
          createdBy: userId,
          status: _status,
          plannedBudget: plannedBudget, 
        );

        savedProject = await _projectService.createProject(newProject);
      } else {
        final updatedProject = widget.project!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          updatedAt: DateTime.now(),
          status: _status,
          plannedBudget: plannedBudget, 
        );

        savedProject = await _projectService.updateProject(updatedProject);
      }
      
      if (savedProject != null) {
        // Supprimer d'abord toutes les associations existantes
        try {
          await _teamService.removeAllTeamsFromProject(savedProject.id);
          
          // Tenir une liste des équipes ajoutées avec succès
          List<String> successfulTeams = [];
          List<String> failedTeams = [];
          
          // Ajouter les nouvelles associations
          for (String teamId in _selectedTeamIds) {
            bool success = await _teamService.addProjectToTeam(teamId, savedProject.id);
            if (success) {
              successfulTeams.add(teamId);
            } else {
              failedTeams.add(teamId);
            }
          }
          
          // Si certaines équipes n'ont pas pu être ajoutées, afficher un avertissement
          if (failedTeams.isNotEmpty) {
            setState(() {
              _errorMessage = 'Le projet a été ${widget.project == null ? 'créé' : 'modifié'}, mais certaines équipes n\'ont pas pu être assignées.';
              _isLoading = false;
            });
            
            // Attendre un court instant pour que l'utilisateur voie le message
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('Erreur lors de la gestion des équipes: $e');
          // Continuer malgré l'erreur pour permettre la création/modification du projet
        }
      }

      if (mounted) {
        Navigator.pop(context, true); 
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'enregistrement du projet: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project == null ? 'Nouveau projet' : 'Modifier le projet'),
      ),
      body: _buildBody(),
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du projet',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un nom de projet';
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _plannedBudgetController,
              decoration: const InputDecoration(
                labelText: 'Budget prévu (€)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  try {
                    double.parse(value.replaceAll(',', '.'));
                  } catch (e) {
                    return 'Veuillez entrer un montant valide';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTeamSelector(),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
              ),
              items: ProjectStatus.values.map((status) {
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
              onPressed: _isLoading ? null : _saveProject,
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
                      widget.project == null ? 'Créer le projet' : 'Enregistrer les modifications',
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeamSelector() {
    if (_isLoadingTeams) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_userTeams.isEmpty) {
      return Card(
        color: Colors.amber.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vous n\'avez pas encore d\'équipes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Créez d\'abord une équipe pour l\'associer à ce projet.',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Naviguer vers l'écran de création d'équipe
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => TeamFormScreen()));
                },
                child: const Text('Créer une équipe'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Équipes assignées au projet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._userTeams.map((team) => CheckboxListTile(
          title: Text(team.name),
          subtitle: team.description != null ? Text(team.description!) : null,
          value: _selectedTeamIds.contains(team.id),
          onChanged: (bool? selected) {
            setState(() {
              if (selected == true) {
                if (!_selectedTeamIds.contains(team.id)) {
                  _selectedTeamIds.add(team.id);
                }
              } else {
                _selectedTeamIds.remove(team.id);
              }
            });
          },
        )),
        if (_selectedTeamIds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Veuillez sélectionner au moins une équipe',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
