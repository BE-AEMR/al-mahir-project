import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/role.dart';
import '../../models/user_role.dart';
import '../../models/permission.dart';
import '../../providers/role_provider.dart';
import '../../services/role_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/permission_gated.dart';

class RolesAdminScreen extends StatefulWidget {
  const RolesAdminScreen({super.key});

  @override
  State<RolesAdminScreen> createState() => _RolesAdminScreenState();
}

class _RolesAdminScreenState extends State<RolesAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RoleService _roleService = RoleService(Supabase.instance.client);
  
  List<Role> _roles = [];
  List<Permission> _permissions = [];
  List<UserRole> _userRoles = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  // Variable pour éviter les chargements en double
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Éviter les chargements simultanés
    if (_isLoadingData) {
      print('DEBUG: Chargement des données déjà en cours, ignoré');
      return;
    }
    
    _isLoadingData = true;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger les rôles et permissions
      final roles = await _roleService.getAllRoles();
      final permissions = await _roleService.getAllPermissions();
      final userRoles = await _roleService.getAllUserRoles();
      
      if (mounted) { // Vérifier si le widget est toujours monté
        setState(() {
          _roles = roles;
          _permissions = permissions;
          _userRoles = userRoles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) { // Vérifier si le widget est toujours monté
        setState(() {
          _errorMessage = 'Erreur lors du chargement des données: $e';
          _isLoading = false;
        });
      }
    } finally {
      _isLoadingData = false; // Réinitialiser le verrou
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Administration des Rôles',
        showLogo: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<RoleProvider>().getUserRolesDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Extraire le team_id du rôle system_admin s'il existe
          String? teamId;
          if (snapshot.hasData) {
            for (var role in snapshot.data!) {
              if (role['role_name'] == 'system_admin') {
                teamId = role['team_id'];
                break;
              }
            }
          }
          
          return PermissionGated(
            permissionName: 'manage_roles',
            teamId: teamId, // Passer le team_id récupéré
            fallback: const Center(
              child: Text(
                'Vous n\'avez pas l\'autorisation d\'accéder à cette page.',
                style: TextStyle(fontSize: 16),
              ),
            ),
            child: _isLoading
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
                              onPressed: _loadData,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.person_outline),
                                text: 'Utilisateurs',
                              ),
                              Tab(
                                icon: Icon(Icons.badge_outlined),
                                text: 'Rôles',
                              ),
                              Tab(
                                icon: Icon(Icons.vpn_key_outlined),
                                text: 'Permissions',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildUserRolesTab(),
                                _buildRolesTab(),
                                _buildPermissionsTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
// Fermeture du return PermissionGated
          );
// Fermeture du builder du premier FutureBuilder
        },
