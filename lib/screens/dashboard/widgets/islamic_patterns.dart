import 'package:flutter/material.dart';
import 'dart:math' as math;

class IslamicPatternBackground extends StatelessWidget {
  final Color color;
  final double scale;

  const IslamicPatternBackground({
    Key? key,
    this.color = Colors.white,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: IslamicPatternPainter(
        color: color,
        scale: scale,
      ),
      size: Size.infinite,
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double scale;

  IslamicPatternPainter({
    required this.color,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double tileSize = 80 * scale;
    
    for (double y = -tileSize; y < size.height + tileSize; y += tileSize) {
      for (double x = -tileSize; x < size.width + tileSize; x += tileSize) {
        _drawGeometricStarPattern(canvas, Offset(x, y), tileSize, paint);
      }
    }
  }
  
  void _drawGeometricStarPattern(Canvas canvas, Offset center, double size, Paint paint) {
    final radius = size / 2;
    
    // Dessiner l'étoile à 8 branches
    final path = Path();
    
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final outerPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final innerPoint = Offset(
        center.dx + radius * 0.4 * math.cos(angle + math.pi / 8),
        center.dy + radius * 0.4 * math.sin(angle + math.pi / 8),
      );
      
      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
      
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Dessiner l'octogone intérieur
    final innerPath = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final point = Offset(
        center.dx + radius * 0.6 * math.cos(angle),
        center.dy + radius * 0.6 * math.sin(angle),
      );
      
      if (i == 0) {
        innerPath.moveTo(point.dx, point.dy);
      } else {
        innerPath.lineTo(point.dx, point.dy);
      }
    }
    
    innerPath.close();
    canvas.drawPath(innerPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
