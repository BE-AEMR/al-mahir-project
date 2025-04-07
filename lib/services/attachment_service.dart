import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/attachment_model.dart';

class AttachmentService {
  final _supabase = Supabase.instance.client;
  final _uuid = Uuid();
  final String _bucketName = 'task-attachments';

  // Récupérer toutes les pièces jointes d'une tâche
  Future<List<Attachment>> getAttachmentsByTask(String taskId) async {
    try {
      final response = await _supabase
          .from('attachments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);

      return response.map<Attachment>((json) => Attachment.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des pièces jointes: $e');
      rethrow;
    }
  }

  // Télécharger une image depuis la galerie
  Future<Attachment?> uploadImageFromGallery(String taskId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80, // Compression de l'image pour réduire la taille
      );

      if (image == null) return null;
      
      return await _uploadFile(taskId, File(image.path), p.basename(image.path));
    } catch (e) {
      debugPrint('Erreur lors du téléchargement de l\'image depuis la galerie: $e');
      rethrow;
    }
  }

  // Prendre une photo avec la caméra
  Future<Attachment?> takePhoto(String taskId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compression de l'image pour réduire la taille
      );

      if (photo == null) return null;
      
      return await _uploadFile(taskId, File(photo.path), 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
    } catch (e) {
      debugPrint('Erreur lors de la prise de photo: $e');
      rethrow;
    }
  }

  // Télécharger un document
  Future<Attachment?> uploadDocument(String taskId) async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result == null || result.files.isEmpty) return null;
      
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      
      return await _uploadFile(taskId, file, fileName);
    } catch (e) {
      debugPrint('Erreur lors du téléchargement du document: $e');
      rethrow;
    }
  }

  // Fonction commune pour le téléchargement de fichiers
  Future<Attachment> _uploadFile(String taskId, File file, String fileName) async {
    try {
      final String fileId = _uuid.v4();
      final String userId = _supabase.auth.currentUser!.id;
      // Inclure l'ID utilisateur dans le chemin pour la politique RLS
      final String filePath = 'task_$taskId/$userId/$fileId/${p.basename(fileName)}';
      
      // Téléverser le fichier vers le stockage Supabase
      await _supabase
          .storage
          .from(_bucketName)
          .upload(filePath, file, fileOptions: const FileOptions(cacheControl: '3600'));

      // Obtenir l'URL publique du fichier
      final String fileUrl = _supabase
          .storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      // Créer l'entrée dans la base de données
      final Map<String, dynamic> attachmentData = {
        'id': fileId,
        'task_id': taskId,
        'name': fileName,
        'url': fileUrl,
        'path': filePath,
        'uploaded_by': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase
          .from('attachments')
          .insert(attachmentData);

      return Attachment.fromJson(attachmentData);
    } catch (e) {
      debugPrint('Erreur lors du téléchargement du fichier: $e');
      rethrow;
    }
  }

  // Supprimer une pièce jointe
  Future<void> deleteAttachment(Attachment attachment) async {
    try {
      // Supprimer le fichier du stockage
      await _supabase
          .storage
          .from(_bucketName)
          .remove([attachment.path]);

      // Supprimer l'entrée de la base de données
      await _supabase
          .from('attachments')
          .delete()
          .eq('id', attachment.id);
    } catch (e) {
      debugPrint('Erreur lors de la suppression de la pièce jointe: $e');
      rethrow;
    }
  }
}
