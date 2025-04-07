/// Modèle représentant une permission dans le système RBAC
class Permission {
  final String id;
  final String name;
  final String? description;
  final String resourceType; // 'project', 'phase', 'task', 'finance', etc.
  final String action; // 'create', 'read', 'update', 'delete', etc.
  final DateTime? createdAt;

  Permission({
    required this.id,
    required this.name,
    this.description,
    required this.resourceType,
    required this.action,
    this.createdAt,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      resourceType: json['resource_type'],
      action: json['action'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'resource_type': resourceType,
      'action': action,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return name;
  }

  // Méthode pour obtenir un nom lisible et traduit de la permission
  String getDisplayName() {
    switch (name) {
      case 'create_project':
        return 'Créer un projet';
      case 'read_project':
        return 'Voir un projet';
      case 'update_project':
        return 'Modifier un projet';
      case 'delete_project':
        return 'Supprimer un projet';
      case 'create_phase':
        return 'Créer une phase';
      case 'read_phase':
        return 'Voir une phase';
      case 'update_phase':
        return 'Modifier une phase';
      case 'delete_phase':
        return 'Supprimer une phase';
      case 'create_task':
        return 'Créer une tâche';
      case 'read_task':
        return 'Voir une tâche';
      case 'update_task':
        return 'Modifier une tâche';
      case 'assign_task':
        return 'Assigner une tâche';
      case 'delete_task':
        return 'Supprimer une tâche';
      case 'create_transaction':
        return 'Créer une transaction';
      case 'read_transaction':
        return 'Voir une transaction';
      case 'update_transaction':
        return 'Modifier une transaction';
      case 'delete_transaction':
        return 'Supprimer une transaction';
      case 'manage_budget':
        return 'Gérer les budgets';
      default:
        return name.replaceAll('_', ' ');
    }
  }
}
