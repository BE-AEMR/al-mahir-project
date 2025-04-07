import 'package:flutter/foundation.dart';
import 'dart:convert';

class Team {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;

  Team({
    this.id = '',  
    required this.name,
    this.description,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      createdBy: json['created_by'],
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
    
    // N'ajouter l'ID que s'il n'est pas vide
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    
    // N'ajouter updatedAt que s'il n'est pas null
    if (updatedAt != null) {
      data['updated_at'] = updatedAt!.toIso8601String();
    }
    
    return data;
  }

  Team copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Team && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum TeamMemberRole {
  admin,
  member,
  guest;

  String get displayName {
    switch (this) {
      case TeamMemberRole.admin:
        return 'Administrateur';
      case TeamMemberRole.member:
        return 'Membre';
      case TeamMemberRole.guest:
        return 'Invité';
    }
  }

  static TeamMemberRole fromString(String value) {
    switch (value) {
      case 'admin':
        return TeamMemberRole.admin;
      case 'member':
        return TeamMemberRole.member;
      case 'guest':
        return TeamMemberRole.guest;
      default:
        return TeamMemberRole.guest;
    }
  }

  String toValue() {
    return toString().split('.').last;
  }
}

enum TeamMemberStatus {
  invited,
  active,
  inactive;

  String get displayName {
    switch (this) {
      case TeamMemberStatus.invited:
        return 'Invité';
      case TeamMemberStatus.active:
        return 'Actif';
      case TeamMemberStatus.inactive:
        return 'Inactif';
    }
  }

  static TeamMemberStatus fromString(String value) {
    switch (value) {
      case 'invited':
        return TeamMemberStatus.invited;
      case 'active':
        return TeamMemberStatus.active;
      case 'inactive':
        return TeamMemberStatus.inactive;
      default:
        return TeamMemberStatus.invited;
    }
  }

  String toValue() {
    return toString().split('.').last;
  }
}

class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final TeamMemberRole role;
  final DateTime joinedAt;
  final String? invitedBy;
  final TeamMemberStatus status;
  final String? userEmail;
  final String? userName;

  TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    required this.status,
    this.userEmail,
    this.userName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'],
      teamId: json['team_id'],
      userId: json['user_id'],
      role: TeamMemberRole.fromString(json['role']),
      joinedAt: DateTime.parse(json['joined_at']),
      invitedBy: json['invited_by'],
      status: TeamMemberStatus.fromString(json['status']),
      userEmail: json['user_email'],
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'team_id': teamId,
      'user_id': userId,
      'role': role.toValue(),
      'joined_at': joinedAt.toIso8601String(),
      'status': status.toValue(),
    };

    if (invitedBy != null) {
      data['invited_by'] = invitedBy;
    }

    return data;
  }

  TeamMember copyWith({
    String? id,
    String? teamId,
    String? userId,
    TeamMemberRole? role,
    DateTime? joinedAt,
    String? invitedBy,
    TeamMemberStatus? status,
    String? userEmail,
    String? userName,
  }) {
    return TeamMember(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      status: status ?? this.status,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamMember && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum InvitationStatus {
  pending,
  accepted,
  rejected,
  expired;

  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'En attente';
      case InvitationStatus.accepted:
        return 'Acceptée';
      case InvitationStatus.rejected:
        return 'Rejetée';
      case InvitationStatus.expired:
        return 'Expirée';
    }
  }

  static InvitationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'rejected':
        return InvitationStatus.rejected;
      case 'expired':
        return InvitationStatus.expired;
      default:
        return InvitationStatus.pending;
    }
  }

  String toValue() {
    return toString().split('.').last;
  }
}

class Invitation {
  final String id;
  final String email;
  final String teamId;
  final String invitedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String token;
  final InvitationStatus status;
  final String? teamName;
  final Map<String, dynamic>? metadata;

  Invitation({
    this.id = '',
    required this.email,
    required this.teamId,
    required this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    this.token = '',
    this.status = InvitationStatus.pending,
    this.teamName,
    this.metadata,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      teamId: json['team_id'] ?? '',
      invitedBy: json['invited_by'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(json['expires_at'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String()),
      token: json['token'] ?? '',
      status: InvitationStatus.fromString(json['status'] ?? 'pending'),
      teamName: json['team_name'],
      metadata: json['metadata'] is String && json['metadata'] != '' 
          ? jsonDecode(json['metadata']) 
          : (json['metadata'] is Map ? json['metadata'] : null),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
      'team_id': teamId,
      'invited_by': invitedBy,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'token': token,
      'status': status.toValue(),
    };
    
    // N'ajouter l'ID que s'il n'est pas vide
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    
    // Ajouter les métadonnées si elles existent
    if (metadata != null) {
      data['metadata'] = jsonEncode(metadata);
    }
    
    return data;
  }

  Invitation copyWith({
    String? id,
    String? email,
    String? teamId,
    String? invitedBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? token,
    InvitationStatus? status,
    String? teamName,
    Map<String, dynamic>? metadata,
  }) {
    return Invitation(
      id: id ?? this.id,
      email: email ?? this.email,
      teamId: teamId ?? this.teamId,
      invitedBy: invitedBy ?? this.invitedBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      token: token ?? this.token,
      status: status ?? this.status,
      teamName: teamName ?? this.teamName,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
