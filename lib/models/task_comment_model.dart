import 'package:flutter/material.dart';

class TaskComment {
  final String id;
  final String taskId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    return TaskComment(
      id: json['id'],
      taskId: json['task_id'],
      userId: json['user_id'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  TaskComment copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskComment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Color getColor() {
    return Colors.blue;
  }

  IconData getIcon() {
    return Icons.comment;
  }
}
