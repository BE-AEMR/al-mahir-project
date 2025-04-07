import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../widgets/islamic_patterns.dart';
import 'team_detail_screen.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final TeamService _teamService = TeamService();
  
  List<Invitation> _invitations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invitations = await _teamService.getReceivedInvitations();
      
      setState(() {
        _invitations = invitations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des invitations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleInvitation(Invitation invitation, bool accept) async {
    try {
      if (accept) {
        await _teamService.acceptInvitation(invitation.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation à l\'équipe "${invitation.teamName}" acceptée'),
            action: SnackBarAction(
              label: 'Voir l\'équipe',
              onPressed: () async {
                // Récupérer les détails de l'équipe
                final team = await _teamService.getTeam(invitation.teamId);
                
                // Naviguer vers l'écran de détail de l'équipe
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeamDetailScreen(team: team),
                    ),
                  ).then((_) => _loadInvitations());
                }
              },
            ),
          ),
        );
      } else {
        await _teamService.rejectInvitation(invitation.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation à l\'équipe "${invitation.teamName}" rejetée')),
        );
      }
      
      _loadInvitations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations reçues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvitations,
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
                        onPressed: _loadInvitations,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _invitations.isEmpty
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
                            'Aucune invitation en attente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vous n\'avez pas d\'invitation à rejoindre une équipe pour le moment',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _invitations.length,
                      itemBuilder: (context, index) {
                        final invitation = _invitations[index];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.group, size: 24),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        invitation.teamName ?? 'Équipe inconnue',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Vous avez été invité à rejoindre cette équipe'),
                                const SizedBox(height: 4),
                                Text(
                                  'Expire le ${invitation.expiresAt.day}/${invitation.expiresAt.month}/${invitation.expiresAt.year}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _handleInvitation(invitation, false),
                                      child: const Text('Refuser'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _handleInvitation(invitation, true),
                                      child: const Text('Accepter'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
