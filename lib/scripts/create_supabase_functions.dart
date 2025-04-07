import 'dart:convert';
import 'package:http/http.dart' as http;

// Script pour créer des fonctions RPC dans Supabase
void main() async {
  // Configuration Supabase
  final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTA3OTgzNSwiZXhwIjoyMDU2NjU1ODM1fQ.47SCRFjFXbKjNuDso-3onVbh1mNgzyJFg1xwzq2JZdw';
  
  try {
    print('Création des fonctions RPC dans Supabase...');
    
    // Créer la fonction execute_sql
    final executeSqlFunction = '''
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
    
    // Créer la fonction check_user_exists
    final checkUserExistsFunction = '''
    CREATE OR REPLACE FUNCTION public.check_user_exists(email text)
    RETURNS boolean
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS \$\$
    DECLARE
      user_exists boolean;
    BEGIN
      SELECT EXISTS (
        SELECT 1 FROM auth.users WHERE email = check_user_exists.email
      ) INTO user_exists;
      
      RETURN user_exists;
    END;
    \$\$;
    ''';
    
    // Exécuter les requêtes SQL pour créer les fonctions
    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/sql'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
      },
      body: json.encode({
        'query': executeSqlFunction + checkUserExistsFunction,
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Fonctions RPC créées avec succès');
    } else {
      print('Erreur lors de la création des fonctions RPC: ${response.statusCode}');
      print('Réponse: ${response.body}');
    }
    
  } catch (e) {
    print('Erreur lors de la création des fonctions RPC: $e');
  }
}
