import 'package:flutter/material.dart';
import 'dart:math' as math;

class IslamicPatternBackground extends StatelessWidget {
  final Color color;
  
  IslamicPatternBackground({
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: IslamicPatternPainter(color: color),
      child: Container(),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  
  IslamicPatternPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double tileSize = 50;
    final int horizontalTileCount = (size.width / tileSize).ceil() + 1;
    final int verticalTileCount = (size.height / tileSize).ceil() + 1;

    // Dessiner le motif géométrique islamique
    for (int y = -1; y < verticalTileCount; y++) {
      for (int x = -1; x < horizontalTileCount; x++) {
        final double centerX = x * tileSize;
        final double centerY = y * tileSize;
        
        // Dessiner un motif de base
        _drawStarPattern(canvas, paint, centerX, centerY, tileSize);
      }
    }
  }

  void _drawStarPattern(Canvas canvas, Paint paint, double centerX, double centerY, double size) {
    final double radius = size / 2;
    
    // Dessiner un octogone
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final double angle = i * math.pi / 4;
      final double x = centerX + radius * math.cos(angle);
      final double y = centerY + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    
    // Dessiner des lignes internes
    for (int i = 0; i < 4; i++) {
      final double angle = i * math.pi / 4;
      final double x1 = centerX + radius * math.cos(angle);
      final double y1 = centerY + radius * math.sin(angle);
      final double x2 = centerX + radius * math.cos(angle + math.pi);
      final double y2 = centerY + radius * math.sin(angle + math.pi);
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
    
    // Dessiner un cercle central
    canvas.drawCircle(Offset(centerX, centerY), radius / 3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Widget pour afficher un espace réservé avec un motif islamique
class IslamicPatternPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final String? message;
  final Color textColor;
  final double borderRadius;
  final double? size;

  const IslamicPatternPlaceholder({
    Key? key,
    this.width = double.infinity,
    this.height = 200,
    this.color = const Color(0xFFE8F3F5),
    this.message,
    this.textColor = Colors.black54,
    this.borderRadius = 8.0,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.3,
            child: CustomPaint(
              painter: IslamicPatternPainter(color: textColor),
              size: Size(width, height),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                message!,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class IslamicDecorativeHeader extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final bool showDecoration;

  const IslamicDecorativeHeader({
    Key? key,
    required this.title,
    this.backgroundColor = const Color(0xFF1E88E5),
    this.textColor = Colors.white,
    this.height = 120.0,
    this.showDecoration = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: backgroundColor,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: [
          if (showDecoration) ...[
            Positioned(
              left: 0,
              bottom: 0,
              child: _buildDecorativeElement(),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildDecorativeElement(isReversed: true),
            ),
          ],
          Center(
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeElement({bool isReversed = false}) {
    return SizedBox(
      width: 80,
      height: height,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(isReversed ? math.pi : 0),
        child: CustomPaint(
          painter: ArabicArchPainter(
            color: textColor.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

class ArabicArchPainter extends CustomPainter {
  final Color color;

  ArabicArchPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;
    
    final path = Path();
    path.moveTo(0, height);
    path.lineTo(0, height * 0.4);
    path.quadraticBezierTo(width * 0.5, 0, width, height * 0.4);
    path.lineTo(width, height);
    
    canvas.drawPath(path, paint);
    
    // Dessiner des détails décoratifs
    for (int i = 1; i < 5; i++) {
      final double y = height * 0.4 + (height * 0.6 / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class IslamicDecorativeButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final double width;
  final double height;
  final bool isOutlined;
  final IconData? icon;

  const IslamicDecorativeButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF1E88E5),
    this.textColor = Colors.white,
    this.width = double.infinity,
    this.height = 50.0,
    this.isOutlined = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color,
        border: Border.all(
          color: color,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.0),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: isOutlined ? color : textColor,
                    size: 20.0,
                  ),
                  SizedBox(width: 8.0),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: isOutlined ? color : textColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
