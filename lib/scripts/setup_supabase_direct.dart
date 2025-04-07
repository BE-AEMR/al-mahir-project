import 'package:supabase/supabase.dart';

// Script pour configurer Supabase directement via le client Supabase
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  // Initialiser le client Supabase avec la clé de service
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    print('Démarrage de la configuration de Supabase...');
    
    // 1. Créer la table des projets
    print('Création de la table "projects"...');
    final projectsTableResult = await client.rpc('execute_sql', params: {
      'sql': '''
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
      '''
    }).execute();
    
    if (projectsTableResult.error != null) {
      print('Erreur lors de la création de la table "projects": ${projectsTableResult.error!.message}');
    } else {
      print('Table "projects" créée avec succès');
    }
    
    // 2. Créer la table des tâches
    print('Création de la table "tasks"...');
    final tasksTableResult = await client.rpc('execute_sql', params: {
      'sql': '''
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
      '''
    }).execute();
    
    if (tasksTableResult.error != null) {
      print('Erreur lors de la création de la table "tasks": ${tasksTableResult.error!.message}');
    } else {
      print('Table "tasks" créée avec succès');
    }
    
    // 3. Activer RLS (Row Level Security)
    print('Activation de la sécurité par ligne (RLS)...');
    final rlsResult = await client.rpc('execute_sql', params: {
      'sql': '''
        -- Activer la sécurité par ligne (RLS)
        ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
        ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
      '''
    }).execute();
    
    if (rlsResult.error != null) {
      print('Erreur lors de l\'activation de RLS: ${rlsResult.error!.message}');
    } else {
      print('Sécurité par ligne (RLS) activée avec succès');
    }
    
    // 4. Créer les politiques pour les projets
    print('Création des politiques pour la table "projects"...');
    final projectsPoliciesResult = await client.rpc('execute_sql', params: {
      'sql': '''
        -- Politique pour les projets: un utilisateur peut voir ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can view their own projects" ON public.projects
          FOR SELECT USING (auth.uid() = created_by);

        -- Politique pour les projets: un utilisateur peut insérer ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can insert their own projects" ON public.projects
          FOR INSERT WITH CHECK (auth.uid() = created_by);

        -- Politique pour les projets: un utilisateur peut mettre à jour ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can update their own projects" ON public.projects
          FOR UPDATE USING (auth.uid() = created_by);

        -- Politique pour les projets: un utilisateur peut supprimer ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can delete their own projects" ON public.projects
          FOR DELETE USING (auth.uid() = created_by);
      '''
    }).execute();
    
    if (projectsPoliciesResult.error != null) {
      print('Erreur lors de la création des politiques pour "projects": ${projectsPoliciesResult.error!.message}');
    } else {
      print('Politiques pour la table "projects" créées avec succès');
    }
    
    // 5. Créer les politiques pour les tâches
    print('Création des politiques pour la table "tasks"...');
    final tasksPoliciesResult = await client.rpc('execute_sql', params: {
      'sql': '''
        -- Politique pour les tâches: un utilisateur peut voir les tâches des projets qu'il a créés
        CREATE POLICY IF NOT EXISTS "Users can view tasks of their projects" ON public.tasks
          FOR SELECT USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );

        -- Politique pour les tâches: un utilisateur peut insérer des tâches dans ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can insert tasks in their projects" ON public.tasks
          FOR INSERT WITH CHECK (
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );

        -- Politique pour les tâches: un utilisateur peut mettre à jour les tâches de ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can update tasks in their projects" ON public.tasks
          FOR UPDATE USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );

        -- Politique pour les tâches: un utilisateur peut supprimer les tâches de ses propres projets
        CREATE POLICY IF NOT EXISTS "Users can delete tasks in their projects" ON public.tasks
          FOR DELETE USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );
      '''
    }).execute();
    
    if (tasksPoliciesResult.error != null) {
      print('Erreur lors de la création des politiques pour "tasks": ${tasksPoliciesResult.error!.message}');
    } else {
      print('Politiques pour la table "tasks" créées avec succès');
    }
    
    // 6. Créer un utilisateur de test s'il n'existe pas déjà
    print('Création d\'un utilisateur de test...');
    try {
      // Vérifier si l'utilisateur existe déjà
      final checkUserResult = await client.auth.admin.listUsers();
      
      bool userExists = false;
      for (final user in checkUserResult) {
        if (user.email == 'test@example.com') {
          userExists = true;
          print('L\'utilisateur de test existe déjà');
          break;
        }
      }
      
      if (!userExists) {
        final userResponse = await client.auth.admin.createUser(
          AdminUserAttributes(
            email: 'test@example.com',
            password: 'password123',
            emailConfirm: true,
          ),
        );
        
        if (userResponse.user != null) {
          print('Utilisateur de test créé avec succès:');
          print('Email: test@example.com');
          print('Mot de passe: password123');
          print('ID utilisateur: ${userResponse.user!.id}');
          
          // Créer un projet de test pour l'utilisateur
          await _createTestProject(client, userResponse.user!.id);
        } else {
          print('Erreur lors de la création de l\'utilisateur: ${userResponse.error?.message}');
        }
      }
    } catch (e) {
      print('Erreur lors de la création de l\'utilisateur: $e');
    }
    
    print('Configuration de Supabase terminée avec succès!');
    
  } catch (e) {
    print('Erreur lors de la configuration de Supabase: $e');
  }
}

// Créer un projet de test
Future<void> _createTestProject(SupabaseClient client, String userId) async {
  try {
    print('Création d\'un projet de test...');
    
    // Créer un projet de test
    final response = await client.from('projects').insert({
      'name': 'Projet de test',
      'description': 'Un projet de test pour démontrer les fonctionnalités',
      'created_by': userId,
      'members': [],
      'status': 'active'
    }).select();
    
    if (response.error == null) {
      final projectId = response.data[0]['id'];
      print('Projet de test créé avec succès: $projectId');
      
      // Créer des tâches de test
      await _createTestTasks(client, projectId, userId);
    } else {
      print('Erreur lors de la création du projet: ${response.error!.message}');
    }
  } catch (e) {
    print('Erreur lors de la création du projet: $e');
  }
}

// Créer des tâches de test
Future<void> _createTestTasks(SupabaseClient client, String projectId, String userId) async {
  try {
    print('Création de tâches de test...');
    
    // Créer des tâches de test
    final response = await client.from('tasks').insert([
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
    
    if (response.error == null) {
      print('Tâches de test créées avec succès');
    } else {
      print('Erreur lors de la création des tâches: ${response.error!.message}');
    }
  } catch (e) {
    print('Erreur lors de la création des tâches: $e');
  }
}
