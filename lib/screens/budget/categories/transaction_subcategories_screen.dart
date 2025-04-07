import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/transaction_category_model.dart';
import '../../../models/transaction_subcategory_model.dart';
import '../../../services/transaction_subcategory_service.dart';
import 'transaction_subcategory_form_screen.dart';

class TransactionSubcategoriesScreen extends StatefulWidget {
  final TransactionCategory category;

  const TransactionSubcategoriesScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<TransactionSubcategoriesScreen> createState() => _TransactionSubcategoriesScreenState();
}

class _TransactionSubcategoriesScreenState extends State<TransactionSubcategoriesScreen> {
  final TransactionSubcategoryService _subcategoryService = TransactionSubcategoryService(Supabase.instance.client);
  
  List<TransactionSubcategory> _subcategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subcategories = await _subcategoryService.getSubcategoriesByCategory(widget.category.id);
      
      setState(() {
        _subcategories = subcategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des sous-catégories: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sous-catégories de ${widget.category.name}'),
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
                    onPressed: _loadSubcategories,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : _buildSubcategoriesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddSubcategory,
        child: const Icon(Icons.add),
        backgroundColor: widget.category.getColor(),
      ),
    );
  }

  Widget _buildSubcategoriesList() {
    if (_subcategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.category.getIcon(),
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune sous-catégorie',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToAddSubcategory,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une sous-catégorie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.category.getColor(),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubcategories,
      child: ListView.builder(
        itemCount: _subcategories.length,
        itemBuilder: (context, index) {
          final subcategory = _subcategories[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.category.getColor().withOpacity(0.2),
              child: Icon(
                widget.category.getIcon(),
                color: widget.category.getColor(),
                size: 20,
              ),
            ),
            title: Text(subcategory.name),
            subtitle: subcategory.description != null && subcategory.description!.isNotEmpty
                ? Text(subcategory.description!)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Modifier',
                  onPressed: () => _navigateToEditSubcategory(subcategory),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDeleteSubcategory(subcategory),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToAddSubcategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionSubcategoryFormScreen(
          category: widget.category,
        ),
      ),
    );

    if (result == true) {
      _loadSubcategories();
    }
  }

  void _navigateToEditSubcategory(TransactionSubcategory subcategory) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionSubcategoryFormScreen(
          category: widget.category,
          subcategory: subcategory,
        ),
      ),
    );

    if (result == true) {
      _loadSubcategories();
    }
  }

  void _confirmDeleteSubcategory(TransactionSubcategory subcategory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la sous-catégorie'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la sous-catégorie "${subcategory.name}" ? '
          'Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSubcategory(subcategory);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubcategory(TransactionSubcategory subcategory) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _subcategoryService.deleteSubcategory(subcategory.id);
      
      // Mettre à jour la liste des sous-catégories
      setState(() {
        _subcategories.removeWhere((s) => s.id == subcategory.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sous-catégorie "${subcategory.name}" supprimée'),
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
