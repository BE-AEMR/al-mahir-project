import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_comment_model.dart';

class TaskCommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<TaskComment>> getCommentsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('task_comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: true);

      return response.map<TaskComment>((data) => TaskComment.fromJson(data)).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des commentaires: $e');
    }
  }

  Future<TaskComment> addComment(String taskId, String comment) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now().toUtc().toIso8601String();

      final data = {
        'task_id': taskId,
        'user_id': userId,
        'comment': comment,
        'created_at': now,
      };

      final response = await _supabase
          .from('task_comments')
          .insert(data)
          .select()
          .single();

      return TaskComment.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du commentaire: $e');
    }
  }

  Future<TaskComment> updateComment(String commentId, String newComment) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final data = {
        'comment': newComment,
        'updated_at': now,
      };

      final response = await _supabase
          .from('task_comments')
          .update(data)
          .eq('id', commentId)
          .select()
          .single();

      return TaskComment.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du commentaire: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('task_comments')
          .delete()
          .eq('id', commentId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du commentaire: $e');
    }
  }
}
