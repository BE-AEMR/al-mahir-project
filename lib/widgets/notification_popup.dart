import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
// Importer la classe Notification et NotificationType avec des alias pour éviter les conflits
import '../models/notification_model.dart' as app_models;
import '../services/notification_service.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationPopup extends StatefulWidget {
  const NotificationPopup({Key? key}) : super(key: key);

  @override
  State<NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<NotificationPopup> {
  final NotificationService _notificationService = NotificationService();
  List<app_models.Notification> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifications = await _notificationService.getUserNotifications(onlyUnread: false);
      final unreadCount = await _notificationService.getUnreadNotificationsCount();
      
      setState(() {
        _notifications = notifications.take(5).toList(); // Limitez à 5 notifications dans le popup
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        });
      }
    } catch (e) {
      // Gérer l'erreur silencieusement dans le popup
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
          _unreadCount = 0;
        });
      }
    } catch (e) {
      // Gérer l'erreur silencieusement dans le popup
    }
  }

  Future<void> _viewAllNotifications() async {
    Navigator.of(context).pop(); // Fermer le popup
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Rafraîchir les notifications après le retour
    _loadNotifications();
  }

  Future<void> _navigateToRelatedItem(app_models.Notification notification) async {
    // Fermer le popup
    Navigator.of(context).pop();
    
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
        Navigator.pushNamed(
          context, 
          '/project_details',
          arguments: {'projectId': notification.relatedId},
        );
        break;
      case app_models.NotificationType.phaseCreated:
      case app_models.NotificationType.phaseStatusChanged:
        // Naviguer vers la page de la phase
        Navigator.pushNamed(
          context, 
          '/phase_details',
          arguments: {'phaseId': notification.relatedId},
        );
        break;
      case app_models.NotificationType.taskAssigned:
      case app_models.NotificationType.taskDueSoon:
      case app_models.NotificationType.taskOverdue:
      case app_models.NotificationType.taskStatusChanged:
        // Naviguer vers la page de la tâche
        Navigator.pushNamed(
          context, 
          '/task_details',
          arguments: {'taskId': notification.relatedId},
        );
        break;
      case app_models.NotificationType.projectInvitation:
        // Naviguer vers la page des invitations
        Navigator.pushNamed(context, '/invitations');
        break;
      case app_models.NotificationType.newUser:
        // Naviguer vers la page de profil de l'utilisateur
        Navigator.pushNamed(
          context, 
          '/user_profile',
          arguments: {'userId': notification.relatedId},
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F4E5F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications ($_unreadCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _unreadCount > 0
                      ? TextButton.icon(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                          label: const Text(
                            'Tout lire',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aucune notification',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final timeAgo = timeago.format(notification.createdAt, locale: 'fr');
                            
                            return InkWell(
                              onTap: () => _navigateToRelatedItem(notification),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: notification.isRead ? null : Colors.blue.shade50,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: notification.getColor().withOpacity(0.2),
                                      child: Icon(
                                        notification.getIcon(),
                                        color: notification.getColor(),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification.title,
                                            style: TextStyle(
                                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.message,
                                            style: const TextStyle(fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                        onPressed: () => _markAsRead(notification.id),
                                        tooltip: 'Marquer comme lu',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: TextButton(
                onPressed: _viewAllNotifications,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'Voir toutes les notifications',
                  style: TextStyle(
                    color: Color(0xFF1F4E5F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationIcon extends StatefulWidget {
  const NotificationIcon({Key? key}) : super(key: key);

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final unreadCount = await _notificationService.getUnreadNotificationsCount();
      setState(() {
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNotificationPopup(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    await showMenu(
      context: context,
      position: position,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(0))),
      color: Colors.transparent,
      items: [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          child: const NotificationPopup(),
        ),
      ],
    );

    // Rafraîchir le compteur après la fermeture du popup
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser MediaQuery pour adapter la taille de l'icône à la taille de l'écran
    final double iconSize = MediaQuery.of(context).size.width < 360 ? 24.0 : 28.0;
    
    return Container(
      // Ajouter une contrainte de largeur pour éviter le débordement
      width: iconSize + 12,
      height: iconSize + 12,
      child: GestureDetector(
        onTap: () => _showNotificationPopup(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications, 
              color: Colors.white,
              size: iconSize,
            ),
            if (_unreadCount > 0 && !_isLoading)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
