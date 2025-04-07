import 'package:flutter/material.dart';
import '../budget/transaction_form_screen.dart';

/// Cette classe est maintenue pour compatibilité avec le code existant
/// mais elle redirige vers TransactionFormScreen qui est plus complète.
/// À terme, toutes les références à cette classe devraient être remplacées
/// par des références directes à TransactionFormScreen.
class ProjectTransactionScreen extends StatelessWidget {
  final String? initialProjectId;
  final String? projectId;
  final String? phaseId;
  final String? taskId;

  const ProjectTransactionScreen({
    Key? key,
    this.initialProjectId,
    this.projectId,
    this.phaseId,
    this.taskId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Redirection vers le formulaire complet
    return TransactionFormScreen(
      initialProjectId: initialProjectId,
      projectId: projectId,
      phaseId: phaseId,
      taskId: taskId,
    );
  }
}
