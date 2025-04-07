import 'package:flutter/material.dart';

enum NotificationType {
  projectCreated,
  projectStatusChanged,
  projectBudgetAlert,
  phaseCreated,
  phaseStatusChanged,
  taskAssigned,
  taskDueSoon,
  taskOverdue,
  taskStatusChanged,
  projectInvitation,
  newUser,
  projectAddedToTeam,
}

class Notification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationType type;
  final String? relatedId; // ID du projet, de la tâche ou de la phase liée
  final String? userId; // ID de l'utilisateur destinataire
  
  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    this.relatedId,
    this.userId,
  });
  
  // Convertir un objet JSON en objet Notification
  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.taskAssigned,
      ),
      relatedId: json['related_id'] as String?,
      userId: json['user_id'] as String?,
    );
  }
  
  // Convertir un objet Notification en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'type': type.toString().split('.').last,
      'related_id': relatedId,
      'user_id': userId,
    };
  }
  
  // Créer une copie de l'objet Notification avec des valeurs modifiées
  Notification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    NotificationType? type,
    String? relatedId,
    String? userId,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      userId: userId ?? this.userId,
    );
  }
  
  // Retourner l'icône correspondant au type de notification
  IconData getIcon() {
    switch (type) {
      case NotificationType.projectCreated:
      case NotificationType.projectStatusChanged:
      case NotificationType.projectInvitation:
      case NotificationType.projectAddedToTeam:
        return Icons.folder;
      case NotificationType.projectBudgetAlert:
        return Icons.attach_money;
      case NotificationType.phaseCreated:
      case NotificationType.phaseStatusChanged:
        return Icons.layers;
      case NotificationType.taskAssigned:
      case NotificationType.taskDueSoon:
      case NotificationType.taskOverdue:
      case NotificationType.taskStatusChanged:
        return Icons.task_alt;
      case NotificationType.newUser:
        return Icons.person_add;
    }
  }
  
  // Retourner la couleur correspondant au type de notification
  Color getColor() {
    switch (type) {
      case NotificationType.projectCreated:
        return Colors.blue;
      case NotificationType.projectStatusChanged:
        return Colors.amber;
      case NotificationType.projectBudgetAlert:
        return Colors.orange;
      case NotificationType.projectAddedToTeam:
        return Colors.lightBlue;
      case NotificationType.phaseCreated:
        return Colors.cyan;
      case NotificationType.phaseStatusChanged:
        return Colors.teal;
      case NotificationType.taskAssigned:
        return Colors.indigo;
      case NotificationType.taskDueSoon:
        return Colors.amber;
      case NotificationType.taskOverdue:
        return Colors.red;
      case NotificationType.taskStatusChanged:
        return Colors.green;
      case NotificationType.projectInvitation:
        return Colors.purple;
      case NotificationType.newUser:
        return Colors.brown;
    }
  }
}
