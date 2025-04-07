import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
// Importer la classe Notification et NotificationType avec des alias pour éviter les conflits
import '../../models/notification_model.dart' as app_models;
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/permission_gated.dart';
import '../../widgets/rbac_gated_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();
  List<app_models.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialisation de timeago en français
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await _notificationService.getUserNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors du chargement des notifications'
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _notificationService.markAllAsRead();
      if (success) {
        setState(() {
          _notifications = _notifications.map((notification) {
            return notification.copyWith(isRead: true);
          }).toList();
        });
        if (mounted) {
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Toutes les notifications ont été marquées comme lues'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors du marquage des notifications comme lues'
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (success) {
        setState(() {
          _notifications = _notifications.map((notification) {
            if (notification.id == notificationId) {
              return notification.copyWith(isRead: true);
            }
            return notification;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors du marquage de la notification comme lue'
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final success = await _notificationService.deleteNotification(notificationId);
      if (success) {
        setState(() {
          _notifications = _notifications.where((notification) => notification.id != notificationId).toList();
        });
        if (mounted) {
          SnackBarHelper.showSuccessSnackBar(
            context, 
            'Notification supprimée'
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showErrorSnackBar(
          context, 
          'Erreur lors de la suppression de la notification'
        );
      }
    }
  }

  Future<void> _navigateToRelatedItem(app_models.Notification notification) async {
    // Marquer la notification comme lue
    await _markAsRead(notification.id);

    if (notification.relatedId == null) return;

    // Navigation vers l'élément associé selon le type de notification
    switch (notification.type) {
      case app_models.NotificationType.projectCreated:
      case app_models.NotificationType.projectStatusChanged:
      case app_models.NotificationType.projectBudgetAlert:
      case app_models.NotificationType.projectAddedToTeam:
        // Naviguer vers la page du projet
        if (mounted) {
          Navigator.pushNamed(
            context, 
            '/project_details',
            arguments: {'projectId': notification.relatedId},
          );
        }
        break;
      case app_models.NotificationType.phaseCreated:
      case app_models.NotificationType.phaseStatusChanged:
        // Naviguer vers la page de la phase
        if (mounted) {
          Navigator.pushNamed(
            context, 
            '/phase_details',
            arguments: {'phaseId': notification.relatedId},
          );
        }
        break;
      case app_models.NotificationType.taskAssigned:
      case app_models.NotificationType.taskDueSoon:
      case app_models.NotificationType.taskOverdue:
      case app_models.NotificationType.taskStatusChanged:
        // Naviguer vers la page de la tâche
        if (mounted) {
          Navigator.pushNamed(
            context, 
            '/task_details',
            arguments: {'taskId': notification.relatedId},
          );
        }
        break;
      case app_models.NotificationType.projectInvitation:
        // Naviguer vers la page des invitations
        if (mounted) {
          Navigator.pushNamed(context, '/invitations');
        }
        break;
      case app_models.NotificationType.newUser:
        // Naviguer vers la page de profil de l'utilisateur
        if (mounted) {
          Navigator.pushNamed(
            context, 
            '/user_profile',
            arguments: {'userId': notification.relatedId},
          );
        }
        break;
    }
  }

  Widget _buildNotificationCard(app_models.Notification notification) {
    // La mise en forme reste la même, mais on corrige l'utilisation de timeago
    Color backgroundColor = notification.isRead ? Colors.white : Colors.blue.shade50;
    
    // Obtenir une représentation lisible de la date de création
    String timeAgoStr = '';
    try {
      timeAgoStr = timeago.format(notification.createdAt, locale: 'fr');
    } catch (e) {
      // Fallback pour le cas où timeago ne fonctionne pas correctement
      timeAgoStr = notification.createdAt.toString();
    }
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      color: backgroundColor,
      child: ListTile(
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              timeAgoStr,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: () => _navigateToRelatedItem(notification),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PermissionGated(
              permissionName: 'manage_notifications',
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: notification.isRead 
                    ? null 
                    : () => _markAsRead(notification.id),
                tooltip: 'Marquer comme lu',
                color: notification.isRead ? Colors.grey : Colors.blue,
              ),
            ),
            PermissionGated(
              permissionName: 'delete_notifications',
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteNotification(notification.id),
                tooltip: 'Supprimer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RbacGatedScreen(
      permissionName: 'read_profile',
      onAccessDenied: () {
        print('DEBUG: NotificationsScreen - onAccessDenied appelé');
        // Afficher seulement un message dans la console sans redirection automatique
        print('DEBUG: NotificationsScreen - Accès refusé, affichage de l\'écran d\'accès refusé');
      },
      accessDeniedWidget: Scaffold(
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
                'Vous n\'avez pas l\'autorisation d\'accéder aux notifications',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigation à la page d'accueil
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: const Color(0xFF1F4E5F),
          foregroundColor: Colors.white,
          actions: [
            PermissionGated(
              permissionName: 'manage_notifications',
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Tout marquer comme lu',
                onPressed: _markAllAsRead,
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune notification',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
      ),
    );
  }
}
