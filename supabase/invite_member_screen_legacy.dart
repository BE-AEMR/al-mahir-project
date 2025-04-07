import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/auth_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  TeamMemberRole _selectedRole = TeamMemberRole.member;
  List<Invitation> _pendingInvitations = [];
  bool _isLoading = false;
  bool _isLoadingInvitations = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingInvitations();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

      // Générer un token unique pour l'invitation
      final token = const Uuid().v4();
      
      // Créer l'invitation
      final invitation = Invitation(
        id: const Uuid().v4(),
        email: email,
        teamId: widget.team.id,
        invitedBy: currentUser.id,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        token: token,
        status: InvitationStatus.pending,
        teamName: widget.team.name,
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
        SnackBar(content: Text('Invitation envoyée à $email')),
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
                        DropdownButtonFormField<TeamMemberRole>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rôle',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: TeamMemberRole.values.map((role) {
                            return DropdownMenuItem<TeamMemberRole>(
                              value: role,
                              child: Text(role.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRole = value;
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
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              child: ListTile(
                                title: Text(invitation.email),
                                subtitle: Text(
                                  'Expire le ${invitation.expiresAt.day}/${invitation.expiresAt.month}/${invitation.expiresAt.year}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 20),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: invitation.token));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Token copié dans le presse-papier')),
                                        );
                                      },
                                      tooltip: 'Copier le token',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: () => _resendInvitation(invitation),
                                      tooltip: 'Renvoyer l\'invitation',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _cancelInvitation(invitation),
                                      tooltip: 'Annuler l\'invitation',
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
