import 'package:http/http.dart' as http;
import 'dart:convert';

// Script pour créer la fonction execute_sql dans Supabase
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  try {
    print('Création de la fonction execute_sql dans Supabase...');
    
    // SQL pour créer la fonction execute_sql
    final sql = '''
    CREATE OR REPLACE FUNCTION public.execute_sql(sql text)
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS \$\$
    BEGIN
      EXECUTE sql;
    END;
    \$\$;
    ''';
    
    // Exécuter le SQL directement via l'API REST
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
    
    if (response.statusCode == 200) {
      print('Fonction execute_sql créée avec succès');
    } else {
      print('Erreur lors de la création de la fonction execute_sql: ${response.statusCode}');
      print('Réponse: ${response.body}');
      
      // Si la fonction n'existe pas encore, essayons de créer les tables directement
      print('Tentative de création des tables directement...');
      await _createTablesDirectly(supabaseUrl, supabaseKey);
    }
  } catch (e) {
    print('Erreur: $e');
    print('Tentative de création des tables directement...');
    await _createTablesDirectly(supabaseUrl, supabaseKey);
  }
}

// Créer les tables directement via l'API REST
Future<void> _createTablesDirectly(String supabaseUrl, String supabaseKey) async {
  try {
    // 1. Créer la table des projets
    print('Création de la table "projects"...');
    final projectsResponse = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: json.encode({
        'command': '''
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
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
      }),
    );
    
    if (projectsResponse.statusCode == 200 || projectsResponse.statusCode == 201) {
      print('Table "projects" créée avec succès');
    } else {
      print('Erreur lors de la création de la table "projects": ${projectsResponse.statusCode}');
      print('Réponse: ${projectsResponse.body}');
    }
    
    // 2. Créer la table des tâches
    print('Création de la table "tasks"...');
    final tasksResponse = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: json.encode({
        'command': '''
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
      }),
    );
    
    if (tasksResponse.statusCode == 200 || tasksResponse.statusCode == 201) {
      print('Table "tasks" créée avec succès');
    } else {
      print('Erreur lors de la création de la table "tasks": ${tasksResponse.statusCode}');
      print('Réponse: ${tasksResponse.body}');
    }
    
    // 3. Activer RLS (Row Level Security)
    print('Activation de la sécurité par ligne (RLS)...');
    final rlsResponse = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: json.encode({
        'command': '''
        ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
        ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
        '''
      }),
    );
    
    if (rlsResponse.statusCode == 200 || rlsResponse.statusCode == 201) {
      print('Sécurité par ligne (RLS) activée avec succès');
    } else {
      print('Erreur lors de l\'activation de RLS: ${rlsResponse.statusCode}');
      print('Réponse: ${rlsResponse.body}');
    }
    
    // 4. Créer les politiques pour les projets
    print('Création des politiques pour la table "projects"...');
    final projectsPoliciesResponse = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: json.encode({
        'command': '''
        CREATE POLICY IF NOT EXISTS "Users can view their own projects" ON public.projects
          FOR SELECT USING (auth.uid() = created_by);
        CREATE POLICY IF NOT EXISTS "Users can insert their own projects" ON public.projects
          FOR INSERT WITH CHECK (auth.uid() = created_by);
        CREATE POLICY IF NOT EXISTS "Users can update their own projects" ON public.projects
          FOR UPDATE USING (auth.uid() = created_by);
        CREATE POLICY IF NOT EXISTS "Users can delete their own projects" ON public.projects
          FOR DELETE USING (auth.uid() = created_by);
        '''
      }),
    );
    
    if (projectsPoliciesResponse.statusCode == 200 || projectsPoliciesResponse.statusCode == 201) {
      print('Politiques pour la table "projects" créées avec succès');
    } else {
      print('Erreur lors de la création des politiques pour "projects": ${projectsPoliciesResponse.statusCode}');
      print('Réponse: ${projectsPoliciesResponse.body}');
    }
    
    // 5. Créer les politiques pour les tâches
    print('Création des politiques pour la table "tasks"...');
    final tasksPoliciesResponse = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: json.encode({
        'command': '''
        CREATE POLICY IF NOT EXISTS "Users can view tasks of their projects" ON public.tasks
          FOR SELECT USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );
        CREATE POLICY IF NOT EXISTS "Users can insert tasks in their projects" ON public.tasks
          FOR INSERT WITH CHECK (
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );
        CREATE POLICY IF NOT EXISTS "Users can update tasks in their projects" ON public.tasks
          FOR UPDATE USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );
        CREATE POLICY IF NOT EXISTS "Users can delete tasks in their projects" ON public.tasks
          FOR DELETE USING (
            auth.uid() = created_by OR 
            auth.uid() IN (
              SELECT created_by FROM public.projects WHERE id = project_id
            )
          );
        '''
      }),
    );
    
    if (tasksPoliciesResponse.statusCode == 200 || tasksPoliciesResponse.statusCode == 201) {
      print('Politiques pour la table "tasks" créées avec succès');
    } else {
      print('Erreur lors de la création des politiques pour "tasks": ${tasksPoliciesResponse.statusCode}');
      print('Réponse: ${tasksPoliciesResponse.body}');
    }
    
    print('Configuration de Supabase terminée avec succès!');
    
  } catch (e) {
    print('Erreur lors de la configuration de Supabase: $e');
  }
}
