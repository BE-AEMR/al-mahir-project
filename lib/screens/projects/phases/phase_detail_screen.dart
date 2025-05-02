import 'package:flutter/material.dart';
import '../../../models/phase_model.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/project_transaction_model.dart';
import '../../../services/phase_service/phase_service.dart';
import '../../../services/project_service/project_service.dart';
import '../../../services/budget_service.dart';
import '../../../widgets/islamic_patterns.dart';
import '../../../widgets/budget_summary_widget.dart';
import '../../tasks/task_form.dart';
import '../../tasks/task_detail_screen.dart';
import '../../budget/transaction_form_screen.dart';
import 'phase_form.dart';

class PhaseDetailScreen extends StatefulWidget {
  final Project project;
  final Phase phase;

  const PhaseDetailScreen({
    super.key,
    required this.project,
    required this.phase,
  });

  @override
  State<PhaseDetailScreen> createState() => _PhaseDetailScreenState();
}

class _PhaseDetailScreenState extends State<PhaseDetailScreen> {
  final PhaseService _phaseService = PhaseService();
  final ProjectService _projectService = ProjectService();
  final BudgetService _budgetService = BudgetService();

  late Phase _phase;
  List<Task> _tasks = [];
  List<Phase> _subPhases = [];
  List<ProjectTransaction> _phaseTransactions = [];
  bool _isLoading = true;
  bool _isLoadingBudget = true;
  bool _isLoadingSubPhases = true;

