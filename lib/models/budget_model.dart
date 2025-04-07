import 'package:flutter/material.dart';

class Budget {
  final String id;
  final String name;
  final String description;
  final double initialAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  Budget({
    required this.id,
    required this.name,
    required this.description,
    required this.initialAmount,
    required this.currentAmount,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convertir un objet JSON en objet Budget
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      initialAmount: json['initial_amount'] is int
          ? (json['initial_amount'] as int).toDouble()
          : json['initial_amount'] as double,
      currentAmount: json['current_amount'] is int
          ? (json['current_amount'] as int).toDouble()
          : json['current_amount'] as double,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
    );
  }

  // Convertir un objet Budget en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'initial_amount': initialAmount,
      'current_amount': currentAmount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  // Créer une copie de l'objet Budget avec des valeurs modifiées
  Budget copyWith({
    String? id,
    String? name,
    String? description,
    double? initialAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      initialAmount: initialAmount ?? this.initialAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Calculer le pourcentage de budget utilisé
  double get usagePercentage {
    if (initialAmount <= 0) return 0;
    // Calculer combien reste par rapport à l'initial
    final remainingPercentage = (currentAmount / initialAmount) * 100;
    // Limiter le résultat entre 0 et 100
    return remainingPercentage.clamp(0, 100);
  }

  // Calculer le pourcentage de budget restant
  double get remainingPercentage {
    return 100 - usagePercentage;
  }

  // Obtenir la couleur en fonction du budget restant
  Color getStatusColor() {
    if (remainingPercentage >= 50) {
      return Colors.green;
    } else if (remainingPercentage >= 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Vérifier si le budget est dépassé
  bool get isOverBudget {
    return currentAmount < 0;
  }

  // Obtenir le montant dépensé
  double get spentAmount {
    return initialAmount - currentAmount;
  }
}
