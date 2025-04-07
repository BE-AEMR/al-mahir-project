import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/transaction_category_model.dart';
import '../../../services/transaction_category_service.dart';
import 'transaction_category_form_screen.dart';
import 'transaction_subcategories_screen.dart';

class TransactionCategoriesScreen extends StatefulWidget {
  final String? initialType; // Type initial: 'income' ou 'expense'
  
  const TransactionCategoriesScreen({
    Key? key,
    this.initialType,
  }) : super(key: key);

  @override
  State<TransactionCategoriesScreen> createState() => _TransactionCategoriesScreenState();
}

class _TransactionCategoriesScreenState extends State<TransactionCategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionCategoryService _categoryService = TransactionCategoryService(Supabase.instance.client);
  
  List<TransactionCategory> _incomeCategories = [];
  List<TransactionCategory> _expenseCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialiser l'onglet en fonction du type fourni
    if (widget.initialType != null) {
      if (widget.initialType == 'expense') {
        _tabController.animateTo(1); // Sélectionner l'onglet des dépenses
      } else {
        _tabController.animateTo(0); // Sélectionner l'onglet des revenus
      }
    }
    
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger les catégories de revenus
      final incomeCategories = await _categoryService.getCategoriesByType('income');
      
      // Charger les catégories de dépenses
      final expenseCategories = await _categoryService.getCategoriesByType('expense');

      setState(() {
        _incomeCategories = incomeCategories;
        _expenseCategories = expenseCategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des catégories: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories de transactions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Couleur du texte de l'onglet sélectionné en blanc
          unselectedLabelColor: Colors.white70, // Couleur du texte des onglets non sélectionnés en blanc légèrement transparent
          indicatorColor: Colors.white, // Couleur de l'indicateur (barre sous l'onglet sélectionné) en blanc
          tabs: const [
            Tab(text: 'Revenus'),
            Tab(text: 'Dépenses'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCategories,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesList(_incomeCategories, 'income'),
                _buildCategoriesList(_expenseCategories, 'expense'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddCategory(
          _tabController.index == 0 ? 'income' : 'expense'
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoriesList(List<TransactionCategory> categories, String type) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              type == 'income' 
                ? 'Aucune catégorie de revenus' 
                : 'Aucune catégorie de dépenses',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddCategory(type),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une catégorie'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: category.getColor().withOpacity(0.2),
              child: Icon(
                category.getIcon(),
                color: category.getColor(),
              ),
            ),
            title: Text(category.name),
            subtitle: Text(category.description ?? 'Aucune description'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.list),
                  tooltip: 'Gérer les sous-catégories',
                  onPressed: () => _navigateToSubcategories(category),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Modifier',
                  onPressed: () => _navigateToEditCategory(category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDeleteCategory(category),
                ),
              ],
            ),
            onTap: () => _navigateToSubcategories(category),
          );
        },
      ),
    );
  }

  void _navigateToAddCategory(String transactionType) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionCategoryFormScreen(
          transactionType: transactionType,
        ),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  void _navigateToEditCategory(TransactionCategory category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionCategoryFormScreen(
          transactionType: category.transactionType,
          category: category,
        ),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  void _navigateToSubcategories(TransactionCategory category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionSubcategoriesScreen(
          category: category,
        ),
      ),
    );

    if (result == true) {
      // Pas besoin de recharger les catégories ici car nous avons modifié des sous-catégories
    }
  }

  void _confirmDeleteCategory(TransactionCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la catégorie "${category.name}" ? '
          'Cette action supprimera également toutes les sous-catégories associées et '
          'ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(category);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(TransactionCategory category) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _categoryService.deleteCategory(category.id);
      
      // Mettre à jour la liste des catégories
      setState(() {
        if (category.transactionType == 'income') {
          _incomeCategories.removeWhere((c) => c.id == category.id);
        } else {
          _expenseCategories.removeWhere((c) => c.id == category.id);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catégorie "${category.name}" supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
