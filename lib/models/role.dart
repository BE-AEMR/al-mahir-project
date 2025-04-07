/// Modèle représentant un rôle dans le système RBAC
class Role {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  Role({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      description: json['description'],
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
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return name;
  }

  // Méthode pour obtenir un nom lisible et traduit du rôle
  String getDisplayName() {
    switch (name) {
      case 'system_admin':
        return 'Administrateur système';
      case 'project_manager':
        return 'Chef de projet';
      case 'team_member':
        return 'Membre d\'équipe';
      case 'finance_manager':
        return 'Responsable financier';
      case 'observer':
        return 'Observateur';
      default:
        return name;
    }
  }
}
