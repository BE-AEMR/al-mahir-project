import 'package:flutter/material.dart';

class Phase {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final int orderIndex;
  final String status;
  final double? budgetAllocated;
  final double? budgetConsumed;
  final String? projectName;

  Phase({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.orderIndex,
    required this.status,
    this.budgetAllocated = 0,
    this.budgetConsumed = 0,
    this.projectName,
  });

  // Convertir un objet JSON en objet Phase
  factory Phase.fromJson(Map<String, dynamic> json) {
    return Phase(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String,
      orderIndex: json['order_index'] as int,
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
      projectName: json['project_name'] != null ? json['project_name'] as String : null,
    );
  }

  // Convertir un objet Phase en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'order_index': orderIndex,
      'status': status,
      'budget_allocated': budgetAllocated,
      'budget_consumed': budgetConsumed,
      // 'project_name' est supprimé car il n'existe pas dans la table de la base de données
    };
  }

  // Créer une copie de l'objet avec des modifications
  Phase copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? orderIndex,
    String? status,
    double? budgetAllocated,
    double? budgetConsumed,
    String? projectName,
  }) {
    return Phase(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      budgetAllocated: budgetAllocated ?? this.budgetAllocated,
      budgetConsumed: budgetConsumed ?? this.budgetConsumed,
      projectName: projectName ?? this.projectName,
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

// Énumération pour les statuts de phase
enum PhaseStatus {
  notStarted,
  inProgress,
  completed,
  onHold,
  cancelled;

  // Convertir l'énumération en chaîne de caractères
  String toValue() {
    switch (this) {
      case PhaseStatus.notStarted:
        return 'not_started';
      case PhaseStatus.inProgress:
        return 'in_progress';
      case PhaseStatus.completed:
        return 'completed';
      case PhaseStatus.onHold:
        return 'on_hold';
      case PhaseStatus.cancelled:
        return 'cancelled';
    }
  }

  // Convertir une chaîne de caractères en énumération
  static PhaseStatus fromValue(String value) {
    switch (value) {
      case 'not_started':
        return PhaseStatus.notStarted;
      case 'in_progress':
        return PhaseStatus.inProgress;
      case 'completed':
        return PhaseStatus.completed;
      case 'on_hold':
        return PhaseStatus.onHold;
      case 'cancelled':
        return PhaseStatus.cancelled;
      default:
        return PhaseStatus.notStarted;
    }
  }

  // Obtenir la couleur associée au statut
  Color getColor() {
    switch (this) {
      case PhaseStatus.notStarted:
        return Colors.grey;
      case PhaseStatus.inProgress:
        return Colors.blue;
      case PhaseStatus.completed:
        return Colors.green;
      case PhaseStatus.onHold:
        return Colors.orange;
      case PhaseStatus.cancelled:
        return Colors.red;
    }
  }

  // Obtenir le texte associé au statut
  String getText() {
    switch (this) {
      case PhaseStatus.notStarted:
        return 'Non démarré';
      case PhaseStatus.inProgress:
        return 'En cours';
      case PhaseStatus.completed:
        return 'Terminé';
      case PhaseStatus.onHold:
        return 'En attente';
      case PhaseStatus.cancelled:
        return 'Annulé';
    }
  }
}
