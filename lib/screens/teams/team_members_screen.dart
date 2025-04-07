import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/islamic_patterns.dart';

class TeamMembersScreen extends StatefulWidget {
  final Team team;
  final bool isAdmin;

  const TeamMembersScreen({
    super.key,
    required this.team,
    required this.isAdmin,
  });

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  
  List<TeamMember> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _canManageMembers = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _checkPermissions();
    _getCurrentUser();
    
    // Journalisation RBAC
    _logUserAccessInfo();
  }
  
  Future<void> _getCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }
  
  Future<void> _checkPermissions() async {
    try {
      final canUpdateTeam = await _roleService.hasPermission('update_team', teamId: widget.team.id);
      final canInviteMember = await _roleService.hasPermission('invite_team_member', teamId: widget.team.id);
      
      setState(() {
        // Permission de gérer les membres si l'utilisateur peut mettre à jour l'équipe
        // ou inviter des membres
        _canManageMembers = canUpdateTeam || canInviteMember;
      });
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
    }
  }

  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('ERREUR: TeamMembersScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (TeamMembersScreen) =====');
      print('ID utilisateur: ${user.id}');
      print('Email: ${user.email}');
      print('Équipe consultée: ${widget.team.id} (${widget.team.name})');
      
      // Vérifier spécifiquement les permissions pour l'écran des membres d'équipe
      final hasReadTeam = await _roleService.hasPermission('read_team', teamId: widget.team.id);
      final hasUpdateTeam = await _roleService.hasPermission('update_team', teamId: widget.team.id);
      final hasInviteTeamMember = await _roleService.hasPermission('invite_team_member', teamId: widget.team.id);
      
      print('\nPermissions pour cette équipe:');
      print('- "read_team": ${hasReadTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
      print('- "update_team": ${hasUpdateTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
      print('- "invite_team_member": ${hasInviteTeamMember ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final members = await _teamService.getTeamMembers(widget.team.id);
      
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des membres: $e';
        _isLoading = false;
      });
    }
  }

  void _showChangeRoleDialog(TeamMember member) {
    if (!_canManageMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de modifier les rôles des membres')),
      );
      return;
    }
    
    // Ne pas permettre à un utilisateur de modifier son propre rôle
    if (member.userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas modifier votre propre rôle')),
      );
      return;
    }
    
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
                final updatedMember = member.copyWith(role: selectedRole);
                await _teamService.updateTeamMember(updatedMember);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rôle mis à jour avec succès')),
                );
                
                _loadMembers();
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
    if (!_canManageMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de retirer des membres')),
      );
      return;
    }
    
    // Ne pas permettre à un utilisateur de se retirer lui-même
    if (member.userId == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas vous retirer vous-même de l\'équipe')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text('Êtes-vous sûr de vouloir retirer ${member.userName ?? member.userEmail ?? 'ce membre'} de l\'équipe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _teamService.removeTeamMember(member.id);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Membre retiré avec succès')),
                );
                
                _loadMembers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors du retrait du membre: $e')),
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
        title: Text('Membres de ${widget.team.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembers,
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
                        onPressed: _loadMembers,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _members.isEmpty
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
                            'Aucun membre dans cette équipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          widget.isAdmin
                            ? const Text(
                                'Invitez des membres pour collaborer',
                                textAlign: TextAlign.center,
                              )
                            : const Text(
                                'L\'administrateur de l\'équipe peut inviter des membres',
                                textAlign: TextAlign.center,
                              ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isCurrentUser = member.userId == _currentUserId;
                        
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
                            trailing: (_canManageMembers && !isCurrentUser)
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
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Changer le rôle'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Retirer de l\'équipe', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : isCurrentUser 
                                    ? const Chip(
                                        label: Text('Vous'),
                                        backgroundColor: Colors.blue,
                                        labelStyle: TextStyle(color: Colors.white),
                                      )
                                    : null,
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
}
