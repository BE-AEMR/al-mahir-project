import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Secret pour l'authentification des fonctions Edge
  static const String functionSecret = 'WebXIO_2025_SecretKey_For_Functions';
}
