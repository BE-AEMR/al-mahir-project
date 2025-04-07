import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'logo_widget.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    
    return Drawer(
      child: Column(
        children: [
          // En-tête du drawer avec logo et informations utilisateur
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1F4E5F),
            ),
            child: Column(
              children: [
                // Logo doré
                const LogoWidget(
                  isGold: true,
                  size: 70,
                  animationType: LogoAnimationType.fade,
                  animationDuration: Duration(milliseconds: 800),
                ),
                
                const SizedBox(height: 16),
                
                // Information utilisateur
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 24.0,
                      color: Color(0xFF1F4E5F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Utilisateur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                
                Text(
                  user?.email ?? 'Non connecté',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard,
                  title: 'Tableau de bord',
                  route: '/',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.folder,
                  title: 'Projets',
                  route: '/projects',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.task_alt,
                  title: 'Tâches',
                  route: '/tasks',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.timeline,
                  title: 'Phases',
                  route: '/phases',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.attach_money,
                  title: 'Budget',
                  route: '/budget',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long,
                  title: 'Transactions',
                  route: '/transactions',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.category,
                  title: 'Catégories',
                  route: '/transaction-categories',
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Paramètres',
                  route: '/settings',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                await authService.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E5F),
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    final bool isSelected = ModalRoute.of(context)?.settings.name == route;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF1F4E5F) : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF1F4E5F) : Colors.grey[800],
        ),
      ),
      tileColor: isSelected ? const Color(0xFF1F4E5F).withOpacity(0.1) : null,
      onTap: () {
        Navigator.pop(context); // Fermer le drawer
        if (ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}
