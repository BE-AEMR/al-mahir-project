/// Modèle représentant un profil utilisateur
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;

  UserProfile({
    required this.id,
    this.email,
    this.displayName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
    };
  }
  
  /// Retourne le nom à afficher pour l'utilisateur, ou son email si le nom n'est pas disponible
  String getDisplayName() {
    return displayName ?? email ?? id;
  }
}
