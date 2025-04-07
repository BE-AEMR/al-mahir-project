// Fichier de constantes pour l'application AL MAHIR Project GESTION DES PROJETS

import 'package:flutter/material.dart';

// Couleurs
class AppColors {
  static const Color primary = Color(0xFF1F4E5F);
  static const Color secondary = Color(0xFF0D2B36);
  static const Color accent = Color(0xFF5BBFBA);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF757575);
}

// Formatage pour la monnaie
class CurrencyFormat {
  static const String euro = '€';
  static const String dollar = '\$';
  static const String defaultCurrency = euro;
  static const int decimalDigits = 2;
}

// Catégories de budget
class BudgetCategories {
  static const String personnelInternal = 'Personnel interne';
  static const String personnelExternal = 'Personnel externe';
  static const String materiels = 'Matériels';
  static const String logiciels = 'Logiciels';
  static const String voyages = 'Voyages';
  static const String formation = 'Formation';
  static const String marketing = 'Marketing';
  static const String autres = 'Autres';

  static List<String> getAllCategories() {
    return [
      personnelInternal,
      personnelExternal,
      materiels,
      logiciels,
      voyages,
      formation,
      marketing,
      autres,
    ];
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case personnelInternal:
        return Colors.blue;
      case personnelExternal:
        return Colors.orange;
      case materiels:
        return Colors.green;
      case logiciels:
        return Colors.purple;
      case voyages:
        return Colors.red;
      case formation:
        return Colors.teal;
      case marketing:
        return Colors.pink;
      case autres:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case personnelInternal:
        return Icons.people;
      case personnelExternal:
        return Icons.person_outline;
      case materiels:
        return Icons.devices;
      case logiciels:
        return Icons.laptop;
      case voyages:
        return Icons.flight;
      case formation:
        return Icons.school;
      case marketing:
        return Icons.trending_up;
      case autres:
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }
}

// Seuils pour les alertes de budget
class BudgetThresholds {
  static const double warning = 80.0; // 80% du budget utilisé
  static const double critical = 100.0; // 100% du budget utilisé (dépassement)
}

// Messages d'erreur et de succès
class AppMessages {
  static const String errorGeneric = 'Une erreur est survenue. Veuillez réessayer.';
  static const String errorNetwork = 'Erreur de connexion. Veuillez vérifier votre connexion internet.';
  static const String errorAuthentication = 'Erreur d\'authentification. Veuillez vous reconnecter.';
  static const String errorPermission = 'Vous n\'avez pas les permissions nécessaires pour cette action.';

  static const String successSave = 'Enregistré avec succès.';
  static const String successDelete = 'Supprimé avec succès.';
  static const String successCreate = 'Créé avec succès.';
  static const String successUpdate = 'Mis à jour avec succès.';
}
