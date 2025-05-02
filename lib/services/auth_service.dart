import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _client.auth.currentUser;

  // Vérifier si l'utilisateur est connecté
  bool get isAuthenticated => currentUser != null;

  // Obtenir l'utilisateur actuel (méthode Future pour compatibilité)
  Future<User?> getCurrentUser() async {
    return currentUser;
  }

  // Obtenir l'ID de l'utilisateur actuel
  Future<String?> getCurrentUserId() async {
    return currentUser?.id;
  }

  // Obtenir l'ID de l'utilisateur actuel de manière synchrone
  String? getCurrentUserIdSync() {
    return currentUser?.id;
  }

  // Connexion avec email et mot de passe
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('Tentative de connexion avec email: $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('Connexion réussie: ${response.user?.email}');
      return response;
    } catch (e) {
      print('Erreur de connexion: $e');
      rethrow;
    }
  }

  // Inscription avec email et mot de passe
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('Tentative d\'inscription avec email: $email');
      
      // Utiliser l'URL GitHub Pages pour la redirection (dans le dossier docs)
      final redirectUrl = 'https://be-aemr.github.io/al-mahir-project/auth/callback';
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl, // URL de redirection vers GitHub Pages
      );

      // Ajouter le displayName au profil utilisateur
      if (response.user != null) {
        await _client.from('profiles').update({
          'display_name': displayName,
        }).eq('id', response.user!.id);
        print('Profil utilisateur mis à jour avec le nom d\'affichage: $displayName');
      }

      print('Inscription réussie: ${response.user?.email}');
      return response;
    } catch (e) {
      print('Erreur d\'inscription: $e');
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      print('Tentative de déconnexion');
      await _client.auth.signOut();
      print('Déconnexion réussie');
    } catch (e) {
      print('Erreur de déconnexion: $e');
      rethrow;
    }
  }

  // Réinitialisation de mot de passe
  Future<void> resetPassword({required String email}) async {
    try {
      print('Tentative d\'envoi de réinitialisation de mot de passe pour: $email');
      
      // Utiliser l'URL GitHub Pages pour la redirection (dans le dossier docs)
      final redirectUrl = 'https://be-aemr.github.io/al-mahir-project/auth/reset-password';
      
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl, // URL de redirection vers GitHub Pages
      );
      print('Email de réinitialisation envoyé avec succès');
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email de réinitialisation: $e');
      rethrow;
    }
  }

  // Suppression de compte utilisateur
  Future<void> deleteAccount() async {
    try {
      print('Tentative de suppression du compte utilisateur');
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }
      
      // Supprimer les données de l'utilisateur dans les tables personnalisées
      await _client.from('profiles').delete().eq('id', user.id);
      
      // Supprimer le compte utilisateur de Supabase
      await _client.auth.admin.deleteUser(user.id);
      
      print('Compte utilisateur supprimé avec succès');
      
      // Déconnexion après suppression
      await signOut();
    } catch (e) {
      print('Erreur lors de la suppression du compte: $e');
      rethrow;
    }
  }
}
