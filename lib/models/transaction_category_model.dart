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
        // Trouver l'icône par son nom
        final iconData = IconData(
          int.parse(icon!, radix: 16),
          fontFamily: 'MaterialIcons',
        );
        return iconData;
      } catch (e) {
        // En cas d'erreur, utiliser une icône par défaut
        print('Erreur lors de la recherche de l\'icône: $e');
      }
    }
    
    // Icônes par défaut basées sur le type de transaction
    if (transactionType == 'income') {
      return Icons.arrow_upward;
    } else if (transactionType == 'expense') {
      return Icons.arrow_downward;
    }
    
    // Icône par défaut générique
    return Icons.category;
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
