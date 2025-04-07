import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Script pour créer un utilisateur de test directement via Supabase Flutter
void main() async {
  // Charger les variables d'environnement
  await dotenv.load();
  
  // Initialiser Supabase
  await Supabase.initialize(
    url: 'https://qxjxzbmihbapoeaebdvk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEwNzk4MzUsImV4cCI6MjA1NjY1NTgzNX0.x8fV1oOxZyUAvB2eono3TCthWdRpJFc3c2RQ7oU80zw',
  );
  
  try {
    print('Création d\'un utilisateur de test...');
    
    // Créer un utilisateur de test
    final response = await Supabase.instance.client.auth.signUp(
      email: 'test@example.com',
      password: 'password123',
    );
    
    if (response.user != null) {
      print('Utilisateur de test créé avec succès:');
      print('Email: test@example.com');
      print('Mot de passe: password123');
      print('ID utilisateur: ${response.user!.id}');
      
      // Se connecter avec l'utilisateur de test
      final loginResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      
      if (loginResponse.user != null) {
        print('Connexion réussie avec l\'utilisateur de test');
        
        // Créer un projet de test
        await _createTestProject(loginResponse.user!.id);
      }
    } else if (response.error != null) {
      if (response.error!.message.contains('already registered')) {
        print('L\'utilisateur de test existe déjà');
        
        // Se connecter avec l'utilisateur de test
        final loginResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        );
        
        if (loginResponse.user != null) {
          print('Connexion réussie avec l\'utilisateur de test');
          
          // Créer un projet de test
          await _createTestProject(loginResponse.user!.id);
        } else {
          print('Erreur lors de la connexion: ${loginResponse.error?.message}');
        }
      } else {
        print('Erreur lors de la création de l\'utilisateur: ${response.error!.message}');
      }
    }
  } catch (e) {
    print('Erreur: $e');
  } finally {
    // Fermer Supabase
    await Supabase.instance.client.dispose();
  }
}

// Créer un projet de test
Future<void> _createTestProject(String userId) async {
  try {
    print('Création d\'un projet de test...');
    
    // Créer un projet de test
    final response = await Supabase.instance.client.from('projects').insert({
      'name': 'Projet de test',
      'description': 'Un projet de test pour démontrer les fonctionnalités',
      'created_by': userId,
      'members': [],
      'status': 'active'
    }).select();
    
    if (response.isEmpty) {
      print('Erreur lors de la création du projet');
      return;
    }
    
    final projectId = response[0]['id'];
    print('Projet de test créé avec succès: $projectId');
    
    // Créer des tâches de test
    await _createTestTasks(projectId, userId);
  } catch (e) {
    print('Erreur lors de la création du projet: $e');
  }
}

// Créer des tâches de test
Future<void> _createTestTasks(String projectId, String userId) async {
  try {
    print('Création de tâches de test...');
    
    // Créer des tâches de test
    final response = await Supabase.instance.client.from('tasks').insert([
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
    ]);
    
    print('Tâches de test créées avec succès');
  } catch (e) {
    print('Erreur lors de la création des tâches: $e');
  }
}
