import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import '../../models/project_model.dart';
import '../../services/team_service/team_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../projects/project_detail_screen.dart';
import 'project_to_team_dialog.dart';

class TeamProjectsScreen extends StatefulWidget {
  final Team team;
  final bool isAdmin;

  const TeamProjectsScreen({
    super.key,
    required this.team,
    required this.isAdmin,
  });

  @override
  State<TeamProjectsScreen> createState() => _TeamProjectsScreenState();
}

class _TeamProjectsScreenState extends State<TeamProjectsScreen> {
  final TeamService _teamService = TeamService();
  
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final projects = await _teamService.getTeamProjects(widget.team.id);
      
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des projets: $e';
        _isLoading = false;
      });
    }
  }

  void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ProjectToTeamDialog(
          teamId: widget.team.id,
          onProjectsAdded: () {
            _loadProjects();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Projet(s) ajouté(s) avec succès')),
            );
          },
        );
      },
    );
  }

  void _showRemoveProjectDialog(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le projet'),
        content: Text('Êtes-vous sûr de vouloir retirer "${project.name}" de cette équipe ? Le projet ne sera pas supprimé, mais il ne sera plus associé à cette équipe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _teamService.removeProjectFromTeam(widget.team.id, project.id);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Projet retiré de l\'équipe avec succès')),
                );
                
                _loadProjects();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors du retrait du projet: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Projets de ${widget.team.name}'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddProjectDialog,
              tooltip: 'Ajouter un projet',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
              : _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const IslamicPatternPlaceholder(
                            size: 150,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun projet dans cette équipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ajoutez des projets pour collaborer avec votre équipe',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (widget.isAdmin)
                            ElevatedButton.icon(
                              onPressed: _showAddProjectDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un projet'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            title: Text(project.name),
                            subtitle: Text(project.description ?? 'Aucune description'),
                            trailing: widget.isAdmin
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showRemoveProjectDialog(project),
                                        tooltip: 'Retirer de l\'équipe',
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 16),
                                    ],
                                  )
                                : const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailScreen(projectId: project.id),
                                ),
                              ).then((_) => _loadProjects());
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
