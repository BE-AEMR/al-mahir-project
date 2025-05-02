import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/team_model.dart';
import '../../models/project_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../projects/project_detail_screen.dart';
import 'team_members_screen.dart';
import 'team_projects_screen.dart';
import 'invite_member_screen.dart';
import 'project_to_team_dialog.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;

  const TeamDetailScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> with SingleTickerProviderStateMixin {
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  
  late TabController _tabController;
  Team? _team;
  List<TeamMember> _members = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _errorMessage;

  // RBAC permissions
  bool _canUpdateTeam = false;
  bool _canDeleteTeam = false;
  bool _canInviteTeamMember = false;
  bool _canAddProject = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _team = widget.team;
    _loadTeamDetails();
    _checkPermissions();
    
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (_team == null) return;
    
    try {
      // Ajouter des logs pour le débogage
      print('DEBUG: Vérification des permissions pour l\'équipe ${_team!.id}');
      
      final canUpdateTeam = await _roleService.hasPermission('update_team', teamId: _team!.id);
      final canDeleteTeam = await _roleService.hasPermission('delete_team', teamId: _team!.id);
      final canInviteTeamMember = await _roleService.hasPermission('invite_team_member', teamId: _team!.id);
      final canCreateProject = await _roleService.hasPermission('create_project');
      
      print('DEBUG: Résultats des permissions:');
      print('- update_team: $canUpdateTeam');
      print('- delete_team: $canDeleteTeam');
      print('- invite_team_member: $canInviteTeamMember');
      print('- create_project: $canCreateProject');
      
      // Ne plus utiliser le système legacy, faire confiance au système RBAC
      setState(() {
        _canUpdateTeam = canUpdateTeam;
        _canDeleteTeam = canDeleteTeam;
        _canInviteTeamMember = canInviteTeamMember;
        _canAddProject = canCreateProject;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('ERREUR: TeamDetailScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (TeamDetailScreen) =====');
      print('ID utilisateur: ${user.id}');
      print('Email: ${user.email}');
      if (_team != null) {
        print('Équipe consultée: ${_team!.id} (${_team!.name})');
      }
      
      // Récupérer le profil utilisateur via le service d'équipe
      final userProfile = await _teamService.getUserProfile(user.id);
      if (userProfile != null) {
        print('Nom: ${userProfile['display_name'] ?? 'Non défini'}');
      }
      
      // Récupérer les informations de rôle via la fonction RPC
      final userRoles = await _roleService.getUserRolesWithDetails(user.id);
      
      print('\nRôles attribués:');
      if (userRoles != null && userRoles.isNotEmpty) {
        for (var roleData in userRoles) {
          final roleName = roleData['roles']['name'];
          final roleDesc = roleData['roles']['description'];
          final teamId = roleData['team_id'];
          final projectId = roleData['project_id'];
          
          print('- Rôle: $roleName ($roleDesc)');
          if (teamId != null) print('  → Équipe: $teamId');
          if (projectId != null) print('  → Projet: $projectId');
          
          // Récupérer les permissions pour ce rôle
          final permissions = await _roleService.getRolePermissions(roleData['role_id']);
          
          if (permissions != null && permissions.isNotEmpty) {
            print('  Permissions:');
            for (var permData in permissions) {
              final permName = permData['permissions']['name'];
              final permDesc = permData['permissions']['description'];
              print('    • $permName: $permDesc');
            }
          }
        }
      } else {
        print('Aucun rôle attribué à cet utilisateur.');
      }
      
      // Vérifier les permissions spécifiques pour cet écran
      if (_team != null) {
        print('\nPermissions pour cette équipe:');
        final hasReadTeam = await _roleService.hasPermission('read_team', teamId: _team!.id);
        print('- "read_team": ${hasReadTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
        
        final hasUpdateTeam = await _roleService.hasPermission('update_team', teamId: _team!.id);
        print('- "update_team": ${hasUpdateTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
        
        final hasDeleteTeam = await _roleService.hasPermission('delete_team', teamId: _team!.id);
        print('- "delete_team": ${hasDeleteTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
        
        final hasInviteTeamMember = await _roleService.hasPermission('invite_team_member', teamId: _team!.id);
        print('- "invite_team_member": ${hasInviteTeamMember ? 'ACCORDÉE' : 'REFUSÉE'}');
      }
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }

  Future<void> _loadTeamDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger les détails de l'équipe
      final team = await _teamService.getTeam(_team!.id);
      
      // Charger les membres de l'équipe
      final members = await _teamService.getTeamMembers(_team!.id);
      
      // Charger les projets de l'équipe
      final projects = await _teamService.getTeamProjects(_team!.id);
      
      setState(() {
        _team = team;
        _members = members;
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des détails de l\'équipe: $e';
        _isLoading = false;
      });
    }
  }

  void _showEditTeamDialog() {
    if (!_canUpdateTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de modifier cette équipe')),
      );
      return;
    }
    
    final nameController = TextEditingController(text: _team?.name);
    final descriptionController = TextEditingController(text: _team?.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'équipe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'équipe',
                  hintText: 'Entrez le nom de l\'équipe',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Entrez une description (optionnel)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom de l\'équipe est requis')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                if (_team == null) return;
                
                final updatedTeam = _team!.copyWith(
                  name: name,
                  description: description.isNotEmpty ? description : null,
                  updatedAt: DateTime.now(),
                );
                
                await _teamService.updateTeam(updatedTeam);
                _loadTeamDetails();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Équipe mise à jour avec succès')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la mise à jour de l\'équipe: $e')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTeamDialog() {
    if (!_canDeleteTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de supprimer cette équipe')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'équipe'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette équipe ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                if (_team == null) return;
                
                await _teamService.deleteTeam(_team!.id);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Équipe supprimée avec succès')),
                );
                
                Navigator.pop(context); // Retourner à l'écran des équipes
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression de l\'équipe: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ProjectToTeamDialog(
          teamId: _team!.id,
          onProjectsAdded: () {
            _loadTeamDetails();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Projet(s) ajouté(s) avec succès')),
            );
          },
        );
      },
    );
  }

  void _navigateToInviteMember() {
    if (_team == null) return;
    
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => InviteMemberScreen(team: _team!),
      ),
    ).then((_) => _loadTeamDetails());
  }

  void _showChangeRoleDialog(TeamMember member) {
    TeamMemberRole selectedRole = member.role;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Changer le rôle de ${member.userName ?? member.userEmail ?? 'Utilisateur'}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: TeamMemberRole.values.map((role) {
              return RadioListTile<TeamMemberRole>(
                title: Text(role.displayName),
                value: role,
                groupValue: selectedRole,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedRole = value;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                if (_team == null) return;
                
                final updatedMember = member.copyWith(
                  role: selectedRole,
                );
                
                await _teamService.updateTeamMember(updatedMember);
                _loadTeamDetails();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rôle mis à jour avec succès')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la mise à jour du rôle: $e')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(TeamMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: const Text('Êtes-vous sûr de vouloir retirer ce membre de l\'équipe ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                if (_team == null) return;
                
                await _teamService.removeTeamMember(member.id);
                _loadTeamDetails();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Membre retiré avec succès')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression du membre: $e')),
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

  Widget _buildMembersTab() {
    if (_team == null) {
      return const Center(child: Text('Erreur: Informations d\'équipe manquantes'));
    }
    
    return _members.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const IslamicPatternPlaceholder(
                  size: 120,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun membre pour le moment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_canInviteTeamMember)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_team == null) return;
                      
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => InviteMemberScreen(team: _team!),
                        ),
                      ).then((_) => _loadTeamDetails());
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Inviter un membre'),
                  ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final isCurrentUser = member.userId == _authService.currentUser?.id;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (member.userName ?? 'U').substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(
                    member.userName ?? 'Utilisateur',
                    style: TextStyle(
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.userEmail ?? 'Email non disponible'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(member.role).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              member.role.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getRoleColor(member.role),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(member.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              member.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(member.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: _canUpdateTeam && !isCurrentUser
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'change_role':
                                _showChangeRoleDialog(member);
                                break;
                              case 'remove':
                                _showRemoveMemberDialog(member);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'change_role',
                              child: Text('Changer le rôle'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Retirer de l\'équipe', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) {
      return Center(
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
            if (_canAddProject)
              ElevatedButton.icon(
                onPressed: _showAddProjectDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un projet'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeamDetails,
      child: ListView.builder(
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
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(projectId: project.id),
                  ),
                ).then((_) => _loadTeamDetails());
              },
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(TeamMemberRole role) {
    switch (role) {
      case TeamMemberRole.admin:
        return Colors.purple;
      case TeamMemberRole.member:
        return Colors.blue;
      case TeamMemberRole.guest:
        return Colors.orange;
    }
  }

  Color _getStatusColor(TeamMemberStatus status) {
    switch (status) {
      case TeamMemberStatus.invited:
        return Colors.amber;
      case TeamMemberStatus.active:
        return Colors.green;
      case TeamMemberStatus.inactive:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_team?.name ?? 'Détails de l\'équipe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTeamDetails();
              _checkPermissions();
            },
            tooltip: 'Actualiser',
          ),
          if (_canUpdateTeam)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditTeamDialog,
              tooltip: 'Modifier l\'équipe',
            ),
          if (_canDeleteTeam)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteTeamDialog,
              tooltip: 'Supprimer l\'équipe',
            ),
          // Autres options du menu si nécessaire
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    // _buildHeader(),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Membres'),
                        Tab(text: 'Projets'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMembersTab(),
                          _buildProjectsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    final currentTab = _tabController.index;
    
    // Logs supplémentaires
    print('DEBUG: Construction du FAB - Tab: $currentTab, CanInvite: $_canInviteTeamMember');
    
    // Si on est sur l'onglet des membres et l'utilisateur a la permission d'inviter
    if (currentTab == 0 && _canInviteTeamMember) {
      print('DEBUG: Affichage du bouton d\'invitation');
      return FloatingActionButton(
        onPressed: () {
          if (_team == null) return;
          
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => InviteMemberScreen(team: _team!),
            ),
          ).then((_) => _loadTeamDetails());
        },
        tooltip: 'Inviter un membre',
        child: const Icon(Icons.person_add),
      );
    }
    
    // Si on est sur l'onglet des projets et l'utilisateur a la permission de créer un projet
    if (currentTab == 1 && _canAddProject) {
      return FloatingActionButton(
        onPressed: () {
          if (_team == null) return;
          
          // Afficher la boîte de dialogue pour ajouter un projet
          _showAddProjectDialog();
        },
        tooltip: 'Ajouter un projet',
        child: const Icon(Icons.add),
      );
    }
    
    // Si l'utilisateur n'a pas les permissions nécessaires, ne pas afficher de FAB
    return Container();
  }
}
