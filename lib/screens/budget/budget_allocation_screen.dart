import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../models/project_model.dart';
import '../../services/budget_service.dart';
import '../../services/project_service/project_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/constants.dart';

class BudgetAllocationScreen extends StatefulWidget {
  final String? initialBudgetId;
  final String? initialProjectId;
  final String? projectId;

  const BudgetAllocationScreen({
    Key? key,
    this.initialBudgetId,
    this.initialProjectId,
    this.projectId,
  }) : super(key: key);

  @override
  _BudgetAllocationScreenState createState() => _BudgetAllocationScreenState();
}

class _BudgetAllocationScreenState extends State<BudgetAllocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  final BudgetService _budgetService = BudgetService();
  final ProjectService _projectService = ProjectService();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  List<Budget> _budgets = [];
  List<Project> _projects = [];
  
  String? _selectedBudgetId;
  String? _selectedProjectId;
  Budget? _selectedBudget;
  Project? _selectedProject;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.initialBudgetId;
    _selectedProjectId = widget.initialProjectId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final budgets = await _budgetService.getAllBudgets();
      final projects = await _projectService.getAllProjects();
      
      setState(() {
        _budgets = budgets;
        _projects = projects;
        
        // Si les valeurs initiales n'étaient pas définies, sélectionner les premiers éléments par défaut
        if (_selectedBudgetId == null && budgets.isNotEmpty) {
          _selectedBudgetId = budgets.first.id;
        }
        if (_selectedProjectId == null && projects.isNotEmpty) {
          _selectedProjectId = projects.first.id;
        }
        
        _updateSelectedItems();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données: $e';
        _isLoading = false;
      });
    }
  }

  void _updateSelectedItems() {
    if (_budgets.isEmpty) {
      _selectedBudget = null;
    } else {
      _selectedBudget = _budgets.firstWhere(
        (budget) => budget.id == _selectedBudgetId,
        orElse: () => _budgets.first,
      );
    }
    
    if (_projects.isEmpty) {
      _selectedProject = null;
    } else {
      _selectedProject = _projects.firstWhere(
        (project) => project.id == _selectedProjectId,
        orElse: () => _projects.first,
      );
    }
    
    if (_selectedBudget != null) {
      _selectedBudgetId = _selectedBudget!.id;
    }
    if (_selectedProject != null) {
      _selectedProjectId = _selectedProject!.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final amount = double.parse(_amountController.text.replaceAll(',', '.'));
        final note = _noteController.text.trim();
        
        // Vérifier si le budget sélectionné a suffisamment de fonds
        if (_selectedBudget!.currentAmount < amount) {
          SnackBarHelper.showErrorSnackBar(
            context, 
            'Fonds insuffisants: le budget ${_selectedBudget!.name} ne dispose que de ${_currencyFormat.format(_selectedBudget!.currentAmount)}'
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // Allouer le budget au projet
        await _budgetService.allocateBudgetToProject(
          _selectedBudgetId!,
          _selectedProjectId!,
          amount,
          note,
        );
        
        // Rafraîchir les données après l'allocation
        await _loadData();
        
        if (!mounted) return;
        SnackBarHelper.showSuccessSnackBar(
          context, 
          'Budget alloué avec succès au projet'
        );
        
        // Réinitialiser le formulaire
        _amountController.clear();
        _noteController.clear();
      } catch (e) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors de l\'allocation: ${e.toString()}'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allouer un budget'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Allocation de budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Transférez des fonds d\'un budget global vers un projet spécifique.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Sélection du budget source
                        const Text(
                          'Source des fonds',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Budget source',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          value: _selectedBudgetId,
                          items: _budgets.map((budget) {
                            return DropdownMenuItem<String>(
                              value: budget.id,
                              child: Text('${budget.name} (${_currencyFormat.format(budget.currentAmount)})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBudgetId = value;
                              _updateSelectedItems();
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez sélectionner un budget source';
                            }
                            return null;
                          },
                        ),
                        if (_selectedBudget != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Fonds disponibles: ${_currencyFormat.format(_selectedBudget!.currentAmount)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        
                        // Sélection du projet destination
                        const Text(
                          'Destination des fonds',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Projet destinataire',
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
                              _updateSelectedItems();
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez sélectionner un projet destinataire';
                            }
                            return null;
                          },
                        ),
                        if (_selectedProject != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Budget actuel: ${_currencyFormat.format(_selectedProject!.budgetAllocated ?? 0)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        
                        // Montant à allouer
                        const Text(
                          'Détails de l\'allocation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Montant à allouer (€)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.euro),
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
                            if (_selectedBudget != null && amount > _selectedBudget!.currentAmount) {
                              return 'Fonds insuffisants dans le budget source';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Note ou description (optionnel)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          minLines: 2,
                          maxLines: 4,
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
                            child: const Text('Allouer le budget'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
