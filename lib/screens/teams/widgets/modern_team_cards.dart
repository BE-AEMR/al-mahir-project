import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../../../models/team_model.dart';
import '../../../widgets/islamic_patterns.dart';

class ModernTeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback onTap;

  const ModernTeamCard({
    Key? key,
    required this.team,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1F4E5F),
                Color(0xFF0D2B36),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Motif islamique en arrière-plan
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Opacity(
                    opacity: 0.06,
                    child: IslamicPatternBackground(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              // Contenu de la carte
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre de l'équipe avec défilement si trop long
                    Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Vérifier si le texte est trop long pour l'espace disponible
                              final textSpan = TextSpan(
                                text: team.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              );
                              final textPainter = TextPainter(
                                text: textSpan,
                                textDirection: TextDirection.ltr,
                              );
                              textPainter.layout(maxWidth: double.infinity);
                              
                              // Si le texte tient dans l'espace disponible, on l'affiche normalement
                              // Sinon, on utilise le widget Marquee pour le faire défiler
                              final textWidth = textPainter.width;
                              
                              if (textWidth <= constraints.maxWidth) {
                                return Text(
                                  team.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              } else {
                                return SizedBox(
                                  height: 25, // Hauteur fixe pour le défilement
                                  // Optimisation 3: Isoler l'animation avec RepaintBoundary
                                  child: RepaintBoundary(
                                    child: Marquee(
                                      text: team.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      scrollAxis: Axis.horizontal,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      blankSpace: 40.0,
                                      // Optimisation 1: Réduire la vitesse d'animation
                                      velocity: 20.0,
                                      // Optimisation 2: Augmenter la pause entre les cycles
                                      pauseAfterRound: const Duration(seconds: 60),
                                      startPadding: 10.0,
                                      accelerationDuration: const Duration(milliseconds: 500),
                                      accelerationCurve: Curves.linear,
                                      decelerationDuration: const Duration(milliseconds: 500),
                                      decelerationCurve: Curves.easeOut,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description de l'équipe
                    Expanded(
                      child: Text(
                        team.description ?? 'Aucune description',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    // Date de création
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Créée le ${_formatDate(team.createdAt)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Formater la date de création
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ModernInvitationCard extends StatelessWidget {
  final List<Invitation> invitations;
  final Function(Invitation, bool) onInvitationAction;

  const ModernInvitationCard({
    Key? key,
    required this.invitations,
    required this.onInvitationAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5C6BC0),
            Color(0xFF3949AB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif islamique en arrière-plan
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Opacity(
                opacity: 0.06,
                child: IslamicPatternBackground(
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre et badge
                Row(
                  children: [
                    const Icon(
                      Icons.mail,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Invitations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${invitations.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white30),
                // Liste des invitations
                ...invitations.map((invitation) => _buildInvitationItem(invitation, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationItem(Invitation invitation, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icône de l'équipe
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.groups,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Informations sur l'invitation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.teamName ?? 'Équipe inconnue',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invitation de : ${invitation.email}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Boutons d'action
          Row(
            children: [
              _buildActionButton(
                context,
                Icons.check,
                Colors.green,
                'Accepter',
                () => onInvitationAction(invitation, true),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                context,
                Icons.close,
                Colors.red,
                'Rejeter',
                () => onInvitationAction(invitation, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
