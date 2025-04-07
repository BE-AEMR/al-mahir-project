import 'package:flutter/material.dart';

class BudgetTransaction {
  final String id;
  final String? budgetId;
  final String? projectId;
  final String? projectName;  // Ajout du nom du projet
  final String? phaseId;
  final String? phaseName;    // Ajout du nom de la phase
  final String? taskId;
  final String? taskName;     // Ajout du nom de la tâche
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String category;
  final String? subcategory;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  BudgetTransaction({
    required this.id,
    this.budgetId,
    this.projectId,
    this.projectName,
    this.phaseId,
    this.phaseName,
    this.taskId,
    this.taskName,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.category,
    this.subcategory,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convertir un objet JSON en objet BudgetTransaction
  factory BudgetTransaction.fromJson(Map<String, dynamic> json) {
    return BudgetTransaction(
      id: json['id'] as String,
      budgetId: json['budget_id'] as String?,
      projectId: json['project_id'] as String?,
      projectName: json['project_name'] as String?,
      phaseId: json['phase_id'] as String?,
      phaseName: json['phase_name'] as String?,
      taskId: json['task_id'] as String?,
      taskName: json['task_name'] as String?,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }

  // Convertir un objet BudgetTransaction en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'budget_id': budgetId,
      'project_id': projectId,
      'phase_id': phaseId,
      'task_id': taskId,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'category': category,
      'subcategory': subcategory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Créer une copie de l'objet BudgetTransaction avec des valeurs modifiées
  BudgetTransaction copyWith({
    String? id,
    String? budgetId,
    String? projectId,
    String? projectName,
    String? phaseId,
    String? phaseName,
    String? taskId,
    String? taskName,
    double? amount,
    String? description,
    DateTime? transactionDate,
    String? category,
    String? subcategory,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return BudgetTransaction(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      phaseId: phaseId ?? this.phaseId,
      phaseName: phaseName ?? this.phaseName,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Vérifier si c'est une entrée d'argent
  bool get isIncome {
    return amount > 0;
  }

  // Vérifier si c'est une sortie d'argent
  bool get isExpense {
    return amount < 0;
  }

  // Obtenir la valeur absolue du montant
  double get absoluteAmount {
    return amount.abs();
  }

  // Obtenir une couleur en fonction du type de transaction
  Color getAmountColor() {
    return isIncome ? Colors.green : Colors.red;
  }

  // Obtenir une icône en fonction du type de transaction
  IconData getAmountIcon() {
    return isIncome ? Icons.arrow_upward : Icons.arrow_downward;
  }
}

// Énumération pour les catégories de transactions
enum TransactionCategory {
  income,
  expense;

  String get displayName {
    switch (this) {
      case TransactionCategory.income:
        return 'Entrée';
      case TransactionCategory.expense:
        return 'Sortie';
    }
  }

  String toValue() {
    switch (this) {
      case TransactionCategory.income:
        return 'income';
      case TransactionCategory.expense:
        return 'expense';
    }
  }

  static TransactionCategory fromValue(String value) {
    switch (value) {
      case 'income':
        return TransactionCategory.income;
      case 'expense':
        return TransactionCategory.expense;
      default:
        return TransactionCategory.expense;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.income:
        return Colors.green;
      case TransactionCategory.expense:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionCategory.income:
        return Icons.arrow_upward;
      case TransactionCategory.expense:
        return Icons.arrow_downward;
    }
  }
}

// Liste des sous-catégories communes pour les entrées et sorties
class TransactionSubcategories {
  // Sous-catégories pour les entrées
  static final List<String> income = [
    'Vente',
    'Paiement client',
    'Investissement',
    'Subvention',
    'Remboursement',
    'Autre',
  ];

  // Sous-catégories pour les dépenses
  static final List<String> expense = [
    'Matériel',
    'Service',
    'Personnel',
    'Location',
    'Transport',
    'Marketing',
    'Logiciel',
    'Formation',
    'Maintenance',
    'Autre',
  ];

  // Obtenir la liste correspondant à la catégorie
  static List<String> getForCategory(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.income:
        return income;
      case TransactionCategory.expense:
        return expense;
    }
  }
}
