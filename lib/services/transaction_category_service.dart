import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_category_model.dart';

class TransactionCategoryService {
  final SupabaseClient _supabase;
  
  TransactionCategoryService(this._supabase);
  
  // Récupérer toutes les catégories par type de transaction
  Future<List<TransactionCategory>> getCategoriesByType(String transactionType) async {
    final response = await _supabase
        .from('transaction_categories')
        .select()
        .eq('transaction_type', transactionType)
        .order('name');
    
    return (response as List)
        .map((data) => TransactionCategory.fromJson(data))
        .toList();
  }
  
  // Récupérer toutes les catégories
  Future<List<TransactionCategory>> getAllCategories() async {
    final response = await _supabase
        .from('transaction_categories')
        .select()
        .order('name');
    
    return (response as List)
        .map((data) => TransactionCategory.fromJson(data))
        .toList();
  }
  
  // Récupérer une catégorie par son ID
  Future<TransactionCategory?> getCategoryById(String id) async {
    final response = await _supabase
        .from('transaction_categories')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    
    return TransactionCategory.fromJson(response);
  }
  
  // Ajouter une catégorie
  Future<TransactionCategory> addCategory(
    String name, 
    String transactionType,
    {String? description, String? icon, String? color}
  ) async {
    final data = {
      'name': name,
      'transaction_type': transactionType,
      'description': description,
      'icon': icon,
      'color': color,
    };
    
    final response = await _supabase
        .from('transaction_categories')
        .insert(data)
        .select()
        .single();
    
    return TransactionCategory.fromJson(response);
  }
  
  // Mettre à jour une catégorie
  Future<TransactionCategory> updateCategory(
    String id,
    {String? name, String? transactionType, String? description, String? icon, String? color}
  ) async {
    final data = {
      if (name != null) 'name': name,
      if (transactionType != null) 'transaction_type': transactionType,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    };
    
    final response = await _supabase
        .from('transaction_categories')
        .update(data)
        .eq('id', id)
        .select()
        .single();
    
    return TransactionCategory.fromJson(response);
  }
  
  // Supprimer une catégorie
  Future<void> deleteCategory(String id) async {
    await _supabase
        .from('transaction_categories')
        .delete()
        .eq('id', id);
  }
  
  // Migrer les catégories statiques vers la base de données
  Future<void> migrateStaticCategories(
    Map<String, List<String>> categoriesMap,
    List<String> incomeCategories,
    List<String> expenseCategories
  ) async {
    // Migrer les catégories de revenus
    for (String category in incomeCategories) {
      try {
        final newCategory = await addCategory(
          category, 
          'income',
          description: 'Catégorie de revenu migrée'
        );
        
        // Migrer les sous-catégories si elles existent
        if (categoriesMap.containsKey(category)) {
          for (String subcategory in categoriesMap[category]!) {
            await _supabase.from('transaction_subcategories').insert({
              'category_id': newCategory.id,
              'name': subcategory,
              'description': 'Sous-catégorie migrée'
            });
          }
        }
      } catch (e) {
        print('Erreur lors de la migration de la catégorie $category: $e');
      }
    }
    
    // Migrer les catégories de dépenses
    for (String category in expenseCategories) {
      try {
        final newCategory = await addCategory(
          category, 
          'expense',
          description: 'Catégorie de dépense migrée'
        );
        
        // Migrer les sous-catégories si elles existent
        if (categoriesMap.containsKey(category)) {
          for (String subcategory in categoriesMap[category]!) {
            await _supabase.from('transaction_subcategories').insert({
              'category_id': newCategory.id,
              'name': subcategory,
              'description': 'Sous-catégorie migrée'
            });
          }
        }
      } catch (e) {
        print('Erreur lors de la migration de la catégorie $category: $e');
      }
    }
  }
}
