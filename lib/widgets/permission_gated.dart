import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webxio_new/providers/role_provider.dart';

/// Widget qui affiche son contenu uniquement si l'utilisateur a la permission requise
class PermissionGated extends StatelessWidget {
  final String permissionName;
  final Widget child;
  final Widget? fallback;
  final String? teamId;
  final String? projectId;
  final bool showLoadingIndicator;

  const PermissionGated({
    super.key,
    required this.permissionName,
    required this.child,
    this.fallback,
    this.teamId,
    this.projectId,
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Provider.of<RoleProvider>(context, listen: false).hasPermission(
        permissionName,
        teamId: teamId,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        // Afficher un indicateur de chargement si nécessaire
        if (snapshot.connectionState == ConnectionState.waiting && showLoadingIndicator) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          );
        }

        // Vérifier si l'utilisateur a la permission
        final hasPermission = snapshot.data ?? false;
        
        if (hasPermission) {
          return child;
        } else if (fallback != null) {
          return fallback!;
        } else {
          return const SizedBox.shrink(); // Ne rien afficher
        }
      },
    );
  }
}

/// Extension de PermissionGated spécifiquement pour les boutons
class PermissionGatedButton extends StatelessWidget {
  final String permissionName;
  final Widget child;
  final VoidCallback? onPressed;
  final String? teamId;
  final String? projectId;
  final bool showLoadingIndicator;

  const PermissionGatedButton({
    super.key,
    required this.permissionName,
    required this.child,
    required this.onPressed,
    this.teamId,
    this.projectId,
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Provider.of<RoleProvider>(context, listen: false).hasPermission(
        permissionName,
        teamId: teamId,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        // Pendant le chargement, afficher le bouton désactivé
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(
            onPressed: null, // Bouton désactivé
            child: showLoadingIndicator
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : child,
          );
        }

        final hasPermission = snapshot.data ?? false;
        
        // Afficher le bouton activé ou désactivé selon la permission
        return ElevatedButton(
          onPressed: hasPermission ? onPressed : null,
          child: child,
        );
      },
    );
  }
}

/// Fonction qui vérifie de manière synchrone si un widget doit être construit
/// Utile pour les listes ou autres scénarios où FutureBuilder n'est pas idéal
class PermissionBuilder extends StatelessWidget {
  final String permissionName;
  final Widget Function(BuildContext, bool) builder;
  final String? teamId;
  final String? projectId;

  const PermissionBuilder({
    super.key,
    required this.permissionName,
    required this.builder,
    this.teamId,
    this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    
    return FutureBuilder<bool>(
      future: roleProvider.hasPermission(
        permissionName,
        teamId: teamId,
        projectId: projectId,
      ),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        return builder(context, hasPermission);
      },
    );
  }
}
