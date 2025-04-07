import 'package:flutter/material.dart';

/// Classe pour les données de répartition des tâches par statut ou priorité
class TaskDistributionData {
  final String label;
  final int count;
  final Color color;

  TaskDistributionData({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Classe pour les données de progression des projets
class ProjectProgressData {
  final String projectName;
  final String projectId;
  final double progressPercentage;
  final double budgetUsagePercentage;
  final double plannedBudgetUsagePercentage; 
  final double budgetAmount; 
  final double plannedBudgetAmount; 
  final double usedBudgetAmount; 
  final Color progressColor;

  ProjectProgressData({
    required this.projectName,
    required this.projectId,
    required this.progressPercentage,
    required this.budgetUsagePercentage,
    required this.plannedBudgetUsagePercentage,
    required this.budgetAmount,
    required this.plannedBudgetAmount,
    required this.usedBudgetAmount,
    required this.progressColor,
  });
}

/// Classe pour les données de timeline des tâches
class TaskTimelineData {
  final String taskId;
  final String taskTitle;
  final DateTime dueDate;
  final int priority;
  final String status;

  TaskTimelineData({
    required this.taskId,
    required this.taskTitle,
    required this.dueDate,
    required this.priority,
    required this.status,
  });
}

/// Classe pour les données budgétaires
class BudgetOverviewData {
  final String projectName;
  final String projectId;
  final double allocatedBudget;
  final double usedBudget;
  final Color color;

  BudgetOverviewData({
    required this.projectName,
    required this.projectId,
    required this.allocatedBudget,
    required this.usedBudget,
    required this.color,
  });
}

/// Classe pour les transactions récentes
class RecentTransactionData {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final bool isIncome;

  RecentTransactionData({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.isIncome,
  });
}

/// Classe pour les données de phases de projet
class PhaseProgressData {
  final String phaseId;
  final String phaseName;
  final String projectId;
  final String projectName;
  final double progressPercentage;
  final String status;
  final Color statusColor;
  final double? budgetAllocated;
  final double? budgetConsumed;
  final double? budgetUsagePercentage;
  final Color? budgetStatusColor;

  PhaseProgressData({
    required this.phaseId,
    required this.phaseName,
    required this.projectId,
    required this.projectName,
    required this.progressPercentage,
    required this.status,
    required this.statusColor,
    this.budgetAllocated,
    this.budgetConsumed,
    this.budgetUsagePercentage,
    this.budgetStatusColor,
  });
}
