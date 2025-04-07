import 'package:supabase/supabase.dart';

// Script pour initialiser la base de données Supabase
// Ce script doit être exécuté une seule fois pour configurer la base de données
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  // Initialiser le client Supabase avec la clé de service
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    print('Démarrage de la configuration de la base de données...');
    
    // 1. Créer la table des projets
    print('Création de la table "projects"...');
    await client.rpc('create_table_if_not_exists', params: {
      'table_name': 'projects',
      'columns': '''
        id uuid primary key default uuid_generate_v4(),
        name text not null,
        description text not null,
        created_at timestamp with time zone default now(),
        updated_at timestamp with time zone,
        created_by uuid references auth.users(id),
        members text[] default '{}',
        status text not null
      '''
    });
    
    // 2. Créer la table des tâches
    print('Création de la table "tasks"...');
    await client.rpc('create_table_if_not_exists', params: {
      'table_name': 'tasks',
      'columns': '''
        id uuid primary key default uuid_generate_v4(),
        project_id uuid references projects(id) on delete cascade,
        title text not null,
        description text,
        created_at timestamp with time zone default now(),
        updated_at timestamp with time zone,
        due_date timestamp with time zone,
        assigned_to text not null,
        created_by uuid references auth.users(id),
        status text not null,
        priority integer not null
      '''
    });
    
    // 3. Créer un utilisateur de test
    print('Création d\'un utilisateur de test...');
    final userResponse = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: 'test@example.com',
        password: 'password123',
        emailConfirm: true,
      ),
    );
    
    if (userResponse.user != null) {
      print('Utilisateur de test créé avec succès: ${userResponse.user!.email}');
      
      // 4. Créer un projet de test pour l'utilisateur
      print('Création d\'un projet de test...');
      final projectResponse = await client.from('projects').insert({
        'name': 'Projet de test',
        'description': 'Un projet de test pour démontrer les fonctionnalités',
        'created_by': userResponse.user!.id,
        'members': [],
        'status': 'active'
      }).select();
      
      if (projectResponse.isNotEmpty) {
        final projectId = projectResponse[0]['id'];
        print('Projet de test créé avec succès: $projectId');
        
        // 5. Créer quelques tâches de test
        print('Création de tâches de test...');
        await client.from('tasks').insert([
          {
            'project_id': projectId,
            'title': 'Tâche 1',
            'description': 'Description de la tâche 1',
            'assigned_to': userResponse.user!.email,
            'created_by': userResponse.user!.id,
            'status': 'todo',
            'priority': 1
          },
          {
            'project_id': projectId,
            'title': 'Tâche 2',
            'description': 'Description de la tâche 2',
            'assigned_to': userResponse.user!.email,
            'created_by': userResponse.user!.id,
            'status': 'inProgress',
            'priority': 2
          }
        ]);
        
        print('Tâches de test créées avec succès');
      }
    }
    
    print('Configuration de la base de données terminée avec succès!');
    print('Vous pouvez maintenant vous connecter avec:');
    print('Email: test@example.com');
    print('Mot de passe: password123');
    
  } catch (e) {
    print('Erreur lors de la configuration de la base de données: $e');
  }
}
