import 'package:flutter/material.dart';

class BudgetAllocation {
  final String id;
  final String budgetId;
  final String projectId;
  final double amount;
  final String description;
  final DateTime allocationDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  BudgetAllocation({
    required this.id,
    required this.budgetId,
    required this.projectId,
    required this.amount,
    required this.description,
    required this.allocationDate,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convertir un objet JSON en objet BudgetAllocation
  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      id: json['id'] as String,
      budgetId: json['budget_id'] as String,
      projectId: json['project_id'] as String,
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      description: json['description'] as String,
      allocationDate: DateTime.parse(json['allocation_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }

  // Convertir un objet BudgetAllocation en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'budget_id': budgetId,
      'project_id': projectId,
      'amount': amount,
      'description': description,
      'allocation_date': allocationDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Créer une copie de l'objet BudgetAllocation avec des valeurs modifiées
  BudgetAllocation copyWith({
    String? id,
    String? budgetId,
    String? projectId,
    double? amount,
    String? description,
    DateTime? allocationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return BudgetAllocation(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      projectId: projectId ?? this.projectId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      allocationDate: allocationDate ?? this.allocationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
