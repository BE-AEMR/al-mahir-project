import 'role.dart';
import 'team_model.dart';
import 'project_model.dart';
import 'user_profile.dart';

/// Modèle représentant l'attribution d'un rôle à un utilisateur dans le système RBAC
class UserRole {
  final String id;
  final String userId;
  final String roleId;
  final Role? role;
  final String? teamId;
  final Team? team;
  final String? projectId;
  final Project? project;
  final DateTime? createdAt;
  final String? createdBy;
  final UserProfile? userProfile;
  final List<dynamic>? associatedProjects;

  UserRole({
    required this.id,
    required this.userId,
    required this.roleId,
    this.role,
    this.teamId,
    this.team,
    this.projectId,
    this.project,
    this.createdAt,
    this.createdBy,
    this.userProfile,
    this.associatedProjects,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'],
      userId: json['user_id'],
      roleId: json['role_id'],
      role: json['roles'] != null ? Role.fromJson(json['roles']) : null,
      teamId: json['team_id'],
      team: json['teams'] != null ? Team.fromJson(json['teams']) : null,
      projectId: json['project_id'],
      project: json['projects'] != null ? Project.fromJson(json['projects']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      createdBy: json['created_by'],
      userProfile: json['profiles'] != null ? UserProfile.fromJson(json['profiles']) : null,
      associatedProjects: json['associated_projects'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role_id': roleId,
      'team_id': teamId,
      'project_id': projectId,
      'created_at': createdAt?.toIso8601String(),
      'created_by': createdBy,
      'associated_projects': associatedProjects,
    };
  }

  /// Détermine si ce rôle est global (non lié à un projet ou une équipe spécifique)
  bool get isGlobal => teamId == null && projectId == null;

  /// Détermine si ce rôle est spécifique à une équipe
  bool get isTeamSpecific => teamId != null && projectId == null;

  /// Détermine si ce rôle est spécifique à un projet
  bool get isProjectSpecific => projectId != null && teamId == null;

  /// Détermine si ce rôle est spécifique à un projet dans une équipe
  bool get isTeamProjectSpecific => teamId != null && projectId != null;

  /// Retourne une description du contexte d'application de ce rôle
  String getContextDescription() {
    if (isGlobal) {
      return "Rôle global";
    } else if (isTeamSpecific && team != null) {
      return "Équipe: ${team!.name}";
    } else if (isProjectSpecific && project != null) {
      return "Projet: ${project!.name}";
    } else if (isTeamProjectSpecific && team != null && project != null) {
      return "Équipe: ${team!.name} / Projet: ${project!.name}";
    } else {
      return "Contexte inconnu";
    }
  }

  /// Retourne une description formatée de la date de création
  String getFormattedCreationDate() {
    if (createdAt == null) return 'Date inconnue';
    
    // Formater la date comme "jour/mois/année heure:minute"
    final day = createdAt!.day.toString().padLeft(2, '0');
    final month = createdAt!.month.toString().padLeft(2, '0');
    final year = createdAt!.year;
    final hour = createdAt!.hour.toString().padLeft(2, '0');
    final minute = createdAt!.minute.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute';
  }
}
