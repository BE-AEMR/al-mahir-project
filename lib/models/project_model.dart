import 'package:flutter/material.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String status;
  final double? budgetAllocated;
  final double? budgetConsumed;
  final double? plannedBudget;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.status,
    this.budgetAllocated = 0,
    this.budgetConsumed = 0,
    this.plannedBudget = 0,
  });

  // Convertir un objet JSON en objet Project
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String,
      status: json['status'] as String,
      budgetAllocated: json['budget_allocated'] != null
          ? (json['budget_allocated'] is int 
              ? (json['budget_allocated'] as int).toDouble()
              : json['budget_allocated'] as double)
          : 0,
      budgetConsumed: json['budget_consumed'] != null
          ? (json['budget_consumed'] is int 
              ? (json['budget_consumed'] as int).toDouble()
              : json['budget_consumed'] as double)
          : 0,
      plannedBudget: json['planned_budget'] != null
          ? (json['planned_budget'] is int 
              ? (json['planned_budget'] as int).toDouble()
              : json['planned_budget'] as double)
          : 0,
    );
  }

  // Convertir un objet Project en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'status': status,
      'budget_allocated': budgetAllocated,
      'budget_consumed': budgetConsumed,
      'planned_budget': plannedBudget,
    };
  }

  // Créer une copie de l'objet Project avec des valeurs modifiées
  Project copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? status,
    double? budgetAllocated,
    double? budgetConsumed,
    double? plannedBudget,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      budgetAllocated: budgetAllocated ?? this.budgetAllocated,
      budgetConsumed: budgetConsumed ?? this.budgetConsumed,
      plannedBudget: plannedBudget ?? this.plannedBudget,
    );
  }

  // Calculer le budget restant
  double? get budgetRemaining {
    if (budgetAllocated == null || budgetConsumed == null) return null;
    return budgetAllocated! - budgetConsumed!;
  }

  // Calculer le pourcentage de budget utilisé
  double get budgetUsagePercentage {
    if (budgetAllocated == null || budgetAllocated == 0 || budgetConsumed == null) return 0;
    final percentage = (budgetConsumed! / budgetAllocated!) * 100;
    return percentage.clamp(0, 100);
  }

  // Vérifier si le budget est dépassé
  bool get isBudgetOverrun {
    if (budgetAllocated == null || budgetConsumed == null) return false;
    return budgetConsumed! > budgetAllocated!;
  }

  // Obtenir une couleur en fonction de l'état du budget
  Color getBudgetStatusColor() {
    if (budgetAllocated == null || budgetConsumed == null) return Colors.grey;
    
    final percentage = budgetUsagePercentage;
    if (percentage < 70) {
      return Colors.green;
    } else if (percentage < 90) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

// Énumération pour les statuts de projet
enum ProjectStatus {
  active,
  completed,
  onHold,
  cancelled;

  String get displayName {
    switch (this) {
      case ProjectStatus.active:
        return 'Actif';
      case ProjectStatus.completed:
        return 'Terminé';
      case ProjectStatus.onHold:
        return 'En attente';
      case ProjectStatus.cancelled:
        return 'Annulé';
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.completed:
        return Colors.blue;
      case ProjectStatus.onHold:
        return Colors.orange;
      case ProjectStatus.cancelled:
        return Colors.red;
    }
  }
}
