import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

// Cette classe servira à générer un aperçu de l'icône de l'application
class IconGenerator {
  static Future<void> generateIcon() async {
    // Assurez-vous que Flutter est initialisé
    WidgetsFlutterBinding.ensureInitialized();

    // Créez un widget pour l'icône avec le fond de la sidebar
    final widget = Container(
      width: 1024,
      height: 1024,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F4E5F),
            Color(0xFF0D2B36),
          ],
        ),
      ),
    );

    // Instructions pour l'utilisateur
    print('Pour générer les icônes de l\'application:');
    print('1. Assurez-vous que le fichier SVG existe dans assets/logo/almahir_blanc.svg');
    print('2. Exécutez: flutter pub run flutter_launcher_icons');
  }
}
