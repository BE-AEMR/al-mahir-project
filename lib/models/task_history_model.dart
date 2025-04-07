import 'package:flutter/material.dart';
import 'task_model.dart';

class TaskHistory {
  final String id;
  final String taskId;
  final String userId;
  final String fieldName;
  final String? oldValue;
  final String newValue;
  final DateTime createdAt;

  TaskHistory({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.fieldName,
    this.oldValue,
    required this.newValue,
    required this.createdAt,
  });

  // Convertir un objet JSON en objet TaskHistory
  factory TaskHistory.fromJson(Map<String, dynamic> json) {
    return TaskHistory(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      userId: json['user_id'] as String,
      fieldName: json['field_name'] as String,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convertir un objet TaskHistory en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Obtenir une description lisible du changement
  String getDescription() {
    switch (fieldName) {
      case 'status':
        final oldStatus = oldValue != null ? TaskStatus.fromValue(oldValue!).displayName : null;
        final newStatus = TaskStatus.fromValue(newValue).displayName;
        if (oldStatus != null) {
          return 'Changement de statut de "$oldStatus" à "$newStatus"';
        } else {
          return 'Statut défini à "$newStatus"';
        }
      case 'priority':
        final oldPriority = oldValue != null 
            ? TaskPriority.fromValue(int.parse(oldValue!)).displayName 
            : null;
        final newPriority = TaskPriority.fromValue(int.parse(newValue)).displayName;
        if (oldPriority != null) {
          return 'Changement de priorité de "$oldPriority" à "$newPriority"';
        } else {
          return 'Priorité définie à "$newPriority"';
        }
      case 'assigned_to':
        if (oldValue == null && newValue.isNotEmpty) {
          return 'Assignée à un utilisateur';
        } else if (oldValue != null && newValue.isEmpty) {
          return 'Désassignée de l\'utilisateur';
        } else {
          return 'Réassignée à un autre utilisateur';
        }
      case 'title':
        return 'Titre modifié';
      case 'description':
        return 'Description modifiée';
      case 'due_date':
        if (oldValue == null) {
          return 'Date d\'échéance ajoutée';
        } else if (newValue.isEmpty) {
          return 'Date d\'échéance supprimée';
        } else {
          return 'Date d\'échéance modifiée';
        }
      default:
        return 'Modification de $fieldName';
    }
  }

  // Obtenir une icône appropriée pour le type de changement
  IconData getIcon() {
    switch (fieldName) {
      case 'status':
        return Icons.playlist_add_check;
      case 'priority':
        return Icons.flag;
      case 'assigned_to':
        return Icons.person;
      case 'title':
        return Icons.title;
      case 'description':
        return Icons.description;
      case 'due_date':
        return Icons.event;
      default:
        return Icons.edit;
    }
  }
  
  // Obtenir une couleur appropriée pour le type de changement
  Color getColor() {
    switch (fieldName) {
      case 'status':
        // Si changement vers "terminé", vert
        if (newValue == 'completed') {
          return Colors.green;
        }
        // Si changement vers "en attente" ou "annulé", orange/rouge
        else if (newValue == 'on_hold' || newValue == 'cancelled') {
          return Colors.orange;
        }
        // Sinon, bleu pour les autres changements de statut
        return Colors.blue;
      case 'priority':
        // Rouge pour priorité urgente/haute
        if (newValue == '3' || newValue == '2') {
          return Colors.red;
        }
        // Vert pour priorité basse
        else if (newValue == '0') {
          return Colors.green;
        }
        // Orange pour priorité moyenne
        return Colors.orange;
      case 'assigned_to':
        return Colors.purple;
      case 'due_date':
        return Colors.teal;
      default:
        return Colors.grey.shade700;
    }
  }
}
