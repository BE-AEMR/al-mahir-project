import 'package:flutter/material.dart';

class AppColors {
  // Couleurs principales
  static const primary = Color(0xFF1F4E5F);
  static const primaryLight = Color(0xFF356273);
  static const secondary = Color(0xFF2E7D32);
  static const accent = Color(0xFFFF6F00);
  
  // Couleurs de statut
  static const todo = Color(0xFF90A4AE);
  static const inProgress = Color(0xFF2196F3);
  static const completed = Color(0xFF4CAF50);
  static const blocked = Color(0xFFE53935);
  static const pending = Color(0xFFFF9800);
  static const cancelled = Color(0xFF9E9E9E);
  
  // Couleurs de priorité
  static const lowPriority = Color(0xFF8BC34A);
  static const mediumPriority = Color(0xFFFFC107);
  static const highPriority = Color(0xFFFF5722);
  static const criticalPriority = Color(0xFFD32F2F);
  
  // Couleurs de graphiques
  static const List<Color> chartColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE53935),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFF3F51B5),
    Color(0xFFFFEB3B),
  ];
  
  // Couleurs d'état
  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const error = Color(0xFFB00020);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF2196F3);
  
  // Couleurs de texte
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textLight = Colors.white;
}
