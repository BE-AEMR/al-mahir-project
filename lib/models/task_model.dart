import 'package:flutter/material.dart';

class Task {
  final String id;
  final String projectId;
  final String? phaseId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? dueDate;
  final String? assignedTo;
  final String createdBy;
  final String status;
  final int priority;
  final double? budgetAllocated;
  final double? budgetConsumed;

  Task({
    required this.id,
    required this.projectId,
    this.phaseId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.updatedAt,
    this.dueDate,
    this.assignedTo,
    required this.createdBy,
    required this.status,
    required this.priority,
    this.budgetAllocated = 0,
    this.budgetConsumed = 0,
  });

  // Convertir un objet JSON en objet Task
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      phaseId: json['phase_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'] as String) 
          : null,
      assignedTo: json['assigned_to'] as String?,
      createdBy: json['created_by'] as String,
      status: json['status'] as String,
      priority: json['priority'] as int,
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
    );
  }

  // Convertir un objet Task en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'phase_id': phaseId,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'status': status,
      'priority': priority,
      'budget_allocated': budgetAllocated,
      'budget_consumed': budgetConsumed,
    };
  }

  // Créer une copie de l'objet Task avec des valeurs modifiées
  Task copyWith({
    String? id,
    String? projectId,
    String? phaseId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    String? assignedTo,
    String? createdBy,
    String? status,
    int? priority,
    double? budgetAllocated,
    double? budgetConsumed,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      phaseId: phaseId ?? this.phaseId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      budgetAllocated: budgetAllocated ?? this.budgetAllocated,
      budgetConsumed: budgetConsumed ?? this.budgetConsumed,
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

// Énumération pour les statuts de tâche
enum TaskStatus {
  todo,
  inProgress,
  review,
  completed;
  //onHold,
  //cancelled;

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'À faire';
      case TaskStatus.inProgress:
        return 'En cours';
      case TaskStatus.review:
        return 'En révision';
      case TaskStatus.completed:
        return 'Terminée';
      //case TaskStatus.onHold:
      //  return 'En attente';
      //case TaskStatus.cancelled:
      //  return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.review:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      //case TaskStatus.onHold:
      //  return Colors.amber;
      //case TaskStatus.cancelled:
      //  return Colors.red;
    }
  }
  
  // Méthodes pour la compatibilité avec le code existant
  String toValue() {
    switch (this) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.review:
        return 'review';
      case TaskStatus.completed:
        return 'completed';
      //case TaskStatus.onHold:
      //  return 'on_hold';
      //case TaskStatus.cancelled:
      //  return 'cancelled';
    }
  }
  
  Color getColor() {
    return color;
  }
  
  String getText() {
    return displayName;
  }
  
  static TaskStatus fromValue(String value) {
    switch (value) {
      case 'todo':
        return TaskStatus.todo;
      case 'in_progress':
      case 'inProgress':  
        return TaskStatus.inProgress;
      case 'review':
        return TaskStatus.review;
      case 'completed':
        return TaskStatus.completed;
      //case 'on_hold':
      //case 'onHold':  
      //  return TaskStatus.onHold;
      //case 'cancelled':
      //  return TaskStatus.cancelled;
      default:
        return TaskStatus.todo;
    }
  }
}

// Énumération pour les priorités de tâche
enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Basse';
      case TaskPriority.medium:
        return 'Moyenne';
      case TaskPriority.high:
        return 'Haute';
      case TaskPriority.urgent:
        return 'Urgente';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }

  int get value {
    switch (this) {
      case TaskPriority.low:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.high:
        return 2;
      case TaskPriority.urgent:
        return 3;
    }
  }
  
  // Méthodes pour la compatibilité avec le code existant
  Color getColor() {
    return color;
  }
  
  String getText() {
    return displayName;
  }

  static TaskPriority fromValue(int value) {
    switch (value) {
      case 0:
        return TaskPriority.low;
      case 1:
        return TaskPriority.medium;
      case 2:
        return TaskPriority.high;
      case 3:
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }
}