// Fermeture du premier FutureBuilder
      ),
      floatingActionButton: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<RoleProvider>().getUserRolesDetails(),
        builder: (context, snapshot) {
          // Extraire le team_id du rôle system_admin s'il existe
          String? teamId;
          if (snapshot.hasData) {
            for (var role in snapshot.data!) {
              if (role['role_name'] == 'system_admin') {
                teamId = role['team_id'];
                break;
              }
            }
          }
          
          return PermissionGated(
            permissionName: 'manage_roles',
            teamId: teamId, // Passer le team_id récupéré
            child: _tabController.index == 0 ? _buildAddUserRoleButton() :
                  _tabController.index == 1 ? _buildAddRoleButton() :
                  _buildAddPermissionButton(),
          );
        },
      ),
    );
  }

  Widget _buildUserRolesTab() {
    if (_userRoles.isEmpty) {
      return const Center(
        child: Text('Aucun rôle utilisateur trouvé'),
      );
    }

    return ListView.builder(
      itemCount: _userRoles.length,
      itemBuilder: (context, index) {
        final userRole = _userRoles[index];
        return _buildUserRoleCard(userRole);
      },
    );
  }

  Widget _buildUserRoleCard(UserRole userRole) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => _confirmDeleteUserRole(userRole),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Supprimer',
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(_getRoleContextIcon(userRole)),
          ),
          title: Text(userRole.userProfile?.getDisplayName() ?? userRole.userId),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rôle: ${userRole.role?.getDisplayName() ?? "Inconnu"}'),
              Text(_getRoleSubtitle(userRole)),
            ],
          ),
          onTap: () {
            // Modifier pour afficher la fenêtre d'édition au lieu des détails
            _showEditUserRoleDialog(userRole);
          },
        ),
      ),
    );
  }

  Widget _buildRolesTab() {
    if (_roles.isEmpty) {
      return const Center(
        child: Text('Aucun rôle trouvé'),
      );
    }

    return ListView.builder(
      itemCount: _roles.length,
      itemBuilder: (context, index) {
        final role = _roles[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.badge),
            ),
            title: Text(role.getDisplayName()),
            subtitle: Text(role.description ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => _showRoleDetailsDialog(role),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionsTab() {
    if (_permissions.isEmpty) {
      return const Center(
        child: Text('Aucune permission trouvée'),
      );
    }

    // Grouper les permissions par type de ressource
    final Map<String, List<Permission>> groupedPermissions = {};
    for (var permission in _permissions) {
      if (!groupedPermissions.containsKey(permission.resourceType)) {
        groupedPermissions[permission.resourceType] = [];
      }
      groupedPermissions[permission.resourceType]!.add(permission);
    }

    return ListView.builder(
      itemCount: groupedPermissions.length,
      itemBuilder: (context, index) {
        final resourceType = groupedPermissions.keys.elementAt(index);
        final permissions = groupedPermissions[resourceType]!;
        
        return ExpansionTile(
          title: Text(
            resourceType.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: permissions
              .map(
                (permission) => ListTile(
                  leading: Icon(_getIconForAction(permission.action)),
                  title: Text(permission.getDisplayName()),
                  subtitle: Text('${permission.action} sur ${permission.resourceType}'),
                ),
              )
              .toList(),
        );
      },
    );
  }

  IconData _getIconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'create':
        return Icons.add_circle_outline;
      case 'read':
        return Icons.visibility;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete_outline;
      case 'manage':
        return Icons.settings;
      default:
        return Icons.vpn_key;
    }
  }

  Widget _buildAddUserRoleButton() {
    return FloatingActionButton(
      onPressed: () {
        _showAssignRoleDialog();
      },
      child: const Icon(Icons.add),
    );
  }

  Widget _buildAddRoleButton() {
    return FloatingActionButton(
      onPressed: () {
        _showAddRoleDialog();
      },
      child: const Icon(Icons.add),
    );
  }

  Widget _buildAddPermissionButton() {
    return FloatingActionButton(
      onPressed: () {
        _showAddPermissionDialog();
      },
      child: const Icon(Icons.add),
    );
  }

  Future<void> _showAssignRoleDialog() async {
    String? selectedUserId;
    String? selectedRoleId;
    String? selectedTeamId;
    String? selectedProjectId;
    
    // Récupérer la liste des utilisateurs
    List<Map<String, dynamic>> users = [];
    try {
      users = await _roleService.getAllUsers();
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs: $e');
    }
    
    // Récupérer la liste des équipes
    List<Map<String, dynamic>> teams = [];
    try {
      final response = await Supabase.instance.client.from('teams').select('id, name').order('name');
      teams = response;
    } catch (e) {
      print('Erreur lors de la récupération des équipes: $e');
    }
    
    // Récupérer la liste des projets
    List<Map<String, dynamic>> projects = [];
    try {
      final response = await Supabase.instance.client.from('projects').select('id, name').order('name');
      projects = response;
    } catch (e) {
      print('Erreur lors de la récupération des projets: $e');
    }
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Attribuer un rôle à un utilisateur'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélection de l'utilisateur
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Utilisateur',
                        hintText: 'Sélectionnez un utilisateur',
                      ),
                      value: selectedUserId,
                      items: users.map((user) {
                        final displayName = user['display_name'] ?? user['email'] ?? user['id'];
                        return DropdownMenuItem<String>(
                          value: user['id'],
                          child: Text(displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedUserId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Veuillez sélectionner un utilisateur' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Sélection du rôle
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Rôle',
                        hintText: 'Sélectionnez un rôle',
                      ),
                      value: selectedRoleId,
                      items: _roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role.id,
                          child: Text(role.getDisplayName()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedRoleId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Veuillez sélectionner un rôle' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Contexte: Équipe (optionnel)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Équipe (optionnel)',
                        hintText: 'Sélectionnez une équipe',
                      ),
                      value: selectedTeamId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Aucune équipe (global)'),
                        ),
                        ...teams.map((team) {
                          return DropdownMenuItem<String>(
                            value: team['id'],
                            child: Text(team['name']),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedTeamId = value;
                          // Réinitialiser le projet si l'équipe change
                          selectedProjectId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Contexte: Projet (optionnel)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Projet (optionnel)',
                        hintText: 'Sélectionnez un projet',
                      ),
                      value: selectedProjectId,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Aucun projet'),
                        ),
                        ...projects
                            .where((project) => selectedTeamId == null || 
                                  project['team_id'] == selectedTeamId)
                            .map((project) {
                          return DropdownMenuItem<String>(
                            value: project['id'],
                            child: Text(project['name']),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedProjectId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUserId != null && selectedRoleId != null) {
                      // Fermer le dialogue
                      Navigator.of(context).pop();
                      
                      // Afficher un indicateur de chargement
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        // Récupérer le nom du rôle pour l'affichage
                        final roleName = _roles
                            .firstWhere((r) => r.id == selectedRoleId)
                            .name;
                        
                        // Attribuer le rôle à l'utilisateur
                        final success = await _roleService.assignRole(
                          userId: selectedUserId!,
                          roleName: roleName,
                          teamId: selectedTeamId,
                          projectId: selectedProjectId,
                        );
                        
                        if (success) {
                          // Recharger les données pour afficher le nouveau rôle utilisateur
                          await _loadData();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rôle attribué avec succès'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Erreur lors de l\'attribution du rôle'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        // Masquer l'indicateur de chargement
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    } else {
                      // Afficher un message si les champs requis ne sont pas remplis
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez sélectionner un utilisateur et un rôle'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: const Text('Attribuer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddRoleDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un nouveau rôle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du rôle',
                    hintText: 'ex: project_manager',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Le nom du rôle est requis';
                    }
                    if (value.contains(' ')) {
                      return 'Le nom ne doit pas contenir d\'espaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'ex: Gestionnaire de projets avec accès en écriture',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Fermer le dialogue et montrer un indicateur de chargement
                  Navigator.of(context).pop();
                  
                  // Afficher un indicateur de chargement
                  setState(() {
                    _isLoading = true;
                  });
                  
                  try {
                    // Appeler la méthode pour créer le rôle
                    final success = await _createRole(
                      nameController.text.trim(),
                      descriptionController.text.trim(),
                    );
                    
                    if (success) {
                      // Recharger les données pour afficher le nouveau rôle
                      await _loadData();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rôle créé avec succès'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Erreur lors de la création du rôle'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    // Masquer l'indicateur de chargement
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddPermissionDialog() async {
    // Cette méthode afficherait un dialogue pour ajouter une nouvelle permission
    // Pour le moment, on affiche simplement une notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité à implémenter: Ajouter une permission'),
      ),
    );
  }

  Future<void> _showDeleteUserRoleDialog(UserRole userRole) async {
    // Cette méthode afficherait un dialogue pour confirmer la suppression
    // Pour le moment, on affiche simplement une notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité à implémenter: Supprimer un rôle utilisateur'),
      ),
    );
  }

  Future<void> _showRoleDetailsDialog(Role role) async {
    // Récupérer les permissions associées à ce rôle
    List<Permission> rolePermissions = [];
    try {
      final response = await Supabase.instance.client
          .from('role_permissions')
          .select('permissions (*)')
          .eq('role_id', role.id);
      
      rolePermissions = response
          .map((item) => Permission.fromJson(item['permissions']))
          .toList()
          .cast<Permission>();
    } catch (e) {
      print('Erreur lors de la récupération des permissions du rôle: $e');
    }
    
    // Trier les permissions par type de ressource
    final Map<String, List<Permission>> groupedPermissions = {};
    for (var permission in rolePermissions) {
      if (!groupedPermissions.containsKey(permission.resourceType)) {
        groupedPermissions[permission.resourceType] = [];
      }
      groupedPermissions[permission.resourceType]!.add(permission);
    }
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rôle: ${role.getDisplayName()}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (role.description != null && role.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Description: ${role.description}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                const Divider(),
                const Text(
                  'Permissions associées:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: rolePermissions.isEmpty
                      ? const Center(
                          child: Text('Aucune permission associée à ce rôle'),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: groupedPermissions.entries.map((entry) {
                            return ExpansionTile(
                              title: Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              children: entry.value
                                  .map(
                                    (permission) => ListTile(
                                      leading: Icon(_getIconForAction(permission.action)),
                                      title: Text(permission.getDisplayName()),
                                      subtitle: Text('${permission.action} sur ${permission.resourceType}'),
                                    ),
                                  )
                                  .toList(),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditRoleDialog(role);
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditRoleDialog(Role role) async {
    final TextEditingController descriptionController = TextEditingController(text: role.description);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    
    List<Permission> allPermissions = _permissions;
    List<String> selectedPermissionIds = [];
    
    // Récupérer les permissions actuellement associées au rôle
    try {
      final response = await Supabase.instance.client
          .from('role_permissions')
          .select('permission_id')
          .eq('role_id', role.id);
      
      selectedPermissionIds = response
          .map((item) => item['permission_id'] as String)
          .toList();
    } catch (e) {
      print('Erreur lors de la récupération des permissions du rôle: $e');
    }
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Modifier le rôle: ${role.name}'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Permissions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allPermissions.length,
                          itemBuilder: (context, index) {
                            final permission = allPermissions[index];
                            final isSelected = selectedPermissionIds.contains(permission.id);
                            
                            return CheckboxListTile(
                              title: Text(permission.getDisplayName()),
                              subtitle: Text('${permission.action} sur ${permission.resourceType}'),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selectedPermissionIds.add(permission.id);
                                  } else {
                                    selectedPermissionIds.remove(permission.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Fermer le dialogue et montrer un indicateur de chargement
                      Navigator.of(context).pop();
                      
                      // Afficher un indicateur de chargement
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        // Appeler la méthode pour mettre à jour le rôle
                        final success = await _updateRole(
                          role.id,
                          descriptionController.text.trim(),
                          selectedPermissionIds,
                        );
                        
                        if (success) {
                          // Recharger les données pour afficher les modifications
                          await _loadData();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rôle mis à jour avec succès'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Erreur lors de la mise à jour du rôle'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        // Masquer l'indicateur de chargement
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Met à jour un rôle existant et ses permissions
  Future<bool> _updateRole(String roleId, String description, List<String> permissionIds) async {
    try {
      // Mise à jour de la table roles
      await Supabase.instance.client.from('roles').update({
        'description': description,
      }).eq('id', roleId);
      
      // Supprimer toutes les permissions existantes pour ce rôle
      await Supabase.instance.client
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId);
      
      // Ajouter les nouvelles permissions sélectionnées
      if (permissionIds.isNotEmpty) {
        final List<Map<String, dynamic>> rolePermissions = permissionIds
            .map((permissionId) => {
                  'role_id': roleId,
                  'permission_id': permissionId,
                })
            .toList();
        
        await Supabase.instance.client
            .from('role_permissions')
            .insert(rolePermissions);
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la mise à jour du rôle: $e');
      return false;
    }
  }

  /// Crée un nouveau rôle dans la base de données
  Future<bool> _createRole(String name, String description) async {
    try {
      // Insérer le nouveau rôle dans la table 'roles'
      await Supabase.instance.client.from('roles').insert({
        'name': name,
        'description': description,
      });
      
      return true;
    } catch (e) {
      print('Erreur lors de la création du rôle: $e');
      return false;
    }
  }

  // Méthode d'aide pour générer le sous-titre du rôle utilisateur en fonction du contexte
  String _getRoleSubtitle(UserRole userRole) {
    if (userRole.isGlobal) {
      return 'Global (toutes équipes/projets)';
    } else if (userRole.isTeamSpecific && userRole.team != null) {
      return 'Équipe: ${userRole.team!.name}';
    } else if (userRole.isProjectSpecific && userRole.project != null) {
      return 'Projet: ${userRole.project!.name}';
    } else if (userRole.isTeamProjectSpecific && userRole.team != null) {
      final projectInfo = userRole.associatedProjects != null && userRole.associatedProjects!.isNotEmpty 
          ? '${userRole.associatedProjects!.length} projet(s)' 
          : userRole.project?.name ?? 'Projets spécifiques';
      
      return 'Équipe: ${userRole.team!.name} | ${projectInfo}';
    } else {
      return 'Contexte non spécifié';
    }
  }

  // Méthode pour obtenir une icône en fonction du contexte du rôle
  IconData _getRoleContextIcon(UserRole userRole) {
    if (userRole.projectId != null) {
      return Icons.assignment;
    } else if (userRole.teamId != null) {
      return Icons.group;
    } else {
      return Icons.public;
    }
  }

  // Méthode pour supprimer un rôle utilisateur
  Future<void> _deleteUserRole(UserRole userRole) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await Supabase.instance.client
          .from('user_roles')
          .delete()
          .eq('id', userRole.id);
      
      // Recharger les données pour mettre à jour l'interface
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rôle utilisateur supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression du rôle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Méthode pour afficher un dialogue de confirmation avant la suppression
  Future<void> _confirmDeleteUserRole(UserRole userRole) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer le rôle "${userRole.role?.getDisplayName()}" '
            'attribué à "${userRole.userProfile?.getDisplayName() ?? "cet utilisateur"}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _deleteUserRole(userRole);
    }
  }

  Future<void> _showEditUserRoleDialog(UserRole userRole) async {
    print('=== DEBUG EDIT USER ROLE === DÉBUT ÉDITION UTILISATEUR ===');
    print('=== DEBUG EDIT USER ROLE === UserId: ${userRole.userId}');
    print('=== DEBUG EDIT USER ROLE === UserRoleId: ${userRole.id}');
    print('=== DEBUG EDIT USER ROLE === RoleId: ${userRole.roleId}');
    print('=== DEBUG EDIT USER ROLE === TeamId: ${userRole.teamId}');
    print('=== DEBUG EDIT USER ROLE === ProjectId: ${userRole.projectId}');
    
    if (userRole.associatedProjects != null) {
      print('=== DEBUG EDIT USER ROLE === Projets associés: ${userRole.associatedProjects?.length ?? 0}');
      for (var project in userRole.associatedProjects ?? []) {
        print('=== DEBUG EDIT USER ROLE === Projet associé: ${project['id']} - ${project['name']}');
      }
    } else {
      print('=== DEBUG EDIT USER ROLE === Aucun projet associé trouvé dans userRole.associatedProjects');
    }
    
    String? selectedRoleId = userRole.roleId;
    String? selectedTeamId = userRole.teamId;
    // Modifier pour supporter une liste de projets sélectionnés
    List<String> selectedProjectIds = [];
    
    // Initialiser la liste des projets sélectionnés
    if (userRole.associatedProjects != null && userRole.associatedProjects!.isNotEmpty) {
      print('=== DEBUG EDIT USER ROLE === Initialisation avec les projets associés');
      // Utiliser les projets associés s'ils existent
      selectedProjectIds = userRole.associatedProjects!
          .map<String>((project) => project['id'] as String)
          .toList();
      print('=== DEBUG EDIT USER ROLE === Projets initialisés: $selectedProjectIds');
    } else if (userRole.projectId != null) {
      print('=== DEBUG EDIT USER ROLE === Initialisation avec le projet unique');
      // Sinon, utiliser le projet principal s'il existe
      selectedProjectIds.add(userRole.projectId!);
      print('=== DEBUG EDIT USER ROLE === Projet initialisé: ${userRole.projectId}');
    }
    
    // Récupérer la liste des équipes
    List<Map<String, dynamic>> teams = [];
    try {
      final response = await Supabase.instance.client.from('teams').select('id, name').order('name');
      teams = response;
    } catch (e) {
      print('Erreur lors de la récupération des équipes: $e');
    }
    
    // Récupérer tous les projets (utilisé seulement si aucune équipe n'est sélectionnée)
    List<Map<String, dynamic>> allProjects = [];
    // Liste des projets filtrés en fonction de l'équipe sélectionnée
    List<Map<String, dynamic>> filteredProjects = [];
    
    try {
      // Récupérer tous les projets
      final response = await Supabase.instance.client.from('projects').select('id, name').order('name');
      allProjects = response;
      
      // Si une équipe est sélectionnée au départ, filtrer les projets
      if (selectedTeamId != null) {
        // Récupérer les projets associés à l'équipe via la table de jointure team_projects
        final teamProjectsResponse = await Supabase.instance.client
            .from('team_projects')
            .select('project_id')
            .eq('team_id', selectedTeamId);
        
        final projectIds = teamProjectsResponse.map<String>((json) => json['project_id'] as String).toList();
        
        print('=== DEBUG EDIT USER ROLE === Équipe changée pour: $selectedTeamId');
        print('=== DEBUG EDIT USER ROLE === Projets de l\'équipe: ${projectIds.length}');
        
        // Filtrer les projets pour ne garder que ceux associés à l'équipe
        filteredProjects = allProjects.where((project) => 
          projectIds.contains(project['id'])).toList();
      } else {
        // Si aucune équipe n'est sélectionnée, utiliser tous les projets
        filteredProjects = allProjects;
      }
    } catch (e) {
      print('Erreur lors de la récupération des projets: $e');
    }
    
    if (!mounted) return;
    
    // Définir les styles cohérents pour tout le formulaire
    final TextStyle labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).primaryColor,
    );
    
    final TextStyle infoStyle = TextStyle(
      fontSize: 13,
      color: Colors.grey[700],
    );
    
    final TextStyle hintStyle = TextStyle(
      fontSize: 12,
      fontStyle: FontStyle.italic,
      color: Colors.grey[600],
    );
    
    final InputDecoration inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Modifier le rôle de ${userRole.userProfile?.getDisplayName() ?? userRole.userId}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420, // Ajuster la hauteur pour s'adapter au contenu
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Information de l'utilisateur avec style réduit
                    RichText(
                      text: TextSpan(
                        style: infoStyle,
                        children: [
                          TextSpan(
                            text: 'Utilisateur: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: userRole.userProfile?.getDisplayName() ?? userRole.userId,
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: infoStyle,
                        children: [
                          TextSpan(
                            text: 'Email: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: userRole.userProfile?.email ?? "Non disponible",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Sélection du rôle
                    Text('Rôle', style: labelStyle),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      decoration: inputDecoration,
                      isExpanded: true,
                      isDense: true,
                      value: selectedRoleId,
                      items: _roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role.id,
                          child: Text(
                            role.getDisplayName(),
                            style: TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedRoleId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Veuillez sélectionner un rôle' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    // Contexte: Équipe (optionnel)
                    Text('Équipe (optionnel)', style: labelStyle),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      decoration: inputDecoration,
                      isExpanded: true,
                      isDense: true,
                      value: selectedTeamId,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Aucune équipe (global)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        ...teams.map((team) {
                          return DropdownMenuItem<String>(
                            value: team['id'],
                            child: Text(
                              team['name'],
                              style: TextStyle(fontSize: 13),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) async {
                        // Mise à jour dynamique des projets disponibles lorsque l'équipe change
                        if (value != selectedTeamId) {
                          // Si une équipe est sélectionnée, récupérer ses projets associés
                          if (value != null) {
                            try {
                              // Récupérer les projets associés à l'équipe via la table de jointure
                              final teamProjectsResponse = await Supabase.instance.client
                                  .from('team_projects')
                                  .select('project_id')
                                  .eq('team_id', value);
                              
                              final projectIds = teamProjectsResponse.map<String>(
                                (json) => json['project_id'] as String).toList();
                              
                              // Filtrer les projets pour ne garder que ceux associés à l'équipe
                              filteredProjects = allProjects.where((project) => 
                                projectIds.contains(project['id'])).toList();
                            } catch (e) {
                              print('Erreur lors de la récupération des projets de l\'équipe: $e');
                              filteredProjects = [];
                            }
                          } else {
                            // Si aucune équipe n'est sélectionnée, utiliser tous les projets
                            filteredProjects = allProjects;
                          }
                          
                          // Vider la liste des projets sélectionnés
                          selectedProjectIds = [];
                        }
                        
                        setState(() {
                          selectedTeamId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Titre pour la section projets
                    Text('Projets (optionnel)', style: labelStyle),
                    
                    // Message d'aide plus discret
                    Text(
                      'Sélectionnez un ou plusieurs projets',
                      style: hintStyle,
                    ),
                    const SizedBox(height: 6),
                    
                    // Barre de recherche pour les projets
                    TextField(
                      decoration: inputDecoration.copyWith(
                        hintText: 'Rechercher un projet...',
                        hintStyle: hintStyle,
                        prefixIcon: Icon(Icons.search, size: 18),
                        prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      style: TextStyle(fontSize: 13),
                      onChanged: (value) {
                        final searchTerm = value.toLowerCase();
                        setState(() {
                          if (value.isEmpty) {
                            // Si la recherche est vide, afficher tous les projets filtrés
                            // déjà disponibles
                          } else {
                            // Si une recherche est en cours, filtrer davantage les projets
                            filteredProjects = filteredProjects.where((project) => 
                              project['name'].toString().toLowerCase().contains(searchTerm)).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    
                    // Liste de projets sélectionnables
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: filteredProjects.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun projet disponible',
                                style: hintStyle,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredProjects.length,
                              padding: EdgeInsets.symmetric(vertical: 4),
                              itemBuilder: (context, index) {
                                final project = filteredProjects[index];
                                final isSelected = selectedProjectIds.contains(project['id']);
                                
                                return AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  margin: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                                      : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected 
                                        ? Theme.of(context).primaryColor.withOpacity(0.3)
                                        : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    horizontalTitleGap: 8,
                                    leading: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[200],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check : Icons.add,
                                        color: isSelected ? Colors.white : Colors.grey[600],
                                        size: 14,
                                      ),
                                    ),
                                    title: Text(
                                      project['name'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          // Si déjà sélectionné, retirer de la liste
                                          selectedProjectIds.remove(project['id']);
                                        } else {
                                          // Sinon, ajouter à la liste
                                          selectedProjectIds.add(project['id']);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    
                    // Afficher les projets sélectionnés
                    if (selectedProjectIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedProjectIds.map((projectId) {
                          final projectName = filteredProjects
                            .firstWhere((p) => p['id'] == projectId, orElse: () => {'name': 'Inconnu'})['name'];
                          
                          return Chip(
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            labelStyle: TextStyle(fontSize: 11),
                            labelPadding: EdgeInsets.symmetric(horizontal: 4),
                            padding: EdgeInsets.all(0),
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            deleteIconColor: Theme.of(context).primaryColor,
                            label: Text(projectName),
                            deleteIcon: Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() {
                                selectedProjectIds.remove(projectId);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Annuler',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedRoleId != null) {
                      // Fermer le dialogue
                      Navigator.of(context).pop();
                      
                      // Afficher un indicateur de chargement
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        print('=== DEBUG EDIT USER ROLE === SAUVEGARDE DU RÔLE UTILISATEUR ===');
                        print('=== DEBUG EDIT USER ROLE === RoleId: $selectedRoleId');
                        print('=== DEBUG EDIT USER ROLE === TeamId: $selectedTeamId');
                        print('=== DEBUG EDIT USER ROLE === Projets: $selectedProjectIds (${selectedProjectIds.length})');
                        
                        // 1. Mettre à jour l'enregistrement dans user_roles (sans project_id)
                        await Supabase.instance.client
                            .from('user_roles')
                            .update({
                              'role_id': selectedRoleId,
                              'team_id': selectedTeamId,
                              'project_id': null, // Plus besoin de project_id dans cette table
                            })
                            .eq('id', userRole.id);
                        
                        print('=== DEBUG EDIT USER ROLE === user_roles mis à jour');
                        
                        // 2. Supprimer toutes les relations projet existantes pour cet user_role
                        await Supabase.instance.client
                            .from('user_role_projects')
                            .delete()
                            .eq('user_role_id', userRole.id);
                        
                        print('=== DEBUG EDIT USER ROLE === anciennes relations user_role_projects supprimées');
                        
                        // 3. Ajouter les nouvelles relations projet si nécessaire
                        if (selectedProjectIds.isNotEmpty) {
                          final projectEntries = selectedProjectIds.map((projectId) => {
                            'user_role_id': userRole.id,
                            'project_id': projectId,
                          }).toList();
                          
                          print('=== DEBUG EDIT USER ROLE === Création de ${projectEntries.length} nouvelles relations user_role_projects');
                          
                          await Supabase.instance.client
                              .from('user_role_projects')
                              .insert(projectEntries);
                          
                          print('=== DEBUG EDIT USER ROLE === Nouvelles relations user_role_projects créées');
                        }
                        
                        // Utiliser Future.delayed pour laisser le dialogue se fermer complètement avant de recharger
                        Future.delayed(Duration(milliseconds: 300), () {
                          // Recharger les données pour afficher les modifications
                          if (mounted) { // Vérifier si le widget est toujours monté
                            print('=== DEBUG EDIT USER ROLE === Rechargement des données');
                            _loadData();
                            print('=== DEBUG EDIT USER ROLE === Données rechargées');
                            
                            // Afficher le message de succès
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Rôle utilisateur mis à jour avec succès pour ${selectedProjectIds.length} projet(s)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        });
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur lors de la mise à jour du rôle: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        // Masquer l'indicateur de chargement
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Enregistrer',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
              actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              contentPadding: EdgeInsets.all(16),
              titlePadding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          },
        );
      },
    );
  }
}