  @override
  void initState() {
    super.initState();
    _phase = widget.phase;
    _loadData();
    _loadBudgetData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingSubPhases = true;
    });

    try {
      // Charger les tâches de la phase
      final tasks = await _projectService.getTasksByProject(widget.project.id);
      final phaseTasks = tasks.where((task) => task.phaseId == _phase.id).toList();

      // Charger les sous-phases
      final subPhases = await _phaseService.getSubPhasesByParentId(_phase.id);

      setState(() {
        _tasks = phaseTasks;
        _subPhases = subPhases;
        _isLoading = false;
        _isLoadingSubPhases = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
        _isLoadingSubPhases = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des données: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBudgetData() async {
    setState(() {
      _isLoadingBudget = true;
    });

    try {
      // Charger les transactions de la phase
      final transactions = await _budgetService.getTransactionsByPhase(_phase.id);

      setState(() {
        _phaseTransactions = transactions;
        _isLoadingBudget = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des transactions: $e');
      setState(() {
        _isLoadingBudget = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditPhaseDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhaseForm(
          projectId: widget.project.id,
          phase: _phase,
          onPhaseUpdated: (updatedPhase) {
            setState(() {
              _phase = updatedPhase;
            });
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _phase = result;
      });
    }
  }

  Future<void> _showAddSubPhaseDialog() async {
    // Utiliser un dialogue simple pour créer une sous-phase
    final formKey = GlobalKey<FormState>();
    String name = '';
    String description = '';
    String status = PhaseStatus.notStarted.toValue(); // Initialiser avec le statut par défaut

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une sous-phase'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                    onSaved: (value) => name = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer une description';
                      }
                      return null;
                    },
                    onSaved: (value) => description = value!,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PhaseStatus.notStarted.toValue(),
                        child: Text(PhaseStatus.notStarted.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.inProgress.toValue(),
                        child: Text(PhaseStatus.inProgress.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.completed.toValue(),
                        child: Text(PhaseStatus.completed.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.onHold.toValue(),
                        child: Text(PhaseStatus.onHold.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.cancelled.toValue(),
                        child: Text(PhaseStatus.cancelled.getText()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          status = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        setState(() {
          _isLoadingSubPhases = true;
        });

        // Créer la sous-phase
        final subPhase = await _phaseService.createSubPhase(
          _phase.id,
          name,
          description,
          status: status,
        );

        setState(() {
          _subPhases.add(subPhase);
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sous-phase ajoutée avec succès')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditSubPhaseDialog(Phase subPhase) async {
    // Utiliser un dialogue simple pour modifier une sous-phase
    final formKey = GlobalKey<FormState>();
    String name = subPhase.name;
    String description = subPhase.description;
    String status = subPhase.status;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier la sous-phase'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nom'),
                    initialValue: name,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un nom';
                      }
                      return null;
                    },
                    onSaved: (value) => name = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    initialValue: description,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer une description';
                      }
                      return null;
                    },
                    onSaved: (value) => description = value!,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PhaseStatus.notStarted.toValue(),
                        child: Text(PhaseStatus.notStarted.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.inProgress.toValue(),
                        child: Text(PhaseStatus.inProgress.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.completed.toValue(),
                        child: Text(PhaseStatus.completed.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.onHold.toValue(),
                        child: Text(PhaseStatus.onHold.getText()),
                      ),
                      DropdownMenuItem(
                        value: PhaseStatus.cancelled.toValue(),
                        child: Text(PhaseStatus.cancelled.getText()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          status = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        setState(() {
          _isLoadingSubPhases = true;
        });

        // Mettre à jour la sous-phase
        final updatedSubPhase = subPhase.copyWith(
          name: name,
          description: description,
          status: status,
          updatedAt: DateTime.now().toUtc(),
        );

        await _phaseService.updatePhase(updatedSubPhase);

        setState(() {
          final index = _subPhases.indexWhere((p) => p.id == subPhase.id);
          if (index != -1) {
            _subPhases[index] = updatedSubPhase;
          }
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sous-phase mise à jour avec succès')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteSubPhase(Phase subPhase) async {
    // Demander confirmation avant de supprimer
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la sous-phase'),
        content: Text('Voulez-vous vraiment supprimer la sous-phase "${subPhase.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() {
          _isLoadingSubPhases = true;
        });

        // Supprimer la sous-phase
        await _phaseService.deletePhase(subPhase.id);

        setState(() {
          _subPhases.removeWhere((p) => p.id == subPhase.id);
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sous-phase supprimée avec succès')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoadingSubPhases = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => TaskForm(
        projectId: widget.project.id,
        phaseId: _phase.id,
        subPhases: _subPhases, // Passer les sous-phases disponibles
        onTaskCreated: (task) {
          setState(() {
            _tasks.add(task);
          });
        },
      ),
    );
  }

  Future<void> _deletePhase() async {
    try {
      await _phaseService.deletePhase(_phase.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phase supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression de la phase: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression de la phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final phaseStatus = PhaseStatus.fromValue(_phase.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(_phase.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditPhaseDialog,
            tooltip: 'Modifier la phase',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer la phase'),
                  content: const Text(
                    'Êtes-vous sûr de vouloir supprimer cette phase ? '
                        'Les tâches associées à cette phase seront dissociées mais pas supprimées.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePhase();
                      },
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Supprimer la phase',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations sur la phase
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: phaseStatus.getColor().withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              phaseStatus.getText(),
                              style: TextStyle(
                                color: phaseStatus.getColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Projet: ${widget.project.name}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_phase.description.isNotEmpty
                          ? _phase.description
                          : 'Aucune description'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Créée le ${_phase.createdAt.day}/${_phase.createdAt.month}/${_phase.createdAt.year}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),



              // Liste des sous-phases
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sous-phases (${_subPhases.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddSubPhaseDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une sous-phase'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _isLoadingSubPhases
                  ? const Center(child: CircularProgressIndicator())
                  : _subPhases.isEmpty
                  ? Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: IslamicPatternPlaceholder(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucune sous-phase',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subPhases.length,
                itemBuilder: (context, index) {
                  final subPhase = _subPhases[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(subPhase.name),
                      subtitle: Text(subPhase.description),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditSubPhaseDialog(subPhase),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteSubPhase(subPhase),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),


            ],
          ),
        ),
      ),
    );
  }
}
