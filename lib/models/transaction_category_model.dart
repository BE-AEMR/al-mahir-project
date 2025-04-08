import 'package:flutter/material.dart';

class TransactionCategory {
  final String id;
  final String name;
  final String transactionType; // 'income' ou 'expense'
  final String? description;
  final String? icon;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionCategory({
    required this.id,
    required this.name,
    required this.transactionType,
    this.description,
    this.icon,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'],
      name: json['name'],
      transactionType: json['transaction_type'],
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'transaction_type': transactionType,
      'description': description,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Méthode pour obtenir l'icône (si spécifiée ou une icône par défaut)
  IconData getIcon() {
    // Si une icône est spécifiée, essayer de la trouver dans la liste des icônes de Material
    if (icon != null && icon!.isNotEmpty) {
      try {
        // Au lieu de créer une IconData dynamique, utiliser une map d'icônes prédéfinies
        // ou retourner une icône par défaut si l'icône n'est pas trouvée
        return getIconFromString(icon!) ?? _getDefaultIcon();
      } catch (e) {
        // En cas d'erreur, utiliser une icône par défaut
        print('Erreur lors de la recherche de l\'icône: $e');
      }
    }

    return _getDefaultIcon();
  }

  // Méthode pour obtenir l'icône par défaut basée sur le type de transaction
  IconData _getDefaultIcon() {
    // Icônes par défaut basées sur le type de transaction
    if (transactionType == 'income') {
      return Icons.arrow_upward;
    } else if (transactionType == 'expense') {
      return Icons.arrow_downward;
    }

    // Icône par défaut générique
    return Icons.category;
  }

// Méthode pour obtenir une icône à partir de son code hexadécimal
  static IconData? getIconFromString(String iconCode) {
    // Map des icônes couramment utilisées
    final Map<String, IconData> iconMap = {
      // Ajouter ici les icônes que vous utilisez dans votre application
      // Format: 'code_hexa': Icons.nom_icone,
      'e5c8': Icons.check,
      'e5cd': Icons.close,
      'e88a': Icons.arrow_upward,
      'e88b': Icons.arrow_downward,
      'e5d5': Icons.category,
      'e8b0': Icons.attach_money,
      'e227': Icons.shopping_cart,
      'e8cc': Icons.restaurant,
      'e332': Icons.home,
      'e0c9': Icons.directions_car,
      'e8f8': Icons.local_hospital,
      'e87d': Icons.school,
      'e0dd': Icons.flight,
      'e8d9': Icons.local_grocery_store,
      'e8d6': Icons.local_cafe,
      'e8b8': Icons.build,
      'e0ef': Icons.phone,
      'e0e2': Icons.event,
      // Ajoutez d'autres icônes selon vos besoins
    };

    return iconMap[iconCode.toLowerCase()];
  }

  // Méthode pour obtenir la couleur (si spécifiée ou une couleur par défaut)
  Color getColor() {
    // Si une couleur est spécifiée, essayer de la convertir
    if (color != null && color!.isNotEmpty) {
      try {
        return Color(int.parse(color!.replaceAll('#', ''), radix: 16) | 0xFF000000);
      } catch (e) {
        // En cas d'erreur, utiliser une couleur par défaut
        print('Erreur lors de la conversion de la couleur: $e');
      }
    }

    // Couleurs par défaut basées sur le type de transaction
    if (transactionType == 'income') {
      return Colors.green;
    } else if (transactionType == 'expense') {
      return Colors.red;
    }

    // Couleur par défaut générique
    return Colors.blue;
  }

  // Créer une copie de cette instance avec des valeurs modifiées
  TransactionCategory copyWith({
    String? id,
    String? name,
    String? transactionType,
    String? description,
    String? icon,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      transactionType: transactionType ?? this.transactionType,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
