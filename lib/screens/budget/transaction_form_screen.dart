import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/project_model.dart';
import '../../models/phase_model.dart';
import '../../models/task_model.dart';
import '../../models/project_transaction_model.dart';
import '../../models/transaction_category_model.dart';
import '../../models/transaction_subcategory_model.dart';
import '../../services/project_finance_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/transaction_category_service.dart';
import '../../services/transaction_subcategory_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/constants.dart';
import 'categories/transaction_categories_screen.dart';

class TransactionFormScreen extends StatefulWidget {
  final ProjectTransaction? transaction; // Si null, c'est une nouvelle transaction
  final String? projectId; // ID du projet pour une nouvelle transaction
  final String? phaseId; // ID de la phase pour une nouvelle transaction
  final String? taskId; // ID de la tâche pour une nouvelle transaction
  final String? initialProjectId; // ID du projet initialement sélectionné

  const TransactionFormScreen({
    Key? key, 
    this.transaction, 
    this.projectId,
    this.phaseId,
    this.taskId,
    this.initialProjectId,
  }) : super(key: key);

  @override
  _TransactionFormScreenState createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController(); 
  final _projectFinanceService = ProjectFinanceService();
  final _projectService = ProjectService();
  final _categoryService = TransactionCategoryService(Supabase.instance.client);
  final _subcategoryService = TransactionSubcategoryService(Supabase.instance.client);
  
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  bool _isIncomeTransaction = true;
  
  DateTime _transactionDate = DateTime.now();
  String? _selectedProjectId;
  String? _selectedPhaseId;
  String? _selectedTaskId;
  TransactionCategory? _selectedCategory;
  TransactionSubcategory? _selectedSubcategory;
  
  List<Project> _projects = [];
  List<Phase> _phases = [];
  List<Task> _tasks = [];
  List<TransactionCategory> _incomeCategories = [];
  List<TransactionCategory> _expenseCategories = [];
  List<TransactionSubcategory> _subcategories = [];

