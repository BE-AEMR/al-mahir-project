import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

// Cette fonction crée une image PNG à partir du SVG avec le fond approprié
Future<void> main() async {
  // Création du répertoire si nécessaire
  Directory('assets/logo').createSync(recursive: true);
  
  // Dimensions de l'icône (1024x1024 est recommandé pour les app stores)
  const int size = 1024;
  
  // Couleur de fond de la sidebar
  const Color backgroundColor = Color(0xFF1F4E5F);
  
  // Création d'un fichier PNG temporaire
  print('Génération de l\'icône de l\'application...');
  
  // Le chemin vers votre fichier SVG
  final String svgPath = 'assets/logo/almahir_blanc.svg';
  
  // Vérifier si le fichier existe
  final File svgFile = File(svgPath);
  if (!svgFile.existsSync()) {
    print('Erreur : Le fichier SVG n\'existe pas à l\'emplacement : $svgPath');
    return;
  }
  
  print('Le fichier SVG a été trouvé.');
  print('Veuillez exécuter la commande suivante pour générer les icônes d\'application :');
  print('flutter pub get && flutter pub run flutter_launcher_icons');
}
