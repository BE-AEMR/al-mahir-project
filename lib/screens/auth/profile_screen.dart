import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/islamic_patterns.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  String? _displayName;
  String? _phoneNumber;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }
  
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
          
        if (profile != null) {
          setState(() {
            _displayName = profile['display_name'];
            _phoneNumber = profile['phone_number'];
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Utilisateur non connecté'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
        child: Column(
          children: [
            // Suppression du header décoratif bleu
            
            const SizedBox(height: 24),
            
            // Avatar et informations de base
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1F4E5F).withOpacity(0.1),
                      border: Border.all(
                        color: const Color(0xFF1F4E5F),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF1F4E5F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName ?? user.email ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${user.id.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Informations du profil
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations du compte',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E5F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.badge,
                    title: 'Nom d\'affichage',
                    value: _displayName ?? 'Non défini',
                  ),
                  _buildInfoCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: user.email ?? 'Non défini',
                  ),
                  _buildInfoCard(
                    icon: Icons.phone,
                    title: 'Téléphone',
                    value: _phoneNumber ?? 'Non défini',
                  ),
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Date d\'inscription',
                    value: user.createdAt != null
                        ? _formatDate(DateTime.parse(user.createdAt!))
                        : 'Non défini',
                  ),
                  _buildInfoCard(
                    icon: Icons.update,
                    title: 'Dernière connexion',
                    value: user.lastSignInAt != null
                        ? _formatDate(DateTime.parse(user.lastSignInAt!))
                        : 'Non défini',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Boutons d'action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E5F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4, // Largeur fixe pour le bouton
                        child: IslamicDecorativeButton(
                          text: 'Modifier le profil',
                          icon: Icons.edit,
                          onPressed: () async {
                            // Naviguer vers l'écran d'édition du profil
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            );
                            
                            // Si le profil a été modifié, recharger les données
                            if (result == true) {
                              _loadProfileData();
                            }
                          },
                          color: const Color(0xFF1F4E5F),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4, // Largeur fixe pour le bouton
                        child: IslamicDecorativeButton(
                          text: 'Déconnexion',
                          icon: Icons.logout,
                          onPressed: () async {
                            await _authService.signOut();
                            // Au lieu de simplement fermer l'écran, naviguer vers l'écran de login
                            if (!mounted) return;
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false, // Supprimer toutes les routes précédentes
                            );
                          },
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1F4E5F).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1F4E5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1F4E5F),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
