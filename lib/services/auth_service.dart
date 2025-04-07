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
      final response = await _client.auth.signUp(
        email: email,
        password: password,
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
      await _client.auth.resetPasswordForEmail(email);
      print('Email de réinitialisation envoyé avec succès');
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email de réinitialisation: $e');
      rethrow;
    }
  }
}
