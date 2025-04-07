import 'package:flutter/material.dart';

class ProjectTransaction {
  final String id;
  final String projectId;
  final String projectName;  
  final String? phaseId;
  final String? phaseName;    
  final String? taskId;
  final String? taskName;     
  final double amount;
  final String description;
  final String? notes; 
  final DateTime transactionDate;
  final String transactionType; 
  final String category; 
  final String? subcategory;
  final String? categoryId;
  final String? subcategoryId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  ProjectTransaction({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.phaseId,
    this.phaseName,
    this.taskId,
    this.taskName,
    required this.amount,
    required this.description,
    this.notes, 
    required this.transactionDate,
    required this.transactionType,
    required this.category,
    this.subcategory,
    this.categoryId,
    this.subcategoryId,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convertir un objet JSON en objet ProjectTransaction
  factory ProjectTransaction.fromJson(Map<String, dynamic> json) {
    return ProjectTransaction(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      projectName: json['project_name'] as String? ?? 'Projet non spécifié',
      phaseId: json['phase_id'] as String?,
      phaseName: json['phase_name'] as String?,
      taskId: json['task_id'] as String?,
      taskName: json['task_name'] as String?,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      notes: json['notes'] as String?, 
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      transactionType: json['transaction_type'] as String, 
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      categoryId: json['category_id'] as String?,
      subcategoryId: json['subcategory_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }

  // Convertir un objet ProjectTransaction en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'project_name': projectName,
      'phase_id': phaseId,
      'phase_name': phaseName,
      'task_id': taskId,
      'task_name': taskName,
      'amount': amount,
      'description': description,
      'notes': notes, 
      'transaction_date': transactionDate.toIso8601String(),
      'transaction_type': transactionType, 
      'category': category,
      'subcategory': subcategory,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Créer une copie de l'objet ProjectTransaction avec des valeurs modifiées
  ProjectTransaction copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? phaseId,
    String? phaseName,
    String? taskId,
    String? taskName,
    double? amount,
    String? description,
    String? notes, 
    DateTime? transactionDate,
    String? transactionType, 
    String? category,
    String? subcategory,
    String? categoryId,
    String? subcategoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ProjectTransaction(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      phaseId: phaseId ?? this.phaseId,
      phaseName: phaseName ?? this.phaseName,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      notes: notes ?? this.notes, 
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType, 
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Vérifier si c'est une entrée d'argent
  bool get isIncome {
    return transactionType == 'income'; 
  }

  // Vérifier si c'est une sortie d'argent
  bool get isExpense {
    return transactionType == 'expense'; 
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
  
  // Crée une ProjectTransaction à partir d'une BudgetTransaction
  static ProjectTransaction fromBudgetTransaction(Map<String, dynamic> json) {
    return ProjectTransaction(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? 'Projet non spécifié',
      phaseId: json['phase_id'] as String?,
      phaseName: json['phase_name'] as String?,
      taskId: json['task_id'] as String?,
      taskName: json['task_name'] as String?,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      notes: json['notes'] as String?, 
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      transactionType: json['transaction_type'] as String, 
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      categoryId: json['category_id'] as String?,
      subcategoryId: json['subcategory_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }
}

// Énumération pour les types de transactions
enum TransactionType { 
  income,
  expense;

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Entrée';
      case TransactionType.expense:
        return 'Sortie';
    }
  }

  String toValue() {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
    }
  }

  static TransactionType fromValue(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      default:
        return TransactionType.expense;
    }
  }

  Color get color {
    switch (this) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.income:
        return Icons.arrow_upward;
      case TransactionType.expense:
        return Icons.arrow_downward;
    }
  }
}
