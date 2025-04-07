import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/role_provider.dart';

/// Widget qui contrôle l'accès à un écran complet en fonction des permissions RBAC
/// 
/// Utilisation:
/// ```
/// RbacGatedScreen(
///   permissionName: 'view_finances',
///   projectId: projectId, // optionnel
///   teamId: teamId, // optionnel
///   child: YourScreen(),
///   onAccessDenied: () => Navigator.of(context).pop(), // optionnel
///   accessDeniedWidget: const CustomAccessDeniedWidget(), // optionnel
/// )
/// ```
class RbacGatedScreen extends StatelessWidget {
  final String permissionName;
  final Widget child;
  final String? projectId;
  final String? teamId;
  final VoidCallback? onAccessDenied;
  final Widget? accessDeniedWidget;
  final bool showLoadingIndicator;

  const RbacGatedScreen({
    Key? key,
    required this.permissionName,
    required this.child,
    this.projectId,
    this.teamId,
    this.onAccessDenied,
    this.accessDeniedWidget,
    this.showLoadingIndicator = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DEBUG: RbacGatedScreen.build() - Début - Permission: $permissionName');
    return FutureBuilder<bool>(
      future: Provider.of<RoleProvider>(context, listen: false).hasPermission(
        permissionName,
        projectId: projectId,
        teamId: teamId,
      ),
      builder: (context, snapshot) {
        print('DEBUG: RbacGatedScreen.builder() - État de la connexion: ${snapshot.connectionState}');
        // Afficher un indicateur de chargement
        if (snapshot.connectionState == ConnectionState.waiting && showLoadingIndicator) {
          print('DEBUG: RbacGatedScreen - Affichage du loader');
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chargement...'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Vérifier si l'utilisateur a la permission
        final hasPermission = snapshot.data ?? false;
        print('DEBUG: RbacGatedScreen - hasPermission: $hasPermission');

        if (hasPermission) {
          print('DEBUG: RbacGatedScreen - Accès autorisé, affichage de l\'écran');
          return child;
        } else {
          print('DEBUG: RbacGatedScreen - Accès refusé, création du widget _AccessDeniedScreen');
          // Au lieu d'appeler onAccessDenied immédiatement, nous utilisons un widget stateful
          // qui appellera onAccessDenied après son initialisation complète
          return _AccessDeniedScreen(
            onAccessDenied: onAccessDenied,
            accessDeniedWidget: accessDeniedWidget ?? _buildDefaultAccessDeniedScreen(context),
          );
        }
      },
    );
  }

  Widget _buildDefaultAccessDeniedScreen(BuildContext context) {
    print('DEBUG: RbacGatedScreen - Construction de l\'écran d\'accès refusé par défaut');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès refusé'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Vous n\'avez pas l\'autorisation d\'accéder à cette fonctionnalité',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                print('DEBUG: RbacGatedScreen - Bouton Retour pressé');
                Navigator.of(context).pop();
              },
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget stateful pour gérer l'accès refusé de manière sécurisée
class _AccessDeniedScreen extends StatefulWidget {
  final VoidCallback? onAccessDenied;
  final Widget accessDeniedWidget;

  const _AccessDeniedScreen({
    this.onAccessDenied,
    required this.accessDeniedWidget,
  });

  @override
  State<_AccessDeniedScreen> createState() => _AccessDeniedScreenState();
}

class _AccessDeniedScreenState extends State<_AccessDeniedScreen> {
  @override
  void initState() {
    super.initState();
    print('DEBUG: _AccessDeniedScreenState.initState() - Début');
    // Attendre que le widget soit complètement construit avant d'appeler onAccessDenied
    if (widget.onAccessDenied != null) {
      print('DEBUG: _AccessDeniedScreenState - onAccessDenied != null, planification du callback');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('DEBUG: _AccessDeniedScreenState - postFrameCallback exécuté');
        if (mounted) {
          print('DEBUG: _AccessDeniedScreenState - Widget toujours monté, appel de onAccessDenied');
          try {
            widget.onAccessDenied!();
            print('DEBUG: _AccessDeniedScreenState - onAccessDenied exécuté avec succès');
          } catch (e) {
            print('ERREUR: _AccessDeniedScreenState - Exception dans onAccessDenied: $e');
          }
        } else {
          print('DEBUG: _AccessDeniedScreenState - Widget démonté, onAccessDenied non appelé');
        }
      });
    } else {
      print('DEBUG: _AccessDeniedScreenState - Pas de callback onAccessDenied fourni');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: _AccessDeniedScreenState.build() - Début');
    return widget.accessDeniedWidget;
  }
}

/// Mixin pour ajouter des fonctionnalités RBAC aux écrans
/// 
/// Utilisation:
/// ```
/// class YourScreenState extends State<YourScreen> with RbacMixin {
///   @override
///   Widget build(BuildContext context) {
///     // Vérifier la permission avant une action
///     bool canCreate = await checkPermission('create_project');
///     
///     // Utiliser permissionGated pour contrôler l'affichage des widgets
///     Widget button = permissionGated(
///       'update_project',
///       ElevatedButton(...),
///       projectId: projectId,
///     );
///   }
/// }
/// ```
mixin RbacMixin<T extends StatefulWidget> on State<T> {
  /// Vérifie si l'utilisateur a une permission spécifique
  Future<bool> checkPermission(
    String permissionName, {
    String? projectId,
    String? teamId,
  }) async {
    final provider = Provider.of<RoleProvider>(context, listen: false);
    return await provider.hasPermission(
      permissionName,
      projectId: projectId,
      teamId: teamId,
    );
  }

  /// Crée un widget qui ne s'affiche que si l'utilisateur a la permission
  Widget permissionGated(
    String permissionName,
    Widget child, {
    Widget? fallback,
    String? projectId,
    String? teamId,
    bool showLoadingIndicator = false,
  }) {
    return FutureBuilder<bool>(
      future: checkPermission(
        permissionName,
        projectId: projectId,
        teamId: teamId,
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
          return fallback;
        } else {
          return const SizedBox.shrink(); // Ne rien afficher
        }
      },
    );
  }
}
