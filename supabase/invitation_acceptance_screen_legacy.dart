import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';

class InvitationAcceptanceScreen extends StatefulWidget {
  final String token;
  final String teamId;

  const InvitationAcceptanceScreen({
    super.key,
    required this.token,
    required this.teamId,
  });

  @override
  State<InvitationAcceptanceScreen> createState() => _InvitationAcceptanceScreenState();
}

class _InvitationAcceptanceScreenState extends State<InvitationAcceptanceScreen> {
  final TeamService _teamService = TeamService();
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _teamName;

  @override
  void initState() {
    super.initState();
    _loadInvitationDetails();
  }

  Future<void> _loadInvitationDetails() async {
    try {
      // Récupérer les détails de l'invitation
      final invitation = await _teamService.getInvitationByToken(widget.token);
      
      if (invitation.status != InvitationStatus.pending) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cette invitation n\'est plus valide.';
        });
        return;
      }
      
      if (invitation.isExpired) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cette invitation a expiré.';
        });
        return;
      }
      
      // Récupérer le nom de l'équipe
      final team = await _teamService.getTeam(invitation.teamId);
      
      setState(() {
        _teamName = team.name;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement de l\'invitation: $e';
      });
    }
  }

  Future<void> _acceptInvitation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Récupérer l'invitation
      final invitation = await _teamService.getInvitationByToken(widget.token);
      
      // Accepter l'invitation
      await _teamService.acceptInvitation(invitation.id);
      
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de l\'acceptation de l\'invitation: $e';
      });
    }
  }

  Future<void> _rejectInvitation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Récupérer l'invitation
      final invitation = await _teamService.getInvitationByToken(widget.token);
      
      // Rejeter l'invitation
      await _teamService.rejectInvitation(invitation.id);
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du rejet de l\'invitation: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitation d\'équipe'),
      ),
      body: _isLoading 
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Erreur',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Retour'),
                      ),
                    ],
                  ),
                ),
              )
            : _isSuccess
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Invitation acceptée',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vous avez rejoint l\'équipe $_teamName avec succès.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Continuer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group_add,
                            color: Theme.of(context).primaryColor,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Invitation à $_teamName',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Vous avez été invité à rejoindre l\'équipe $_teamName. Souhaitez-vous accepter cette invitation?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: _rejectInvitation,
                                child: Text('Refuser'),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _acceptInvitation,
                                child: Text('Accepter'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
    );
  }
}
