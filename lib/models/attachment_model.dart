import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum AttachmentType {
  image,
  document,
  other
}

class Attachment {
  final String id;
  final String taskId;
  final String name;
  final String url;
  final String path;
  final String uploadedBy;
  final DateTime createdAt;
  final AttachmentType type;

  Attachment({
    required this.id,
    required this.taskId,
    required this.name,
    required this.url,
    required this.path,
    required this.uploadedBy,
    required this.createdAt,
    required this.type,
  });

  // Convertir un objet JSON en objet Attachment
  factory Attachment.fromJson(Map<String, dynamic> json) {
    // Détecter le type d'après l'extension du fichier
    final fileExtension = p.extension(json['name'] as String).toLowerCase();
    final type = _getTypeFromExtension(fileExtension);

    return Attachment(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      path: json['path'] as String,
      uploadedBy: json['uploaded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      type: type,
    );
  }

  // Convertir un objet Attachment en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'name': name,
      'url': url,
      'path': path,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Déterminer le type d'attachement en fonction de l'extension du fichier
  static AttachmentType _getTypeFromExtension(String extension) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'];
    final documentExtensions = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'];

    if (imageExtensions.contains(extension)) {
      return AttachmentType.image;
    } else if (documentExtensions.contains(extension)) {
      return AttachmentType.document;
    } else {
      return AttachmentType.other;
    }
  }

  // Obtenir l'icône appropriée pour ce type de pièce jointe
  IconData getIcon() {
    switch (type) {
      case AttachmentType.image:
        return Icons.image;
      case AttachmentType.document:
        return Icons.description;
      case AttachmentType.other:
        return Icons.attach_file;
    }
  }

  // Obtenir la couleur associée à ce type de pièce jointe
  Color getColor() {
    switch (type) {
      case AttachmentType.image:
        return Colors.blue;
      case AttachmentType.document:
        return Colors.orange;
      case AttachmentType.other:
        return Colors.grey;
    }
  }
}