  @override
  void initState() {
    super.initState();

    _isEditing = widget.transaction != null;
    
    if (_isEditing) {
      _descriptionController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.abs().toString();
      _notesController.text = widget.transaction!.notes ?? '';
      _isIncomeTransaction = widget.transaction!.transactionType == 'income';
      _transactionDate = widget.transaction!.transactionDate;
      _selectedProjectId = widget.transaction!.projectId;
      _selectedPhaseId = widget.transaction!.phaseId;
      _selectedTaskId = widget.transaction!.taskId;
    } else {
      _selectedProjectId = widget.initialProjectId ?? widget.projectId;
      _selectedPhaseId = widget.phaseId;
      _selectedTaskId = widget.taskId;
    }
    
    _loadProjects();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isCategoriesLoading = true;
    });

    try {
      // Charger les catégories de revenu
      final incomeCategories = await _categoryService.getCategoriesByType('income');
      
      // Charger les catégories de dépenses
      final expenseCategories = await _categoryService.getCategoriesByType('expense');

      setState(() {
        _incomeCategories = incomeCategories;
        _expenseCategories = expenseCategories;
        
        // Sélectionner la première catégorie par défaut si nous n'éditons pas une transaction existante
        if (!_isEditing) {
          if (_isIncomeTransaction && _incomeCategories.isNotEmpty) {
            _selectedCategory = _incomeCategories.first;
          } else if (!_isIncomeTransaction && _expenseCategories.isNotEmpty) {
            _selectedCategory = _expenseCategories.first;
          }
          
          // Charger les sous-catégories pour la catégorie sélectionnée
          if (_selectedCategory != null) {
            _loadSubcategories(_selectedCategory!.id);
          }
        } else {
          // Si nous éditons une transaction existante, retrouver la catégorie et sous-catégorie
          _findAndSetCategoryAndSubcategory();
        }
        
        _isCategoriesLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: ${e.toString()}');
      SnackBarHelper.showErrorSnackBar(
        context, 
        'Erreur lors du chargement des catégories: ${e.toString()}'
      );
      setState(() {
        _isCategoriesLoading = false;
      });
    }
  }
  
  Future<void> _findAndSetCategoryAndSubcategory() async {
    if (widget.transaction == null) return;
    
    try {
      // Rechercher la catégorie par son nom
      final categories = _isIncomeTransaction ? _incomeCategories : _expenseCategories;
      final matchingCategory = categories.firstWhere(
        (cat) => cat.name == widget.transaction!.category,
        orElse: () => categories.isNotEmpty ? categories.first : TransactionCategory(
          id: 'default',
          name: 'Autre',
          transactionType: _isIncomeTransaction ? 'income' : 'expense',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      setState(() {
        _selectedCategory = matchingCategory;
      });
      
      // Charger les sous-catégories pour cette catégorie
      await _loadSubcategories(_selectedCategory!.id);
      
      // Rechercher la sous-catégorie par son nom
      if (widget.transaction!.subcategory != null) {
        final matchingSubcategory = _subcategories.firstWhere(
          (subcat) => subcat.name == widget.transaction!.subcategory,
          orElse: () => _subcategories.isNotEmpty ? _subcategories.first : _createDefaultSubcategory(_selectedCategory!.id),
        );
        
        setState(() {
          _selectedSubcategory = matchingSubcategory;
        });
      }
    } catch (e) {
      print('Erreur lors de la recherche de catégorie: ${e.toString()}');
    }
  }

  Future<void> _loadSubcategories(String categoryId) async {
    setState(() {
      _isCategoriesLoading = true;
    });

    try {
      final subcategories = await _subcategoryService.getSubcategoriesByCategory(categoryId);
      
      setState(() {
        _subcategories = subcategories;
        // Sélectionner la première sous-catégorie par défaut
        if (_subcategories.isNotEmpty) {
          _selectedSubcategory = _subcategories.first;
        } else {
          _selectedSubcategory = null;
        }
        _isCategoriesLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des sous-catégories: ${e.toString()}');
      setState(() {
        _subcategories = [];
        _selectedSubcategory = null;
        _isCategoriesLoading = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _projectService.getAllProjects();
      print('Projets récupérés: ${projects.length}');
      
      // Afficher les IDs et noms des projets pour déboguer
      for (var project in projects) {
        print('Projet trouvé: ${project.id} - ${project.name} - créé par: ${project.createdBy}');
      }
      
      final phases = await _projectService.getAllPhases();
      final tasks = await _projectService.getAllTasks();
      
      setState(() {
        _projects = projects;
        _phases = phases;
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: ${e.toString()}');
      SnackBarHelper.showErrorSnackBar(
        context, 
        'Erreur lors du chargement des données: ${e.toString()}'
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateTransactionType(bool isIncome) {
    if (_isIncomeTransaction == isIncome) return;
    
    setState(() {
      _isIncomeTransaction = isIncome;
      
      // Changer la sélection de catégorie en fonction du type de transaction
      if (_isIncomeTransaction && _incomeCategories.isNotEmpty) {
        _selectedCategory = _incomeCategories.first;
      } else if (!_isIncomeTransaction && _expenseCategories.isNotEmpty) {
        _selectedCategory = _expenseCategories.first;
      } else {
        _selectedCategory = null;
      }
      
      // Charger les sous-catégories pour la nouvelle catégorie sélectionnée
      if (_selectedCategory != null) {
        _loadSubcategories(_selectedCategory!.id);
      } else {
        _subcategories = [];
        _selectedSubcategory = null;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final description = _descriptionController.text.trim();
        final notes = _notesController.text.trim();
        double amount = double.parse(_amountController.text.replaceAll(',', '.'));
        if (!_isIncomeTransaction) {
          amount = -amount; // Montant négatif pour les dépenses
        }

        if (_isEditing) {
          // Mettre à jour la transaction existante
          final updatedTransaction = widget.transaction!.copyWith(
            description: description,
            notes: notes,
            amount: amount,
            transactionType: _isIncomeTransaction ? 'income' : 'expense',
            category: _selectedCategory?.name ?? 'Autre',
            subcategory: _selectedSubcategory?.name,
            projectId: _selectedProjectId,
            phaseId: _selectedPhaseId,
            taskId: _selectedTaskId,
            transactionDate: _transactionDate,
            updatedAt: DateTime.now(),
            categoryId: _selectedCategory?.id,
            subcategoryId: _selectedSubcategory?.id,
          );
          
          await _projectFinanceService.updateTransaction(updatedTransaction);
          
          if (!mounted) return;
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Transaction mise à jour avec succès'
          );
          Navigator.pop(context, updatedTransaction);
        } else {
          // Créer une nouvelle transaction
          final newTransaction = await _projectFinanceService.createTransaction(
            _selectedProjectId!,
            _selectedPhaseId,
            _selectedTaskId,
            amount,
            description,
            _transactionDate,
            _selectedCategory?.name ?? 'Autre',
            _selectedSubcategory?.name,
            notes: notes,
          );
          
          if (!mounted) return;
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Transaction créée avec succès'
          );
          Navigator.pop(context, newTransaction);
        }
      } catch (e) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur: ${e.toString()}'
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('fr', 'FR'),
    );

    if (pickedDate != null) {
      setState(() {
        _transactionDate = pickedDate;
      });
    }
  }

  // Méthode utilitaire pour créer une sous-catégorie par défaut
  TransactionSubcategory _createDefaultSubcategory(String categoryId) {
    return TransactionSubcategory(
      id: 'default',
      categoryId: categoryId,
      name: 'Autre',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la transaction' : 'Nouvelle transaction'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de la transaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type de transaction (Entrée/sortie)
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Entrée'),
                            value: true,
                            groupValue: _isIncomeTransaction,
                            onChanged: (value) {
                              setState(() {
                                _isIncomeTransaction = value!;
                                // Mettre à jour les catégories disponibles
                                _updateTransactionType(_isIncomeTransaction);
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Sortie'),
                            value: false,
                            groupValue: _isIncomeTransaction,
                            onChanged: (value) {
                              setState(() {
                                _isIncomeTransaction = value!;
                                // Mettre à jour les catégories disponibles
                                _updateTransactionType(_isIncomeTransaction);
                              });
                            },
                            activeColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir une description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Notes additionnelles
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes additionnelles',
                        hintText: 'Informations complémentaires (optionnel)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // Montant
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Montant (€)',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _isIncomeTransaction ? Icons.arrow_upward : Icons.arrow_downward,
                          color: _isIncomeTransaction ? Colors.green : Colors.red,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir un montant';
                        }
                        final amount = double.tryParse(value.replaceAll(',', '.'));
                        if (amount == null || amount <= 0) {
                          return 'Le montant doit être un nombre positif';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date de la transaction
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date de la transaction',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_transactionDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Catégorisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Catégorie avec bouton de gestion
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TransactionCategory>(
                            decoration: const InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            value: _selectedCategory,
                            items: (_isIncomeTransaction ? _incomeCategories : _expenseCategories)
                                .map((category) {
                              return DropdownMenuItem<TransactionCategory>(
                                value: category,
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedCategory = value;
                                  _loadSubcategories(value.id);
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.id.isEmpty) {
                                return 'Veuillez sélectionner une catégorie';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: IconButton(
                            icon: const Icon(Icons.settings),
                            tooltip: 'Gérer les catégories',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TransactionCategoriesScreen(
                                    initialType: _isIncomeTransaction ? 'income' : 'expense',
                                  ),
                                ),
                              ).then((_) {
                                // Actualiser les catégories à la fermeture de l'écran
                                _loadCategories();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Sous-catégorie
                    if (_subcategories.isNotEmpty)
                      DropdownButtonFormField<TransactionSubcategory>(
                        decoration: const InputDecoration(
                          labelText: 'Sous-catégorie',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.bookmark),
                        ),
                        value: _selectedSubcategory,
                        items: _subcategories.map((subcategory) {
                          return DropdownMenuItem<TransactionSubcategory>(
                            value: subcategory,
                            child: Text(subcategory.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubcategory = value;
                          });
                        },
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Attribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Projet
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Projet',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      value: _selectedProjectId,
                      items: _projects.map((project) {
                        return DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(project.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                          _selectedPhaseId = null;
                          _selectedTaskId = null;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez sélectionner un projet';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phase
                    if (_selectedProjectId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Phase',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.linear_scale),
                        ),
                        value: _selectedPhaseId,
                        items: _phases.where((phase) => phase.projectId == _selectedProjectId).map((phase) {
                          return DropdownMenuItem<String>(
                            value: phase.id,
                            child: Text(phase.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPhaseId = value;
                            _selectedTaskId = null;
                          });
                        },
                        validator: (value) {
                          if (_selectedProjectId != null && (value == null || value.isEmpty)) {
                            return 'Veuillez sélectionner une phase';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    // Tâche
                    if (_selectedProjectId != null && _selectedPhaseId != null)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Tâche',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.check_box),
                        ),
                        value: _selectedTaskId,
                        items: _tasks.where((task) => task.projectId == _selectedProjectId && task.phaseId == _selectedPhaseId).map((task) {
                          return DropdownMenuItem<String>(
                            value: task.id,
                            child: Text(task.title),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTaskId = value;
                          });
                        },
                        validator: (value) {
                          if (_selectedProjectId != null && _selectedPhaseId != null && (value == null || value.isEmpty)) {
                            return 'Veuillez sélectionner une tâche';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                        child: Text(_isEditing ? 'Mettre à jour' : 'Créer'),
                      ),
                    ),
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () {
                              // Afficher une boîte de dialogue de confirmation
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Supprimer la transaction'),
                                  content: const Text(
                                    'Êtes-vous sûr de vouloir supprimer cette transaction ? Cette action ne peut pas être annulée.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        try {
                                          await _projectFinanceService.deleteTransaction(widget.transaction!.id);
                                          if (!mounted) return;
                                          SnackBarHelper.showSuccessSnackBar(
                                            context, 
                                            'Transaction supprimée avec succès'
                                          );
                                          Navigator.pop(context, {'deleted': true, 'transactionId': widget.transaction!.id});
                                        } catch (e) {
                                          SnackBarHelper.showErrorSnackBar(
                                            context, 
                                            'Erreur lors de la suppression: ${e.toString()}'
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                          }
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
