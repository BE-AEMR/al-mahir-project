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
  List<ProjectTransaction> _phaseTransactions = [];
  bool _isLoading = true;
  bool _isLoadingBudget = true;
  
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
    });
    
    try {
      // Charger les tâches de la phase
      final tasks = await _projectService.getTasksByProject(widget.project.id);
      final phaseTasks = tasks.where((task) => task.phaseId == _phase.id).toList();
      
      setState(() {
        _tasks = phaseTasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        _isLoading = false;
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
  
  void _showEditPhaseDialog() {
    showDialog(
      context: context,
      builder: (context) => PhaseForm(
        projectId: widget.project.id,
        phase: _phase,
        onPhaseUpdated: (updatedPhase) {
          setState(() {
            _phase = updatedPhase;
          });
        },
      ),
    );
  }
  
  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => TaskForm(
        projectId: widget.project.id,
        phaseId: _phase.id,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add_task),
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
                    
                    // Section budget
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransactionFormScreen(
                                  phaseId: _phase.id,
                                  projectId: widget.project.id,
                                ),
                              ),
                            );
                            
                            if (result != null) {
                              _loadBudgetData();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter une transaction'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _isLoadingBudget
                        ? const Center(child: CircularProgressIndicator())
                        : BudgetSummaryWidget(
                            budgetAllocated: _phase.budgetAllocated,
                            budgetConsumed: _phase.budgetConsumed,
                            transactions: _phaseTransactions,
                            projectId: widget.project.id,
                            phaseId: _phase.id,
                            onTransactionAdded: (transaction) {
                              setState(() {
                                _phaseTransactions.add(transaction);
                                // Mettre à jour le budget consommé
                                if (transaction.amount < 0) {
                                  _phase = _phase.copyWith(
                                    budgetConsumed: (_phase.budgetConsumed ?? 0) + transaction.amount.abs(),
                                  );
                                }
                              });
                              _loadBudgetData();
                            },
                            onTransactionUpdated: (transaction) {
                              setState(() {
                                final index = _phaseTransactions.indexWhere((t) => t.id == transaction.id);
                                if (index != -1) {
                                  _phaseTransactions[index] = transaction;
                                }
                              });
                              _loadBudgetData();
                            },
                          ),
                    
                    const SizedBox(height: 24),
                    
                    // Liste des tâches
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tâches (${_tasks.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddTaskDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter une tâche'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _tasks.isEmpty
                        ? Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: IslamicPatternPlaceholder(
                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aucune tâche dans cette phase',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Cliquez sur le bouton + pour ajouter une tâche',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              final taskStatus = TaskStatus.fromValue(task.status);
                              final taskPriority = TaskPriority.fromValue(task.priority);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TaskDetailScreen(
                                          task: task,
                                          onTaskUpdated: (updatedTask) {
                                            setState(() {
                                              final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
                                              if (index != -1) {
                                                _tasks[index] = updatedTask;
                                              }
                                            });
                                          },
                                          onTaskDeleted: (deletedTask) {
                                            setState(() {
                                              _tasks.removeWhere((t) => t.id == deletedTask.id);
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: taskStatus.getColor().withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                taskStatus.getText(),
                                                style: TextStyle(
                                                  color: taskStatus.getColor(),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          task.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (task.dueDate != null) ...[
                                              const Icon(Icons.calendar_today, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                            const Icon(Icons.person_outline, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              task.assignedTo ?? 'Non assigné',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: taskPriority.getColor().withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                taskPriority.getText(),
                                                style: TextStyle(
                                                  color: taskPriority.getColor(),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
