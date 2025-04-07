import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_subcategory_model.dart';

class TransactionSubcategoryService {
  final SupabaseClient _supabase;
  
  TransactionSubcategoryService(this._supabase);
  
  // Récupérer les sous-catégories par catégorie
  Future<List<TransactionSubcategory>> getSubcategoriesByCategory(String categoryId) async {
    final response = await _supabase
        .from('transaction_subcategories')
        .select()
        .eq('category_id', categoryId)
        .order('name');
    
    return (response as List)
        .map((data) => TransactionSubcategory.fromJson(data))
        .toList();
  }
  
  // Récupérer une sous-catégorie par son ID
  Future<TransactionSubcategory?> getSubcategoryById(String id) async {
    final response = await _supabase
        .from('transaction_subcategories')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    
    return TransactionSubcategory.fromJson(response);
  }
  
  // Ajouter une sous-catégorie
  Future<TransactionSubcategory> addSubcategory(
    String categoryId,
    String name,
    {String? description}
  ) async {
    final data = {
      'category_id': categoryId,
      'name': name,
      'description': description,
    };
    
    final response = await _supabase
        .from('transaction_subcategories')
        .insert(data)
        .select()
        .single();
    
    return TransactionSubcategory.fromJson(response);
  }
  
  // Mettre à jour une sous-catégorie
  Future<TransactionSubcategory> updateSubcategory(
    String id,
    {String? categoryId, String? name, String? description}
  ) async {
    final data = {
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };
    
    final response = await _supabase
        .from('transaction_subcategories')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    
    return TransactionSubcategory.fromJson(response);
  }
  
  // Supprimer une sous-catégorie
  Future<void> deleteSubcategory(String id) async {
    await _supabase
        .from('transaction_subcategories')
        .delete()
        .eq('id', id);
  }
  
  // Récupérer toutes les sous-catégories
  Future<List<TransactionSubcategory>> getAllSubcategories() async {
    final response = await _supabase
        .from('transaction_subcategories')
        .select()
        .order('name');
    
    return (response as List)
        .map((data) => TransactionSubcategory.fromJson(data))
        .toList();
  }
  
  // Ajouter plusieurs sous-catégories pour une catégorie
  Future<void> addMultipleSubcategories(
    String categoryId,
    List<String> names,
    {String? description}
  ) async {
    final List<Map<String, dynamic>> data = names.map((name) => {
      'category_id': categoryId,
      'name': name,
      'description': description,
    }).toList();
    
    await _supabase
        .from('transaction_subcategories')
        .insert(data);
  }
}
