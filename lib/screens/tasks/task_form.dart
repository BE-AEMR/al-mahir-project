import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../services/project_service/project_service.dart';
import '../../services/auth_service.dart';

class TaskForm extends StatefulWidget {
  final String projectId;
  final String? phaseId;
  final Task? task;
  final Function(Task)? onTaskCreated;
  final Function(Task)? onTaskUpdated;

  const TaskForm({
    super.key,
    required this.projectId,
    this.phaseId,
    this.task,
    this.onTaskCreated,
    this.onTaskUpdated,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assignedToController = TextEditingController();
  
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();
  final _uuid = Uuid();
  
  String _status = TaskStatus.todo.toValue();
  int _priority = TaskPriority.medium.value;
  DateTime? _dueDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      if (widget.task!.assignedTo != null) {
        _assignedToController.text = widget.task!.assignedTo!;
      }
      _status = widget.task!.status;
      _priority = widget.task!.priority;
      _dueDate = widget.task!.dueDate;
    } else {
      // Par défaut, assigner la tâche à l'utilisateur actuel
      _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _assignedToController.text = user.id;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'utilisateur actuel: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assignedToController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        if (widget.task == null) {
          // Créer une nouvelle tâche
          final taskId = _uuid.v4();
          final now = DateTime.now().toUtc();
          final userId = _authService.getCurrentUserIdSync() ?? 'unknown';

          final task = Task(
            id: taskId,
            projectId: widget.projectId,
            phaseId: widget.phaseId,
            title: _titleController.text,
            description: _descriptionController.text,
            createdAt: now,
            dueDate: _dueDate,
            assignedTo: _assignedToController.text,
            createdBy: userId,
            status: _status,
            priority: _priority,
          );

          await _projectService.createTask(task);

          if (widget.onTaskCreated != null) {
            widget.onTaskCreated!(task);
          }
        } else {
          // Mettre à jour une tâche existante
          final updatedTask = widget.task!.copyWith(
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: _dueDate,
            assignedTo: _assignedToController.text,
            status: _status,
            priority: _priority,
            phaseId: widget.phaseId,
            updatedAt: DateTime.now().toUtc(),
          );

          await _projectService.updateTask(updatedTask);

          if (widget.onTaskUpdated != null) {
            widget.onTaskUpdated!(updatedTask);
          }
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.task == null
                    ? 'Tâche créée avec succès'
                    : 'Tâche mise à jour avec succès',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Erreur lors de la soumission du formulaire: $e');
        setState(() {
          _errorMessage = 'Une erreur est survenue: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _dueDate && mounted) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Ajouter une tâche' : 'Modifier la tâche'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Titre de la tâche',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Description de la tâche',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assignedToController,
                decoration: const InputDecoration(
                  labelText: 'Assigné à',
                  hintText: 'ID de l\'utilisateur',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un utilisateur assigné';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDueDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date d\'échéance',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                              : 'Sélectionner une date',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectDueDate,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                ),
                items: [
                  DropdownMenuItem(
                    value: TaskStatus.todo.toValue(),
                    child: Text(TaskStatus.todo.getText()),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.inProgress.toValue(),
                    child: Text(TaskStatus.inProgress.getText()),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.completed.toValue(),
                    child: Text(TaskStatus.completed.getText()),
                  ),
                  //DropdownMenuItem(
                  //  value: TaskStatus.onHold.toValue(),
                  //  child: Text(TaskStatus.onHold.getText()),
                  //),
                  //DropdownMenuItem(
                  //  value: TaskStatus.cancelled.toValue(),
                  //  child: Text(TaskStatus.cancelled.getText()),
                  //),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priorité',
                ),
                items: [
                  DropdownMenuItem(
                    value: TaskPriority.low.value,
                    child: Text(TaskPriority.low.getText()),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.medium.value,
                    child: Text(TaskPriority.medium.getText()),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.high.value,
                    child: Text(TaskPriority.high.getText()),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.urgent.value,
                    child: Text(TaskPriority.urgent.getText()),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _priority = value;
                    });
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(widget.task == null ? 'Ajouter' : 'Mettre à jour'),
        ),
      ],
    );
  }
}
