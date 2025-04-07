import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../widgets/islamic_patterns.dart';
import 'team_detail_screen.dart';
import 'create_team_screen.dart';
import 'invitations_screen.dart';
import 'join_team_screen.dart';
import 'widgets/modern_team_cards.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  
  List<Team> _teams = [];
  List<Invitation> _invitations = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _canCreateTeam = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkPermissions();
    
    // Tracer les informations sur l'utilisateur au démarrage de l'écran
    _logUserAccessInfo();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final teams = await _teamService.getTeams();
      final invitations = await _teamService.getReceivedInvitations();
      
      setState(() {
        _teams = teams;
        _invitations = invitations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des équipes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final canCreateTeam = await _roleService.hasPermission('create_team');
      setState(() {
        _canCreateTeam = canCreateTeam;
      });
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
    }
  }

  void _showCreateTeamDialog() {
    if (_canCreateTeam) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateTeamScreen(),
        ),
      ).then((_) => _loadData());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de créer une équipe')),
      );
    }
  }

  Future<void> _handleInvitation(Invitation invitation, bool accept) async {
    try {
      if (accept) {
        await _teamService.acceptInvitation(invitation.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation à l\'équipe "${invitation.teamName}" acceptée')),
        );
      } else {
        await _teamService.rejectInvitation(invitation.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation à l\'équipe "${invitation.teamName}" rejetée')),
        );
      }
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showJoinTeamDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinTeamScreen(),
      ),
    ).then((_) => _loadData());
  }

  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: TeamsScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (TeamsScreen) =====');
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
      
      // Vérifier spécifiquement les permissions pour l'écran des équipes
      final hasReadTeam = await _roleService.hasPermission('read_team');
      final hasCreateTeam = await _roleService.hasPermission('create_team');
      
      print('\nPermission "read_team" (accès équipes): ${hasReadTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
      print('Permission "create_team" (création équipes): ${hasCreateTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }

  Widget _buildTeamsList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          if (_invitations.isNotEmpty)
            SliverToBoxAdapter(
              child: ModernInvitationCard(
                invitations: _invitations,
                onInvitationAction: _handleInvitation,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _teams.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const IslamicPatternPlaceholder(
                            size: 150,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Vous n\'avez pas encore d\'équipe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Créez une équipe pour collaborer avec d\'autres utilisateurs',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showCreateTeamDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer une équipe'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _showJoinTeamDialog,
                            icon: const Icon(Icons.join_inner),
                            label: const Text('Rejoindre une équipe'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final team = _teams[index];
                        return ModernTeamCard(
                          team: team,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamDetailScreen(team: team),
                              ),
                            ).then((_) => _loadData());
                          },
                        );
                      },
                      childCount: _teams.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes équipes'),
        actions: [
          if (_invitations.isNotEmpty)
            Badge(
              label: Text(_invitations.length.toString()),
              child: IconButton(
                icon: const Icon(Icons.mail),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvitationsScreen(),
                    ),
                  ).then((_) => _loadData());
                },
                tooltip: 'Invitations',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildTeamsList(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_canCreateTeam)
            FloatingActionButton(
              onPressed: _showCreateTeamDialog,
              heroTag: 'createTeam',
              tooltip: 'Créer une équipe',
              child: const Icon(Icons.group_add),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _showJoinTeamDialog,
            tooltip: 'Rejoindre une équipe',
            heroTag: 'joinTeam',
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }
}
