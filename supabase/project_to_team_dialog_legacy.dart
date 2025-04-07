import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/project_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/team_service/team_service.dart';

class ProjectToTeamDialog extends StatefulWidget {
  final String teamId;
  final Function onProjectsAdded;

  const ProjectToTeamDialog({
    required this.teamId,
    required this.onProjectsAdded,
  });

  @override
  State<ProjectToTeamDialog> createState() => _ProjectToTeamDialogState();
}

class _ProjectToTeamDialogState extends State<ProjectToTeamDialog> {
  final ProjectService _projectService = ProjectService();
  final TeamService _teamService = TeamService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Project> _userProjects = [];
  List<Project> _teamProjects = [];
  List<String> _selectedProjectIds = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger les projets de l'utilisateur
      final currentUser = _teamService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      // Récupérer les projets déjà associés à cette équipe
      final teamProjects = await _teamService.getTeamProjects(widget.teamId);
      
      // Récupérer tous les projets de l'utilisateur
      final userProjects = await _projectService.getProjectsByUser(currentUser.id);
      
      // Filtrer pour exclure les projets déjà dans l'équipe
      final teamProjectIds = teamProjects.map((p) => p.id).toSet();
      final availableProjects = userProjects.where((p) => !teamProjectIds.contains(p.id)).toList();
      
      setState(() {
        _teamProjects = teamProjects;
        _userProjects = availableProjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des projets: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addSelectedProjects() async {
    if (_selectedProjectIds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ajouter chaque projet sélectionné à l'équipe
      for (final projectId in _selectedProjectIds) {
        await _teamService.addProjectToTeam(widget.teamId, projectId);
      }

      if (mounted) {
        widget.onProjectsAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'ajout des projets: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ajouter des projets à l\'équipe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProjects,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            else if (_userProjects.isEmpty)
              Column(
                children: [
                  const Text(
                    'Vous n\'avez pas de projets disponibles à ajouter à cette équipe.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_teamProjects.isNotEmpty)
                    const Text(
                      'Tous vos projets sont déjà associés à cette équipe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Sélectionnez les projets à ajouter:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._userProjects.map((project) => CheckboxListTile(
                        title: Text(project.name),
                        subtitle: Text(
                          project.description.length > 50
                              ? '${project.description.substring(0, 50)}...'
                              : project.description,
                        ),
                        value: _selectedProjectIds.contains(project.id),
                        onChanged: (bool? selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedProjectIds.add(project.id);
                            } else {
                              _selectedProjectIds.remove(project.id);
                            }
                          });
                        },
                      )),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading || _userProjects.isEmpty
                      ? null
                      : _addSelectedProjects,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_selectedProjectIds.isEmpty
                          ? 'Fermer'
                          : 'Ajouter (${_selectedProjectIds.length})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
