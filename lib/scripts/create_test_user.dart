import 'dart:convert';
import 'package:http/http.dart' as http;

// Script pour créer un utilisateur de test dans Supabase
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
        'email': 'test@example.com',
        'password': 'password123',
        'email_confirm': true,
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final userData = json.decode(response.body);
      print('Utilisateur de test créé avec succès:');
      print('Email: test@example.com');
      print('Mot de passe: password123');
      print('ID utilisateur: ${userData['id']}');
      
      // Créer un projet de test pour l'utilisateur
      await _createTestProject(supabaseUrl, supabaseKey, userData['id']);
    } else {
      print('Erreur lors de la création de l\'utilisateur: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
  } catch (e) {
    print('Erreur lors de la création de l\'utilisateur: $e');
  }
}

Future<void> _createTestProject(String supabaseUrl, String supabaseKey, String userId) async {
  try {
    print('Création d\'un projet de test...');
    
    // Créer un projet de test
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/projects'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'return=representation',
      },
      body: json.encode({
        'name': 'Projet de test',
        'description': 'Un projet de test pour démontrer les fonctionnalités',
        'created_by': userId,
        'members': [],
        'status': 'active'
      }),
    );
    
    if (response.statusCode == 201) {
      final projectData = json.decode(response.body)[0];
      print('Projet de test créé avec succès: ${projectData['id']}');
      
      // Créer des tâches de test
      await _createTestTasks(supabaseUrl, supabaseKey, projectData['id'], userId);
    } else {
      print('Erreur lors de la création du projet: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
  } catch (e) {
    print('Erreur lors de la création du projet: $e');
  }
}

Future<void> _createTestTasks(String supabaseUrl, String supabaseKey, String projectId, String userId) async {
  try {
    print('Création de tâches de test...');
    
    // Créer des tâches de test
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
      body: json.encode([
        {
          'project_id': projectId,
          'title': 'Tâche 1',
          'description': 'Description de la tâche 1',
          'assigned_to': 'test@example.com',
          'created_by': userId,
          'status': 'todo',
          'priority': 1
        },
        {
          'project_id': projectId,
          'title': 'Tâche 2',
          'description': 'Description de la tâche 2',
          'assigned_to': 'test@example.com',
          'created_by': userId,
          'status': 'inProgress',
          'priority': 2
        }
      ]),
    );
    
    if (response.statusCode == 201) {
      print('Tâches de test créées avec succès');
    } else {
      print('Erreur lors de la création des tâches: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
  } catch (e) {
    print('Erreur lors de la création des tâches: $e');
  }
}
