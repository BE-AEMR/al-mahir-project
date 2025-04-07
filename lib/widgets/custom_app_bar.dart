import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'logo_widget.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.showLogo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    
    return AppBar(
      title: showLogo
          ? Row(
              children: [
                const LogoWidget(
                  isGold: true,
                  size: 32,
                  animationType: LogoAnimationType.rotate,
                  animationDuration: Duration(milliseconds: 2000),
                  repeat: true,
                ),
                const SizedBox(width: 12),
                Text(title),
              ],
            )
          : Text(title),
      backgroundColor: const Color(0xFF1F4E5F),
      elevation: 0,
      actions: actions ??
          [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Recherche
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // Notifications
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    color: const Color(0xFF1F4E5F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
