import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Script pour exécuter le fichier SQL de configuration
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  try {
    // Lire le fichier SQL
    final sqlFile = File('supabase/setup_complete.sql');
    final sqlContent = await sqlFile.readAsString();
    
    print('Exécution du script SQL...');
    
    // Diviser le script en commandes individuelles
    final commands = sqlContent.split(';').where((cmd) => cmd.trim().isNotEmpty).toList();
    
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i].trim();
      print('Exécution de la commande ${i + 1}/${commands.length}...');
      
      // Exécuter la commande SQL
      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/rpc/execute_sql'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
        },
        body: json.encode({
          'sql': command,
        }),
      );
      
      if (response.statusCode == 200) {
        print('Commande exécutée avec succès');
      } else {
        print('Erreur lors de l\'exécution de la commande: ${response.statusCode}');
        print('Réponse: ${response.body}');
        
        // Essayer d'exécuter la commande directement via l'API SQL
        final sqlResponse = await http.post(
          Uri.parse('$supabaseUrl/rest/v1/'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: json.encode({
            'command': command,
          }),
        );
        
        if (sqlResponse.statusCode == 200 || sqlResponse.statusCode == 201) {
          print('Commande exécutée avec succès via l\'API SQL');
        } else {
          print('Erreur lors de l\'exécution de la commande via l\'API SQL: ${sqlResponse.statusCode}');
          print('Réponse: ${sqlResponse.body}');
        }
      }
    }
    
    print('Script SQL exécuté avec succès!');
    
    // Vérifier si les tables ont été créées
    await _checkTables(supabaseUrl, supabaseKey);
    
  } catch (e) {
    print('Erreur: $e');
  }
}

// Vérifier si les tables ont été créées
Future<void> _checkTables(String supabaseUrl, String supabaseKey) async {
  try {
    print('\nVérification des tables...');
    
    // Vérifier la table projects
    final projectsResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/projects?select=id,name&limit=1'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );
    
    if (projectsResponse.statusCode == 200) {
      print('Table "projects" existe');
    } else {
      print('Erreur lors de la vérification de la table "projects": ${projectsResponse.statusCode}');
      print('Réponse: ${projectsResponse.body}');
    }
    
    // Vérifier la table tasks
    final tasksResponse = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/tasks?select=id,title&limit=1'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
    );
    
    if (tasksResponse.statusCode == 200) {
      print('Table "tasks" existe');
    } else {
      print('Erreur lors de la vérification de la table "tasks": ${tasksResponse.statusCode}');
      print('Réponse: ${tasksResponse.body}');
    }
    
  } catch (e) {
    print('Erreur lors de la vérification des tables: $e');
  }
}
