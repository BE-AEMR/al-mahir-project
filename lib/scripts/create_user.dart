import 'dart:convert';
import 'package:http/http.dart' as http;

// Script simple pour créer un utilisateur de test
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  try {
    print('Création d\'un utilisateur de test...');
    
    // Créer un utilisateur de test
    final response = await http.post(
      Uri.parse('$supabaseUrl/auth/v1/admin/users'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
      body: json.encode({
        'email': 'test2@example.com',
        'password': 'password123',
        'email_confirm': true,
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final userData = json.decode(response.body);
      print('Utilisateur de test créé avec succès:');
      print('Email: test2@example.com');
      print('Mot de passe: password123');
      print('ID utilisateur: ${userData['id']}');
    } else {
      print('Erreur lors de la création de l\'utilisateur: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
  } catch (e) {
    print('Erreur: $e');
  }
}
