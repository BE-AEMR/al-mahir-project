import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/transaction_category_model.dart';
import '../../../services/transaction_category_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class TransactionCategoryFormScreen extends StatefulWidget {
  final String transactionType;
  final TransactionCategory? category;

  const TransactionCategoryFormScreen({
    Key? key,
    required this.transactionType,
    this.category,
  }) : super(key: key);

  @override
  State<TransactionCategoryFormScreen> createState() => _TransactionCategoryFormScreenState();
}

class _TransactionCategoryFormScreenState extends State<TransactionCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final TransactionCategoryService _categoryService = TransactionCategoryService(Supabase.instance.client);

  bool _isLoading = false;
  String? _errorMessage;

  // Icône sélectionnée
  IconData? _selectedIcon;
  String? _selectedIconCode;

  // Couleur sélectionnée
  Color _selectedColor = Colors.blue;
  String? _selectedColorCode;

  // Liste des icônes communes pour les catégories
  final List<IconData> _commonIcons = [
    Icons.shopping_cart,
    Icons.home,
    Icons.restaurant,
    Icons.directions_car,
    Icons.local_gas_station,
    Icons.local_hospital,
    Icons.school,
    Icons.flight,
    Icons.fitness_center,
    Icons.movie,
    Icons.attach_money,
    Icons.account_balance,
    Icons.credit_card,
    Icons.computer,
    Icons.phone_android,
    Icons.local_grocery_store,
    Icons.local_pizza,
    Icons.local_bar,
    Icons.local_cafe,
    Icons.local_parking,
    Icons.pets
  ];

  @override
  void initState() {
    super.initState();

    // Si on édite une catégorie existante, récupérer ses valeurs
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';

      // Récupérer l'icône si elle existe
      if (widget.category!.icon != null && widget.category!.icon!.isNotEmpty) {
        try {
          _selectedIconCode = widget.category!.icon;
          // Utiliser la méthode statique pour obtenir l'icône à partir du code
          _selectedIcon = TransactionCategory.getIconFromString(widget.category!.icon!) ?? Icons.category;
        } catch (e) {
          print('Erreur lors de la récupération de l\'icône: $e');
          _selectedIcon = Icons.category;
        }
      } else {
        _selectedIcon = Icons.category;
      }

      // Récupérer la couleur si elle existe
      if (widget.category!.color != null && widget.category!.color!.isNotEmpty) {
        try {
          _selectedColor = Color(int.parse(widget.category!.color!, radix: 16));
        } catch (e) {
          print('Erreur lors de la récupération de la couleur: $e');
          _selectedColor = widget.category!.getColor();
        }
      } else {
        _selectedColor = widget.category!.getColor();
      }
    } else {
      // Couleurs par défaut pour les nouvelles catégories
      if (widget.transactionType == 'income') {
        _selectedColor = Colors.green;
      } else if (widget.transactionType == 'expense') {
        _selectedColor = Colors.red;
      }

      // Icône par défaut
      _selectedIcon = Icons.category;
      _selectedIconCode = Icons.category.codePoint.toRadixString(16);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Méthode pour ouvrir le sélecteur d'icônes personnalisé
  void _pickIcon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une icône'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _commonIcons.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIcon = _commonIcons[index];
                    _selectedIconCode = _commonIcons[index].codePoint.toRadixString(16);
                  });
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _commonIcons[index],
                    size: 30,
                    color: _selectedColor,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // Méthode pour ouvrir le sélecteur de couleurs
  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une couleur'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Convertir la couleur en chaîne hexadécimale
              _selectedColorCode = '#${_selectedColor.value.toRadixString(16).substring(2)}';
            },
            child: const Text('Sélectionner'),
          ),
        ],
      ),
    );
  }

  // Méthode pour sauvegarder la catégorie
  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.category == null) {
        // Ajouter une nouvelle catégorie
        await _categoryService.addCategory(
          _nameController.text.trim(),
          widget.transactionType,
          description: _descriptionController.text.trim(),
          icon: _selectedIconCode,
          color: _selectedColorCode,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Catégorie ajoutée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Mettre à jour une catégorie existante
        await _categoryService.updateCategory(
          widget.category!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _selectedIconCode,
          color: _selectedColorCode,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Catégorie mise à jour avec succès'),
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
    final String title = widget.category == null
        ? 'Nouvelle catégorie de ${widget.transactionType == 'income' ? 'revenu' : 'dépense'}'
        : 'Modifier la catégorie';

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

                    // Nom de la catégorie
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la catégorie',
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
                    const SizedBox(height: 24),

                    // Sélecteur d'icône
                    Row(
                      children: [
                        const Text(
                          'Icône:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: _pickIcon,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: _selectedIcon != null
                                ? Icon(_selectedIcon, size: 32)
                                : const Icon(Icons.add, size: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _pickIcon,
                          icon: const Icon(Icons.edit),
                          label: const Text('Changer l\'icône'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sélecteur de couleur
                    Row(
                      children: [
                        const Text(
                          'Couleur:',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: _pickColor,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _pickColor,
                          icon: const Icon(Icons.color_lens),
                          label: const Text('Changer la couleur'),
                        ),
                      ],
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
                          onPressed: _saveCategory,
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
