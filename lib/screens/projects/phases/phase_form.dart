import 'package:flutter/material.dart';
import '../../../models/phase_model.dart';
import '../../../services/phase_service/phase_service.dart';

class PhaseForm extends StatefulWidget {
  final String projectId;
  final Phase? phase;
  final int orderIndex;
  final Function(Phase)? onPhaseCreated;
  final Function(Phase)? onPhaseUpdated;

  const PhaseForm({
    super.key,
    required this.projectId,
    this.phase,
    this.orderIndex = 0,
    this.onPhaseCreated,
    this.onPhaseUpdated,
  });

  @override
  State<PhaseForm> createState() => _PhaseFormState();
}

class _PhaseFormState extends State<PhaseForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = PhaseStatus.notStarted.toValue();
  bool _isLoading = false;

  final PhaseService _phaseService = PhaseService();

  @override
  void initState() {
    super.initState();
    if (widget.phase != null) {
      _nameController.text = widget.phase!.name;
      _descriptionController.text = widget.phase!.description;
      _status = widget.phase!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (widget.phase == null) {
          // Créer une nouvelle phase
          final phase = await _phaseService.createPhase(
            widget.projectId,
            _nameController.text,
            _descriptionController.text,
            widget.orderIndex,
          );

          if (widget.onPhaseCreated != null) {
            widget.onPhaseCreated!(phase);
          }
        } else {
          // Mettre à jour une phase existante
          final updatedPhase = widget.phase!.copyWith(
            name: _nameController.text,
            description: _descriptionController.text,
            status: _status,
          );

          await _phaseService.updatePhase(updatedPhase);

          if (widget.onPhaseUpdated != null) {
            widget.onPhaseUpdated!(updatedPhase);
          }
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.phase == null
                    ? 'Phase créée avec succès'
                    : 'Phase mise à jour avec succès',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Erreur lors de la soumission du formulaire: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    return AlertDialog(
      title: Text(widget.phase == null ? 'Ajouter une phase' : 'Modifier la phase'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la phase',
                  hintText: 'Ex: Conception, Développement, Tests...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom pour la phase';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Description de la phase...',
                ),
                maxLines: 3,
              ),
              if (widget.phase != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
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
                        _status = value;
                      });
                    }
                  },
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
              : Text(widget.phase == null ? 'Ajouter' : 'Mettre à jour'),
        ),
      ],
    );
  }
}
