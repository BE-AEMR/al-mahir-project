import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../../../models/project_model.dart';
import '../../../screens/dashboard/widgets/islamic_patterns.dart';
import '../../../services/team_service/team_service.dart';
import '../../../providers/role_provider.dart';
import '../../../widgets/permission_gated.dart';

class ModernProjectCard extends StatelessWidget {
  final Project project;
  final int? teamCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ModernProjectCard({
    Key? key,
    required this.project,
    this.teamCount,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Déterminer la couleur du statut
    final ProjectStatus status = ProjectStatus.values.firstWhere(
      (s) => s.name == project.status,
      orElse: () => ProjectStatus.active,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getGradientForStatus(status),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: status.color.withOpacity(0.3),
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
                    // Titre du projet avec défilement si trop long
                    Row(
                      children: [
                        Icon(
                          _getIconForStatus(status),
                          color: Colors.white.withOpacity(0.9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Vérifier si le texte est trop long pour l'espace disponible
                              final textSpan = TextSpan(
                                text: project.name,
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
                                  project.name,
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
                                      text: project.name,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description du projet
                    Text(
                      project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Informations complémentaires
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Équipes: ${teamCount ?? "..."}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Créé le ${_formatDate(project.createdAt)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Boutons d'actions basés sur les permissions
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Bouton d'édition du projet (uniquement visible avec la permission)
                        PermissionGated(
                          permissionName: 'update_project',
                          projectId: project.id,
                          showLoadingIndicator: false,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: onEdit,
                            tooltip: 'Modifier',
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        
                        // Bouton de suppression du projet (uniquement visible avec la permission)
                        PermissionGated(
                          permissionName: 'delete_project',
                          projectId: project.id,
                          showLoadingIndicator: false,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: onDelete,
                            tooltip: 'Supprimer',
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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

  // Générer un dégradé de couleurs en fonction du statut du projet
  List<Color> _getGradientForStatus(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active:
        return [
          const Color(0xFF1F4E5F),
          const Color(0xFF0D2B36),
        ];
      case ProjectStatus.completed:
        return [
          const Color(0xFF388E3C),
          const Color(0xFF1B5E20),
        ];
      case ProjectStatus.onHold:
        return [
          const Color(0xFFFF9800),
          const Color(0xFFE65100),
        ];
      case ProjectStatus.cancelled:
        return [
          const Color(0xFFD32F2F),
          const Color(0xFF8B0000),
        ];
      default:
        return [
          const Color(0xFF1F4E5F),
          const Color(0xFF0D2B36),
        ];
    }
  }

  // Icône correspondant au statut du projet
  IconData _getIconForStatus(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active:
        return Icons.play_circle_outline;
      case ProjectStatus.completed:
        return Icons.check_circle_outline;
      case ProjectStatus.onHold:
        return Icons.pause_circle_outline;
      case ProjectStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.play_circle_outline;
    }
  }

  // Formater la date de création
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
