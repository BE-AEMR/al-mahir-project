import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Enum définissant les types d'animations disponibles pour le logo
enum LogoAnimationType {
  fade,
  pulse,
  float,
  rotate,
  slideIn,
  none,
}

/// Widget réutilisable pour afficher le logo AL MAHIR Project avec différentes options
/// d'animation et de style.
class LogoWidget extends StatelessWidget {
  /// Utiliser la version dorée (true) ou blanche (false) du logo
  final bool isGold;

  /// Taille du logo (la largeur et la hauteur seront identiques)
  final double size;

  /// Type d'animation à appliquer au logo
  final LogoAnimationType animationType;

  /// Durée de l'animation (si applicable)
  final Duration animationDuration;

  /// Si vrai, l'animation se répète indéfiniment
  final bool repeat;

  const LogoWidget({
    Key? key,
    this.isGold = true,
    this.size = 80,
    this.animationType = LogoAnimationType.none,
    this.animationDuration = const Duration(milliseconds: 800),
    this.repeat = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String logoPath = isGold
        ? 'assets/logo/almahir_gold.svg'
        : 'assets/logo/almahir_blanc.svg';

    Widget logo = SvgPicture.asset(
      logoPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    // Appliquer l'animation sélectionnée
    switch (animationType) {
      case LogoAnimationType.fade:
        return _applyFadeAnimation(logo);
      case LogoAnimationType.pulse:
        return _applyPulseAnimation(logo);
      case LogoAnimationType.float:
        return _applyFloatAnimation(logo);
      case LogoAnimationType.rotate:
        return _applyRotateAnimation(logo);
      case LogoAnimationType.slideIn:
        return _applySlideInAnimation(logo);
      case LogoAnimationType.none:
      default:
        return logo;
    }
  }

  /// Animation de fondu
  Widget _applyFadeAnimation(Widget logo) {
    return logo
      .animate()
      .fadeIn(
        duration: animationDuration,
        curve: Curves.easeIn,
      )
      .then()
      .animate(onComplete: (controller) {
        if (repeat) controller.repeat();
      });
  }

  /// Animation de pulsation (zoom in/out)
  Widget _applyPulseAnimation(Widget logo) {
    return logo
      .animate(
        onComplete: (controller) {
          if (repeat) controller.repeat();
        },
      )
      .scale(
        duration: animationDuration,
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.1, 1.1),
        curve: Curves.easeInOut,
      )
      .then()
      .scale(
        duration: animationDuration,
        begin: const Offset(1.1, 1.1),
        end: const Offset(1.0, 1.0),
        curve: Curves.easeInOut,
      );
  }

  /// Animation de flottement (mouvement vertical subtil)
  Widget _applyFloatAnimation(Widget logo) {
    return logo
      .animate(
        onComplete: (controller) {
          if (repeat) controller.repeat();
        },
      )
      .moveY(
        begin: 0,
        end: -10,
        duration: animationDuration,
        curve: Curves.easeInOut,
      )
      .then()
      .moveY(
        begin: -10,
        end: 0,
        duration: animationDuration,
        curve: Curves.easeInOut,
      );
  }

  /// Animation de rotation
  Widget _applyRotateAnimation(Widget logo) {
    return logo
      .animate(
        onComplete: (controller) {
          if (repeat) controller.repeat();
        },
      )
      .rotate(
        duration: animationDuration,
        begin: 0,
        end: 0.05,
        curve: Curves.easeInOut,
      )
      .then()
      .rotate(
        duration: animationDuration,
        begin: 0.05,
        end: -0.05,
        curve: Curves.easeInOut,
      )
      .then()
      .rotate(
        duration: animationDuration,
        begin: -0.05,
        end: 0,
        curve: Curves.easeInOut,
      );
  }

  /// Animation de glissement (entrée par le côté)
  Widget _applySlideInAnimation(Widget logo) {
    return logo
      .animate()
      .slideX(
        begin: -1,
        end: 0,
        duration: animationDuration,
        curve: Curves.easeOutQuad,
      )
      .fadeIn(
        duration: animationDuration * 0.7,
      );
  }
}
