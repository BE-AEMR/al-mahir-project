import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Récupérer toutes les notifications de l'utilisateur actuel
  Future<List<Notification>> getUserNotifications({bool onlyUnread = false}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Construction de la requête
      List<dynamic> response;
      if (onlyUnread) {
        // Requête pour les notifications non lues seulement
        response = await _supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .eq('is_read', false)
            .order('created_at', ascending: false);
      } else {
        // Toutes les notifications
        response = await _supabase
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      }

      return response.map<Notification>((json) => Notification.fromJson(json)).toList();
    } catch (e) {
      print('Erreur lors de la récupération des notifications: $e');
      return [];
    }
  }

  // Récupérer le nombre de notifications non lues
  Future<int> getUnreadNotificationsCount() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Récupérer toutes les notifications non lues
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return response.length;
    } catch (e) {
      print('Erreur lors de la récupération du nombre de notifications non lues: $e');
      return 0;
    }
  }

  // Marquer une notification comme lue
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      print('Erreur lors du marquage de la notification comme lue: $e');
      return false;
    }
  }

  // Marquer toutes les notifications comme lues
  Future<bool> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Erreur lors du marquage de toutes les notifications comme lues: $e');
      return false;
    }
  }

  // Supprimer une notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      return true;
    } catch (e) {
      print('Erreur lors de la suppression de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour un nouvel utilisateur (admin uniquement)
  Future<bool> createNewUserNotification(String newUserId, String newUserName) async {
    try {
      // Récupérer les administrateurs
      final admins = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');
      
      // Créer une notification pour chaque administrateur
      for (final admin in admins) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Nouvel utilisateur',
          message: '$newUserName a rejoint la plateforme.',
          createdAt: DateTime.now(),
          type: NotificationType.newUser,
          relatedId: newUserId,
          userId: admin['id'],
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour un projet créé
  Future<bool> createProjectNotification(String projectId, String projectName, List<String> teamMemberIds) async {
    try {
      // Créer une notification pour chaque membre de l'équipe
      for (final userId in teamMemberIds) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Nouveau projet',
          message: 'Le projet "$projectName" a été créé.',
          createdAt: DateTime.now(),
          type: NotificationType.projectCreated,
          relatedId: projectId,
          userId: userId,
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour un changement de statut de projet
  Future<bool> createProjectStatusNotification(String projectId, String projectName, String status, List<String> teamMemberIds) async {
    try {
      String statusText = '';
      switch (status) {
        case 'completed': statusText = 'terminé'; break;
        case 'onHold': statusText = 'en attente'; break;
        case 'cancelled': statusText = 'annulé'; break;
        default: statusText = status;
      }

      // Créer une notification pour chaque membre de l'équipe
      for (final userId in teamMemberIds) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Statut du projet modifié',
          message: 'Le projet "$projectName" est maintenant $statusText.',
          createdAt: DateTime.now(),
          type: NotificationType.projectStatusChanged,
          relatedId: projectId,
          userId: userId,
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une alerte de budget
  Future<bool> createProjectBudgetAlert(String projectId, String projectName, double percentage, List<String> teamMemberIds) async {
    try {
      String message = '';
      if (percentage >= 100) {
        message = 'Le budget du projet "$projectName" a été dépassé.';
      } else {
        message = 'Le budget du projet "$projectName" a atteint ${percentage.toStringAsFixed(0)}% du montant alloué.';
      }

      // Créer une notification pour chaque membre de l'équipe
      for (final userId in teamMemberIds) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Alerte budget',
          message: message,
          createdAt: DateTime.now(),
          type: NotificationType.projectBudgetAlert,
          relatedId: projectId,
          userId: userId,
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une nouvelle phase
  Future<bool> createPhaseNotification(String phaseId, String phaseName, String projectName, List<String> teamMemberIds) async {
    try {
      // Créer une notification pour chaque membre de l'équipe
      for (final userId in teamMemberIds) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Nouvelle phase',
          message: 'La phase "$phaseName" a été ajoutée au projet "$projectName".',
          createdAt: DateTime.now(),
          type: NotificationType.phaseCreated,
          relatedId: phaseId,
          userId: userId,
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour un changement de statut de phase
  Future<bool> createPhaseStatusNotification(String phaseId, String phaseName, String projectName, String status, List<String> teamMemberIds) async {
    try {
      String statusText = '';
      switch (status) {
        case 'not_started': statusText = 'non démarrée'; break;
        case 'in_progress': statusText = 'en cours'; break;
        case 'completed': statusText = 'terminée'; break;
        case 'on_hold': statusText = 'en attente'; break;
        case 'cancelled': statusText = 'annulée'; break;
        default: statusText = status;
      }

      // Créer une notification pour chaque membre de l'équipe
      for (final userId in teamMemberIds) {
        final notification = Notification(
          id: _uuid.v4(),
          title: 'Statut de phase modifié',
          message: 'La phase "$phaseName" du projet "$projectName" est maintenant $statusText.',
          createdAt: DateTime.now(),
          type: NotificationType.phaseStatusChanged,
          relatedId: phaseId,
          userId: userId,
        );
        
        await _supabase.from('notifications').insert(notification.toJson());
      }
      
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification d'assignation de tâche
  Future<bool> createTaskAssignedNotification(String taskId, String taskTitle, String projectName, String assignedUserId) async {
    try {
      final notification = Notification(
        id: _uuid.v4(),
        title: 'Tâche assignée',
        message: 'Vous avez été assigné à la tâche "$taskTitle" dans le projet "$projectName".',
        createdAt: DateTime.now(),
        type: NotificationType.taskAssigned,
        relatedId: taskId,
        userId: assignedUserId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une tâche dont l'échéance approche
  Future<bool> createTaskDueSoonNotification(String taskId, String taskTitle, String projectName, DateTime dueDate, String assignedUserId) async {
    try {
      final daysRemaining = dueDate.difference(DateTime.now()).inDays;
      String message = '';
      
      if (daysRemaining <= 1) {
        message = 'La tâche "$taskTitle" dans le projet "$projectName" doit être terminée dans 1 jour.';
      } else if (daysRemaining <= 3) {
        message = 'La tâche "$taskTitle" dans le projet "$projectName" doit être terminée dans 3 jours.';
      } else {
        message = 'La tâche "$taskTitle" dans le projet "$projectName" doit être terminée dans 1 semaine.';
      }

      final notification = Notification(
        id: _uuid.v4(),
        title: 'Échéance proche',
        message: message,
        createdAt: DateTime.now(),
        type: NotificationType.taskDueSoon,
        relatedId: taskId,
        userId: assignedUserId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une tâche en retard
  Future<bool> createTaskOverdueNotification(String taskId, String taskTitle, String projectName, String assignedUserId) async {
    try {
      final notification = Notification(
        id: _uuid.v4(),
        title: 'Tâche en retard',
        message: 'La tâche "$taskTitle" dans le projet "$projectName" a dépassé sa date d\'échéance.',
        createdAt: DateTime.now(),
        type: NotificationType.taskOverdue,
        relatedId: taskId,
        userId: assignedUserId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour un changement de statut de tâche
  Future<bool> createTaskStatusNotification(String taskId, String taskTitle, String projectName, String status, String assignedUserId, String changedByUserId) async {
    try {
      // Ne pas notifier l'utilisateur s'il est celui qui a changé le statut
      if (assignedUserId == changedByUserId) {
        return true;
      }
      
      String statusText = '';
      switch (status) {
        case 'review': statusText = 'en révision'; break;
        case 'completed': statusText = 'terminée'; break;
        default: return true; // Ne pas notifier pour les autres statuts
      }

      final notification = Notification(
        id: _uuid.v4(),
        title: 'Statut de tâche modifié',
        message: 'La tâche "$taskTitle" dans le projet "$projectName" est maintenant $statusText.',
        createdAt: DateTime.now(),
        type: NotificationType.taskStatusChanged,
        relatedId: taskId,
        userId: assignedUserId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une invitation à un projet
  Future<bool> createProjectInvitationNotification(String teamId, String teamName, String invitedUserId) async {
    try {
      final notification = Notification(
        id: _uuid.v4(),
        title: 'Invitation à rejoindre une équipe',
        message: 'Vous avez été invité à rejoindre l\'équipe "$teamName".',
        createdAt: DateTime.now(),
        type: NotificationType.projectInvitation,
        relatedId: teamId,
        userId: invitedUserId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification quand un projet est ajouté à une équipe
  Future<bool> createProjectAddedToTeamNotification({
    required String projectId,
    required String projectName,
    required String teamId,
    required String teamName,
    required String userId,
  }) async {
    try {
      final notification = Notification(
        id: _uuid.v4(),
        title: "Projet ajouté à l'équipe",
        message: "Le projet \"$projectName\" a été ajouté à l'équipe \"$teamName\".",
        createdAt: DateTime.now(),
        type: NotificationType.projectAddedToTeam,
        relatedId: projectId,
        userId: userId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification: $e');
      return false;
    }
  }

  // Créer une notification pour une alerte de budget du projet (ancienne méthode, maintenue pour compatibilité)
  Future<bool> createProjectBudgetAlertNotification(String projectId, String projectName, int thresholdPercentage, String userId) async {
    return createProjectBalanceAlertNotification(projectId, projectName, 0, userId);
  }
  
  // Créer une notification pour une alerte de solde négatif du projet
  Future<bool> createProjectBalanceAlertNotification(String projectId, String projectName, double balance, String userId) async {
    try {
      final notification = Notification(
        id: _uuid.v4(),
        title: 'Alerte solde négatif',
        message: 'Le projet "$projectName" a un solde négatif.',
        createdAt: DateTime.now(),
        type: NotificationType.projectBudgetAlert,
        relatedId: projectId,
        userId: userId,
      );
      
      await _supabase.from('notifications').insert(notification.toJson());
      return true;
    } catch (e) {
      print('Erreur lors de la création de la notification d\'alerte de solde: $e');
      return false;
    }
  }
}
