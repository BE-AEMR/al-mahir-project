import 'dart:convert';
import 'package:http/http.dart' as http;

// Script pour créer un projet de test pour l'utilisateur
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  // ID de l'utilisateur de test (utilisez l'ID généré lors de la création de l'utilisateur)
  final userId = '92a9c563-a9f2-4500-ada5-2a0cd23cbf1c';
  
  try {
    print('Utilisation de l\'ID utilisateur: $userId');
    
    // Créer un projet de test
    print('Création d\'un projet de test...');
    final projectResponse = await http.post(
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
    
    if (projectResponse.statusCode == 201) {
      final project = json.decode(projectResponse.body)[0];
      print('Projet de test créé avec succès:');
      print('ID: ${project['id']}');
      print('Nom: ${project['name']}');
      
      // Créer des tâches de test
      await _createTestTasks(supabaseUrl, supabaseKey, project['id'], userId);
    } else {
      print('Erreur lors de la création du projet: ${projectResponse.statusCode}');
      print('Réponse: ${projectResponse.body}');
    }
  } catch (e) {
    print('Erreur: $e');
  }
}

// Créer des tâches de test
Future<void> _createTestTasks(String supabaseUrl, String supabaseKey, String projectId, String userId) async {
  try {
    print('Création de tâches de test...');
    
    // Créer la première tâche
    final task1Response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'return=representation',
      },
      body: json.encode({
        'project_id': projectId,
        'title': 'Tâche 1',
        'description': 'Description de la tâche 1',
        'assigned_to': 'test2@example.com',
        'created_by': userId,
        'status': 'todo',
        'priority': 1
      }),
    );
    
    if (task1Response.statusCode == 201) {
      print('Tâche 1 créée avec succès');
    } else {
      print('Erreur lors de la création de la tâche 1: ${task1Response.statusCode}');
      print('Réponse: ${task1Response.body}');
    }
    
    // Créer la deuxième tâche
    final task2Response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/tasks'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'return=representation',
      },
      body: json.encode({
        'project_id': projectId,
        'title': 'Tâche 2',
        'description': 'Description de la tâche 2',
        'assigned_to': 'test2@example.com',
        'created_by': userId,
        'status': 'inProgress',
        'priority': 2
      }),
    );
    
    if (task2Response.statusCode == 201) {
      print('Tâche 2 créée avec succès');
    } else {
      print('Erreur lors de la création de la tâche 2: ${task2Response.statusCode}');
      print('Réponse: ${task2Response.body}');
    }
    
    print('Tâches de test créées avec succès');
  } catch (e) {
    print('Erreur lors de la création des tâches: $e');
  }
}
