import 'dart:convert';
import 'package:http/http.dart' as http;

// Script pour configurer Supabase directement via l'API REST
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  try {
    print('Démarrage de la configuration de Supabase...');
    
    // 1. Exécuter des requêtes SQL pour créer les tables et les politiques
    await _executeSql(supabaseUrl, supabaseKey, '''
      -- Activer l'extension uuid-ossp pour générer des UUID
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

      -- Table des projets
      CREATE TABLE IF NOT EXISTS public.projects (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ,
        created_by UUID REFERENCES auth.users(id),
        members TEXT[] DEFAULT '{}',
        status TEXT NOT NULL
      );
    ''');
    
    print('Table "projects" créée avec succès');
    
    await _executeSql(supabaseUrl, supabaseKey, '''
      -- Table des tâches
      CREATE TABLE IF NOT EXISTS public.tasks (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ,
        due_date TIMESTAMPTZ,
        assigned_to TEXT NOT NULL,
        created_by UUID REFERENCES auth.users(id),
        status TEXT NOT NULL,
        priority INTEGER NOT NULL
      );
    ''');
    
    print('Table "tasks" créée avec succès');
    
    // 2. Activer RLS (Row Level Security)
    await _executeSql(supabaseUrl, supabaseKey, '''
      -- Activer la sécurité par ligne (RLS)
      ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
      ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
    ''');
    
    print('Sécurité par ligne (RLS) activée');
    
    // 3. Créer les politiques pour les projets
    await _executeSql(supabaseUrl, supabaseKey, '''
      -- Politique pour les projets: un utilisateur peut voir ses propres projets
      CREATE POLICY "Users can view their own projects" ON public.projects
        FOR SELECT USING (auth.uid() = created_by);

      -- Politique pour les projets: un utilisateur peut insérer ses propres projets
      CREATE POLICY "Users can insert their own projects" ON public.projects
        FOR INSERT WITH CHECK (auth.uid() = created_by);

      -- Politique pour les projets: un utilisateur peut mettre à jour ses propres projets
      CREATE POLICY "Users can update their own projects" ON public.projects
        FOR UPDATE USING (auth.uid() = created_by);

      -- Politique pour les projets: un utilisateur peut supprimer ses propres projets
      CREATE POLICY "Users can delete their own projects" ON public.projects
        FOR DELETE USING (auth.uid() = created_by);
    ''');
    
    print('Politiques pour la table "projects" créées avec succès');
    
    // 4. Créer les politiques pour les tâches
    await _executeSql(supabaseUrl, supabaseKey, '''
      -- Politique pour les tâches: un utilisateur peut voir les tâches des projets qu'il a créés
      CREATE POLICY "Users can view tasks of their projects" ON public.tasks
        FOR SELECT USING (
          auth.uid() = created_by OR 
          auth.uid() IN (
            SELECT created_by FROM public.projects WHERE id = project_id
          )
        );

      -- Politique pour les tâches: un utilisateur peut insérer des tâches dans ses propres projets
      CREATE POLICY "Users can insert tasks in their projects" ON public.tasks
        FOR INSERT WITH CHECK (
          auth.uid() IN (
            SELECT created_by FROM public.projects WHERE id = project_id
          )
        );

      -- Politique pour les tâches: un utilisateur peut mettre à jour les tâches de ses propres projets
      CREATE POLICY "Users can update tasks in their projects" ON public.tasks
        FOR UPDATE USING (
          auth.uid() = created_by OR 
          auth.uid() IN (
            SELECT created_by FROM public.projects WHERE id = project_id
          )
        );

      -- Politique pour les tâches: un utilisateur peut supprimer les tâches de ses propres projets
      CREATE POLICY "Users can delete tasks in their projects" ON public.tasks
        FOR DELETE USING (
          auth.uid() = created_by OR 
          auth.uid() IN (
            SELECT created_by FROM public.projects WHERE id = project_id
          )
        );
    ''');
    
    print('Politiques pour la table "tasks" créées avec succès');
    
    // 5. Créer un utilisateur de test s'il n'existe pas déjà
    await _createTestUser(supabaseUrl, supabaseKey);
    
    print('Configuration de Supabase terminée avec succès!');
    
  } catch (e) {
    print('Erreur lors de la configuration de Supabase: $e');
  }
}

// Exécuter une requête SQL via l'API REST
Future<void> _executeSql(String supabaseUrl, String supabaseKey, String sql) async {
  try {
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/rpc/execute_sql'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
      body: json.encode({
        'sql': sql,
      }),
    );
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      print('Erreur lors de l\'exécution SQL: ${response.statusCode}');
      print('Réponse: ${response.body}');
      throw Exception('Erreur lors de l\'exécution SQL: ${response.statusCode}');
    }
  } catch (e) {
    print('Erreur lors de l\'exécution SQL: $e');
    throw e;
  }
}

// Créer un utilisateur de test
Future<void> _createTestUser(String supabaseUrl, String supabaseKey) async {
  try {
    print('Vérification de l\'existence de l\'utilisateur de test...');
    
    // Vérifier si l'utilisateur existe déjà
    final checkResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/rpc/check_user_exists'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
      body: json.encode({
        'email': 'test@example.com',
      }),
    );
    
    if (checkResponse.statusCode == 200) {
      final userExists = json.decode(checkResponse.body);
      if (userExists) {
        print('L\'utilisateur de test existe déjà');
        return;
      }
    }
    
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
    } else if (response.statusCode == 422) {
      print('L\'utilisateur de test existe déjà');
    } else {
      print('Erreur lors de la création de l\'utilisateur: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
  } catch (e) {
    print('Erreur lors de la création de l\'utilisateur: $e');
  }
}

// Créer un projet de test
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

// Créer des tâches de test
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
