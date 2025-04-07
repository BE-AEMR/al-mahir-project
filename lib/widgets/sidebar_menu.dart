import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../providers/role_provider.dart';
import '../widgets/permission_gated.dart';
import '../screens/projects/projects_screen.dart';
import '../screens/auth/profile_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/teams/teams_screen.dart';
import '../screens/admin/roles_admin_screen.dart';
import 'islamic_patterns.dart';

class SidebarMenu extends StatefulWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool isDrawer;

  const SidebarMenu({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.isDrawer = false,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Si c'est un drawer, on l'affiche toujours en mode étendu
    if (widget.isDrawer) {
      _isExpanded = true;
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isAuthenticated = user != null;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isDrawer ? double.infinity : (_isExpanded ? 250 : 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1F4E5F),
            const Color(0xFF0D2B36),
          ],
        ),
        boxShadow: widget.isDrawer ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
          
          // Contenu du menu
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16), // Espace supplémentaire en haut
                // En-tête du menu
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isAuthenticated ? Icons.person : Icons.person_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      if (_isExpanded || widget.isDrawer) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAuthenticated ? (user.email ?? 'Utilisateur') : 'Invité',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAuthenticated ? 'Connecté' : 'Non connecté',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              if (isAuthenticated) ...[
                                const SizedBox(height: 4),
                                FutureBuilder<List<String>>(
                                  future: Provider.of<RoleProvider>(context, listen: false).getUserRoles(),
                                  builder: (context, snapshot) {
                                    final roles = snapshot.data ?? ['Chargement...'];
                                    return Text(
                                      'Rôle: ${roles.join(", ")}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const Divider(
                  color: Colors.white24,
                  height: 1,
                  thickness: 1,
                ),
                
                // Éléments du menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildMenuItem(
                        icon: Icons.dashboard,
                        title: 'Tableau de bord',
                        index: 0,
                      ),
                      _buildMenuItem(
                        icon: Icons.folder,
                        title: 'Projets',
                        index: 1,
                      ),
                      _buildMenuItem(
                        icon: Icons.group,
                        title: 'Équipes',
                        index: 2,
                      ),
                      _buildMenuItem(
                        icon: Icons.calendar_today,
                        title: 'Calendrier',
                        index: 3,
                      ),
                      _buildMenuItem(
                        icon: Icons.analytics,
                        title: 'Statistiques',
                        index: 4,
                      ),
                      _buildMenuItem(
                        icon: Icons.attach_money,
                        title: 'Finances',
                        index: 5,
                      ),
                      
                      const Divider(
                        color: Colors.white24,
                        height: 16,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      
                      // Administration des rôles (afficher seulement pour les administrateurs)
                      FutureBuilder<bool>(
                        future: () async {
                          print('Vérification des permissions pour Admin des Rôles');
                          
                          // Récupérer les informations complètes de user_roles pour debug
                          final roleProvider = Provider.of<RoleProvider>(context, listen: false);
                          final userRolesDetails = await roleProvider.getUserRolesDetails();
                          print('DEBUG sidebar: Détails des rôles utilisateur: $userRolesDetails');
                          
                          // Extraire le team_id du rôle system_admin s'il existe
                          String? teamId;
                          for (var role in userRolesDetails) {
                            if (role['role_name'] == 'system_admin') {
                              teamId = role['team_id'];
                              break;
                            }
                          }
                          
                          print('DEBUG sidebar: Utilisation du team_id: $teamId pour la vérification');
                          final result = await roleProvider.hasPermission('manage_roles', teamId: teamId);
                          print('User has manage_roles permission: $result');
                          return result;
                        }(),
                        builder: (context, snapshot) {
                          final bool hasPermission = snapshot.data ?? false;
                          if (!hasPermission) {
                            return const SizedBox.shrink();
                          }
                          
                          return _buildMenuItem(
                            icon: Icons.admin_panel_settings,
                            title: 'Admin des Rôles',
                            index: 10,
                            isAdmin: true,
                          );
                        },
                      ),
                      const Divider(
                        color: Colors.white24,
                        height: 32,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: 'Paramètres',
                        index: 6,
                      ),
                    ],
                  ),
                ),
                
                // Pied du menu
                Container(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () {
                      if (isAuthenticated) {
                        _authService.signOut();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isAuthenticated ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAuthenticated ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAuthenticated ? Icons.logout : Icons.login,
                            color: isAuthenticated ? Colors.red.shade300 : Colors.green.shade300,
                            size: 20,
                          ),
                          if (_isExpanded || widget.isDrawer) ...[
                            const SizedBox(width: 12),
                            Text(
                              isAuthenticated ? 'Déconnexion' : 'Connexion',
                              style: TextStyle(
                                color: isAuthenticated ? Colors.red.shade300 : Colors.green.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bouton pour réduire/agrandir le menu (seulement si ce n'est pas un drawer)
                if (!widget.isDrawer)
                  Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      onPressed: _toggleExpanded,
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _animation,
                        color: Colors.white70,
                      ),
                      tooltip: _isExpanded ? 'Réduire le menu' : 'Agrandir le menu',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
    bool isAdmin = false,
  }) {
    final isSelected = widget.selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          if (isAdmin) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RolesAdminScreen()),
            );
          } else {
            widget.onItemSelected(index);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 24,
              ),
              if (_isExpanded || widget.isDrawer) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
