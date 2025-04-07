import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../models/role.dart';

class InviteMemberScreen extends StatefulWidget {
  final Team team;

  const InviteMemberScreen({
    super.key,
    required this.team,
  });

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  String _selectedRoleId = ''; // ID du rôle sélectionné (système RBAC)
  String _selectedRoleName = ''; // Nom du rôle sélectionné (pour affichage)
  List<Role> _availableRoles = []; // Rôles disponibles dans le système RBAC
  
  List<Invitation> _pendingInvitations = [];
  bool _isLoading = false;
  bool _isLoadingInvitations = true;
  bool _isLoadingRoles = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingInvitations();
    _loadAvailableRoles();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableRoles() async {
    setState(() {
      _isLoadingRoles = true;
      _errorMessage = null;
    });

    try {
      // Vérifier si l'utilisateur actuel est un administrateur système
      bool isSystemAdmin = false;
      
      try {
        // Récupérer les rôles de l'utilisateur actuel
        final userRolesDetails = await _roleService.getUserRolesDetails();
        isSystemAdmin = userRolesDetails.any((roleDetail) => 
          roleDetail['role_name'] == 'system_admin'
        );
        
        print('DEBUG: L\'utilisateur est-il system_admin? $isSystemAdmin');
      } catch (e) {
        print('Erreur lors de la vérification des rôles de l\'utilisateur: $e');
      }
      
      // Récupérer tous les rôles disponibles via le RoleService
      final allRoles = await _roleService.getAllRoles();
      
      // Filtrer les rôles selon les règles de sécurité:
      // - Si l'utilisateur est un administrateur système, il peut voir et attribuer tous les rôles
      // - Sinon, il ne peut pas voir ni attribuer le rôle system_admin
      List<Role> filteredRoles = allRoles.where((role) {
        if (isSystemAdmin) {
          // Un admin peut voir tous les rôles
          return true;
        } else {
          // Les autres ne peuvent pas voir ni attribuer le rôle system_admin
          return role.name != 'system_admin';
        }
      }).toList();
      
      setState(() {
        _availableRoles = filteredRoles;
        
        // Sélectionner un rôle par défaut approprié
        // Préférer team_member si disponible, sinon prendre le premier rôle
        final defaultRole = filteredRoles.firstWhere(
          (role) => role.name == 'team_member',
          orElse: () => filteredRoles.isNotEmpty ? filteredRoles.first : Role(
            id: '', 
            name: 'Aucun rôle disponible'
          ),
        );
        
        _selectedRoleId = defaultRole.id;
        _selectedRoleName = defaultRole.name;
        _isLoadingRoles = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des rôles: $e';
        _isLoadingRoles = false;
      });
    }
  }

  Future<void> _loadPendingInvitations() async {
    setState(() {
      _isLoadingInvitations = true;
      _errorMessage = null;
    });

    try {
      final invitations = await _teamService.getSentInvitations(widget.team.id);
      
      setState(() {
        _pendingInvitations = invitations.where((inv) => inv.status == InvitationStatus.pending).toList();
        _isLoadingInvitations = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des invitations: $e';
        _isLoadingInvitations = false;
      });
    }
  }

  Future<void> _inviteMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final currentUser = _authService.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      // Vérifier si l'email est déjà invité
      final existingInvitation = _pendingInvitations.where((inv) => inv.email.toLowerCase() == email.toLowerCase()).toList();
      if (existingInvitation.isNotEmpty) {
        setState(() {
          _errorMessage = 'Cet email a déjà été invité';
          _isLoading = false;
        });
        return;
      }

      // Vérifier que le rôle sélectionné est valide
      if (_selectedRoleId.isEmpty) {
        setState(() {
          _errorMessage = 'Veuillez sélectionner un rôle valide';
          _isLoading = false;
        });
        return;
      }
      
      // Créer l'invitation avec les métadonnées RBAC
      final invitation = Invitation(
        email: email,
        teamId: widget.team.id,
        invitedBy: currentUser.id,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        teamName: widget.team.name,
        metadata: {
          'role_id': _selectedRoleId,
          'role_name': _selectedRoleName
        }
      );
      
      await _teamService.createInvitation(invitation);
      
      // Réinitialiser le formulaire
      _emailController.clear();
      
      // Recharger les invitations en attente
      await _loadPendingInvitations();
      
      setState(() {
        _isLoading = false;
      });
      
      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation envoyée à $email avec le rôle $_selectedRoleName')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'envoi de l\'invitation: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelInvitation(Invitation invitation) async {
    try {
      await _teamService.deleteInvitation(invitation.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation à ${invitation.email} annulée')),
      );
      
      _loadPendingInvitations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'annulation de l\'invitation: $e')),
      );
    }
  }

  Future<void> _resendInvitation(Invitation invitation) async {
    try {
      // Pour l'instant, nous simulons un renvoi en mettant à jour la date d'expiration
      final updatedInvitation = invitation.copyWith(
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      
      await _teamService.updateInvitationStatus(invitation.id, InvitationStatus.pending);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation renvoyée à ${invitation.email}')),
      );
      
      _loadPendingInvitations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du renvoi de l\'invitation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inviter un membre'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inviter un nouveau membre',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse email',
                            hintText: 'Entrez l\'adresse email du membre à inviter',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'L\'adresse email est requise';
                            }
                            
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Veuillez entrer une adresse email valide';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _isLoadingRoles 
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              value: _selectedRoleId.isEmpty ? null : _selectedRoleId,
                              decoration: const InputDecoration(
                                labelText: 'Rôle',
                                prefixIcon: Icon(Icons.person),
                              ),
                              items: _availableRoles.map((role) {
                                // Utiliser la méthode getDisplayName de la classe Role
                                String displayName = role.getDisplayName();
                                
                                return DropdownMenuItem<String>(
                                  value: role.id,
                                  child: Text(displayName),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedRoleId = value;
                                    // Trouver le nom du rôle correspondant
                                    final selectedRole = _availableRoles.firstWhere(
                                      (role) => role.id == value,
                                      orElse: () => Role(id: '', name: ''),
                                    );
                                    _selectedRoleName = selectedRole.name;
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez sélectionner un rôle';
                                }
                                return null;
                              },
                            ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _inviteMember,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Envoyer l\'invitation'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Invitations en attente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingInvitations
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingInvitations.isEmpty
                      ? const Card(
                          elevation: 1,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Aucune invitation en attente',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingInvitations.length,
                          itemBuilder: (context, index) {
                            final invitation = _pendingInvitations[index];
                            // Récupérer le nom du rôle à partir des métadonnées s'il existe
                            String roleName = 'Membre';
                            if (invitation.metadata != null && invitation.metadata!.containsKey('role_name')) {
                              String rawRoleName = invitation.metadata!['role_name'];
                              // Formatter le nom de rôle pour l'affichage
                              for (var role in _availableRoles) {
                                if (role.name == rawRoleName) {
                                  roleName = role.getDisplayName();
                                  break;
                                }
                              }
                            }
                            
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(invitation.email),
                                subtitle: Text('Rôle: $roleName'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      tooltip: 'Copier le code d\'invitation',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: invitation.token));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Code d\'invitation copié dans le presse-papier'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      tooltip: 'Renvoyer l\'invitation',
                                      onPressed: () => _resendInvitation(invitation),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Annuler l\'invitation',
                                      onPressed: () => _cancelInvitation(invitation),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
