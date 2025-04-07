import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/transaction_category_model.dart';
import '../../../models/transaction_subcategory_model.dart';
import '../../../services/transaction_subcategory_service.dart';

class TransactionSubcategoryFormScreen extends StatefulWidget {
  final TransactionCategory category;
  final TransactionSubcategory? subcategory;

  const TransactionSubcategoryFormScreen({
    Key? key,
    required this.category,
    this.subcategory,
  }) : super(key: key);

  @override
  State<TransactionSubcategoryFormScreen> createState() => _TransactionSubcategoryFormScreenState();
}

class _TransactionSubcategoryFormScreenState extends State<TransactionSubcategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final TransactionSubcategoryService _subcategoryService = TransactionSubcategoryService(Supabase.instance.client);
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Si on édite une sous-catégorie existante, récupérer ses valeurs
    if (widget.subcategory != null) {
      _nameController.text = widget.subcategory!.name;
      _descriptionController.text = widget.subcategory!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Méthode pour sauvegarder la sous-catégorie
  Future<void> _saveSubcategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.subcategory == null) {
        // Ajouter une nouvelle sous-catégorie
        await _subcategoryService.addSubcategory(
          widget.category.id,
          _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sous-catégorie ajoutée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Mettre à jour une sous-catégorie existante
        await _subcategoryService.updateSubcategory(
          widget.subcategory!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sous-catégorie mise à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.subcategory == null
        ? 'Nouvelle sous-catégorie'
        : 'Modifier la sous-catégorie';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations sur la catégorie parente
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.category.getColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.category.getColor().withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.category.getIcon(),
                            color: widget.category.getColor(),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Catégorie: ${widget.category.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (widget.category.description != null && widget.category.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(widget.category.description!),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Nom de la sous-catégorie
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la sous-catégorie',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optionnelle)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Boutons d'action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _saveSubcategory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.category.getColor(),
                          ),
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
