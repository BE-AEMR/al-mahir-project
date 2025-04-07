import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../../../models/project_model.dart';
import 'islamic_patterns.dart';

class ModernProjectSelector extends StatefulWidget {
  final List<Project> projects;
  final String? selectedProjectId;
  final bool showAllProjects;
  final Function(String?, bool) onProjectSelected;

  const ModernProjectSelector({
    Key? key,
    required this.projects,
    required this.selectedProjectId,
    required this.showAllProjects,
    required this.onProjectSelected,
  }) : super(key: key);

  @override
  State<ModernProjectSelector> createState() => _ModernProjectSelectorState();
}

class _ModernProjectSelectorState extends State<ModernProjectSelector> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    
    // Démarrer l'animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeWithAnimation() {
    _animationController.reverse().then((value) {
      Navigator.of(context).pop();
    });
  }

  String _getSelectedProjectName() {
    if (widget.showAllProjects) {
      return "Tous les projets";
    }
    
    if (widget.selectedProjectId == null) {
      return "";
    }
    
    final project = widget.projects.firstWhere(
      (p) => p.id == widget.selectedProjectId,
      orElse: () => Project(
        id: "",
        name: "Projet inconnu",
        description: "",
        status: "active",
        createdBy: "",
        createdAt: DateTime.now(),
      ),
    );
    
    return project.name;
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1F4E5F),
                Color(0xFF0D2B36),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Motif islamique en arrière-plan
              Positioned.fill(
                child: Opacity(
                  opacity: 0.09,
                  child: IslamicPatternBackground(
                    color: const Color.fromARGB(198, 255, 217, 0), // Couleur dorée
                  ),
                ),
              ),
              
              // Contenu du sélecteur
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Poignée
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  
                  // Titre
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Sélectionner un projet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Liste des projets
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // Option tous les projets
                        _buildProjectTile(
                          title: 'Tous les projets',
                          icon: Icons.people,
                          isSelected: widget.showAllProjects,
                          onTap: () {
                            widget.onProjectSelected(null, true);
                            _closeWithAnimation();
                          },
                        ),
                        
                        const Divider(
                          height: 1,
                          color: Colors.white24,
                          indent: 16,
                          endIndent: 16,
                        ),
                        
                        // Titre de section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_work,
                                color: Colors.amber[300],
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Mes projets',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Liste des projets
                        ...widget.projects.map((project) => _buildProjectTile(
                          title: project.name,
                          icon: Icons.group_work,
                          isSelected: widget.selectedProjectId == project.id && !widget.showAllProjects,
                          onTap: () {
                            widget.onProjectSelected(project.id, false);
                            _closeWithAnimation();
                          },
                        )).toList(),
                        
                        // Espace en bas pour éviter les problèmes d'affichage sur petits écrans
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProjectTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        leading: Icon(
          icon,
          color: isSelected ? Colors.amber[300] : Colors.white70,
        ),
        trailing: isSelected
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ProjectSelectorButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool showAllProjects;
  final String projectName;
  
  const ProjectSelectorButton({
    Key? key,
    required this.onPressed,
    required this.showAllProjects,
    required this.projectName,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final String displayText = showAllProjects 
        ? 'Tous les projets' 
        : 'Projet: $projectName';
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        // Utiliser une largeur adaptative au lieu d'une largeur fixe
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.45, // 45% de la largeur de l'écran
          minWidth: 120, // Largeur minimale
        ),
        height: 40,  
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1F4E5F),
              Color(0xFF0D2B36),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              showAllProjects ? Icons.people_alt : Icons.filter_list,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Vérifier si le texte est trop long pour l'espace disponible
                  final textSpan = TextSpan(
                    text: displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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
                      displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  } else {
                    // Optimisation 3: Isoler l'animation avec RepaintBoundary
                    return RepaintBoundary(
                      child: Marquee(
                        text: displayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
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
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}
