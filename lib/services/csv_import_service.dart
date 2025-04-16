import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/phase_model.dart';
import '../models/team_model.dart';
import '../services/project_service/project_service.dart';
import '../services/phase_service/phase_service.dart';
import '../services/team_service/team_service.dart';
import '../services/auth_service.dart';
import '../config/supabase_config.dart';

class CsvImportResult {
  final int totalRows;
  final int successCount;
  final int errorCount;
  final List<Map<String, dynamic>> successRows;
  final List<Map<String, dynamic>> errorRows;
  final List<String> errorMessages;

  CsvImportResult({
    required this.totalRows,
    required this.successCount,
    required this.errorCount,
    required this.successRows,
    required this.errorRows,
    required this.errorMessages,
  });
}

class CsvTaskData {
  final String title;
  final String description;
  final int priority;
  final String status;
  final DateTime? dueDate;
  final String? phaseId;
  final String? subPhaseId;
  final String? assignedTo;
  final String? teamId;

  CsvTaskData({
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.phaseId,
    this.subPhaseId,
    this.assignedTo,
    this.teamId,
  });

  factory CsvTaskData.fromMap(Map<String, dynamic> map, Map<String, String> columnMapping) {
    // Récupérer les valeurs en utilisant le mapping des colonnes
    String getValueFromMapping(String fieldName) {
      final column = columnMapping[fieldName];
      if (column == null) return '';
      return map[column]?.toString() ?? '';
    }
    
    // Convertir la priorité
    int parsePriority(String value) {
      if (value.isEmpty) return TaskPriority.medium.value;
      
      // Nouveau format: "Nom (valeur)" - extraire la valeur entre parenthèses
      final regex = RegExp(r'\((\d+)\)');
      final match = regex.firstMatch(value);
      if (match != null && match.groupCount >= 1) {
        final extractedValue = int.tryParse(match.group(1) ?? '');
        if (extractedValue != null && extractedValue >= 0 && extractedValue <= 3) {
          return extractedValue;
        }
      }
      
      // Essayer de parser comme nombre
      final intValue = int.tryParse(value);
      if (intValue != null) {
        if (intValue >= 0 && intValue <= 3) return intValue;
        return TaskPriority.medium.value;
      }
      
      // Essayer de matcher par nom
      final lowerValue = value.toLowerCase();
      if (lowerValue.contains('urgent') || lowerValue == '3') {
        return TaskPriority.urgent.value;
      } else if (lowerValue.contains('haut') || lowerValue.contains('high') || lowerValue == '2') {
        return TaskPriority.high.value;
      } else if (lowerValue.contains('moyen') || lowerValue.contains('medium') || lowerValue == '1') {
        return TaskPriority.medium.value;
      } else if (lowerValue.contains('faible') || lowerValue.contains('basse') || lowerValue.contains('low') || lowerValue == '0') {
        return TaskPriority.low.value;
      } else {
        return TaskPriority.medium.value;
      }
    }
    
    // Convertir le statut
    String parseStatus(String value) {
      if (value.isEmpty) return TaskStatus.todo.name;
      
      // Valeurs lisibles exactes comme exportées
      if (value == 'À faire') return TaskStatus.todo.name;
      if (value == 'En cours') return TaskStatus.inProgress.name;
      if (value == 'En revue') return TaskStatus.review.name;
      if (value == 'Terminée') return TaskStatus.completed.name;
      
      // Essayer de matcher par nom
      final lowerValue = value.toLowerCase();
      if (lowerValue.contains('faire') || lowerValue.contains('todo') || lowerValue.contains('new') || lowerValue.contains('nouv')) {
        return TaskStatus.todo.name;
      } else if (lowerValue.contains('cours') || lowerValue.contains('progress')) {
        return TaskStatus.inProgress.name;
      } else if (lowerValue.contains('revue') || lowerValue.contains('review')) {
        return TaskStatus.review.name;
      } else if (lowerValue.contains('termin') || lowerValue.contains('done') || lowerValue.contains('complet')) {
        return TaskStatus.completed.name;
      } else if (lowerValue.contains('bloqu') || lowerValue.contains('block')) {
        return TaskStatus.todo.name; // Pas de statut bloqué, utiliser todo par défaut
      } else {
        // Essayer la valeur exacte pour les cas où c'est déjà l'enum
        try {
          TaskStatus.fromValue(value);
          return value; // Si aucune exception, c'est un statut valide
        } catch (_) {
          return TaskStatus.todo.name; // Valeur par défaut
        }
      }
    }
    
    // Parser la date
    DateTime? parseDate(String value) {
      if (value.isEmpty) return null;
      
      try {
        // Essayer plusieurs formats de date
        // Format ISO
        if (value.contains('T')) {
          return DateTime.parse(value);
        }
        
        // Format YYYY-MM-DD
        if (value.contains('-') && value.split('-').length == 3) {
          return DateTime.parse(value);
        }
        
        // Format DD/MM/YYYY
        if (value.contains('/')) {
          final parts = value.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            return DateTime(year, month, day);
          }
        }
        
        return null;
      } catch (e) {
        print('Erreur lors du parsing de la date: $e');
        return null;
      }
    }

    // Récupérer et traiter les valeurs
    final phaseValue = getValueFromMapping('phase').isNotEmpty 
        ? getValueFromMapping('phase') 
        : getValueFromMapping('phase_id'); // Support des deux formats
        
    final subPhaseValue = getValueFromMapping('sous_phase').isNotEmpty 
        ? getValueFromMapping('sous_phase') 
        : getValueFromMapping('sous_phase_id'); // Support des deux formats
        
    // Gestion spéciale pour l'assignation utilisateur : si vide, retourner null
    String? assignedToValue = getValueFromMapping('assigne_a');
    if (assignedToValue.isEmpty) {
      assignedToValue = null; // Assurer que c'est null et non une chaîne vide
    }
    
    final teamValue = getValueFromMapping('equipe').isNotEmpty 
        ? getValueFromMapping('equipe') 
        : getValueFromMapping('equipe_id'); // Support des deux formats
    
    return CsvTaskData(
      title: getValueFromMapping('titre').isNotEmpty 
          ? getValueFromMapping('titre') 
          : 'Tâche importée ${DateTime.now().toIso8601String()}',
      description: getValueFromMapping('description'),
      priority: parsePriority(getValueFromMapping('priorite')),
      status: parseStatus(getValueFromMapping('statut')),
      dueDate: parseDate(getValueFromMapping('date_echeance')),
      phaseId: phaseValue,  // On garde la valeur lisible pour la résolution ultérieure
      subPhaseId: subPhaseValue, // On garde la valeur lisible pour la résolution ultérieure
      assignedTo: assignedToValue, // On garde la valeur lisible pour la résolution ultérieure
      teamId: teamValue,
    );
  }
  
  // Convertir en modèle Task
  Task toTaskModel(String projectId, String createdBy) {
    return Task(
      id: const Uuid().v4(),
      projectId: projectId,
      title: title,
      description: description,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      status: status,
      priority: priority,
      dueDate: dueDate,
      phaseId: phaseId?.isEmpty == true ? null : phaseId,
      subPhaseId: subPhaseId?.isEmpty == true ? null : subPhaseId,
      assignedTo: assignedTo?.isEmpty == true ? null : assignedTo,
    );
  }
}

class CsvImportService {
  final ProjectService _projectService;
  final PhaseService _phaseService;
  final TeamService _teamService;
  final AuthService _authService;
  final SupabaseClient _supabaseClient = SupabaseConfig.client;

  // Résoudre les noms en UUIDs pour les phases, équipes et utilisateurs
  Future<String?> _resolveNameToUuid(String? value, String type, String projectId) async {
    if (value == null || value.isEmpty) return null;

    try {
      // Si la valeur est déjà un UUID valide, la retourner directement
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      if (uuidRegex.hasMatch(value)) return value;
      
      switch (type) {
        case 'phase':
          // Récupérer les phases du projet et trouver celle qui correspond au nom
          final projectPhases = await _phaseService.getPhasesByProject(projectId);
          Phase? matchingPhase;
          try {
            matchingPhase = projectPhases.firstWhere(
              (phase) => phase.name.toLowerCase() == value.toLowerCase(),
            );
          } catch (_) {
            matchingPhase = null;
          }
          return matchingPhase?.id;
          
        case 'subphase':
          // Parcourir toutes les phases du projet et leurs sous-phases
          final projectPhases = await _phaseService.getPhasesByProject(projectId);
          for (final phase in projectPhases) {
            final subphases = await _phaseService.getSubPhasesByParentId(phase.id);
            Phase? matchingSubphase;
            try {
              matchingSubphase = subphases.firstWhere(
                (subphase) => subphase.name.toLowerCase() == value.toLowerCase(),
              );
            } catch (_) {
              matchingSubphase = null;
            }
            if (matchingSubphase != null) return matchingSubphase.id;
          }
          return null;
          
        case 'team':
          // Récupérer les équipes du projet et trouver celle qui correspond au nom
          final teams = await _teamService.getTeamsByProject(projectId);
          Team? matchingTeam;
          try {
            matchingTeam = teams.firstWhere(
              (team) => team.name.toLowerCase() == value.toLowerCase(),
            );
          } catch (_) {
            matchingTeam = null;
          }
          return matchingTeam?.id;
          
        case 'user':
          // Pour les utilisateurs, c'est plus complexe car nous devons chercher par nom d'affichage
          // Utiliser une requête Supabase directe pour rechercher les utilisateurs par nom
          try {
            final response = await _supabaseClient
              .from('profiles')
              .select('id')
              .ilike('display_name', value)
              .limit(1)
              .single();
              
            if (response != null) {
              return response['id'] as String?;
            }
          } catch (e) {
            print('Erreur lors de la recherche d\'utilisateur par nom: $e');
          }
          return null;
          
        default:
          return value;
      }
    } catch (e) {
      print('Erreur lors de la résolution du nom en UUID: $e');
      return null;
    }
  }
  
  CsvImportService({
    ProjectService? projectService,
    PhaseService? phaseService,
    TeamService? teamService,
    AuthService? authService,
  }) : _projectService = projectService ?? ProjectService(),
       _phaseService = phaseService ?? PhaseService(),
       _teamService = teamService ?? TeamService(),
       _authService = authService ?? AuthService();
  
  // Valider le fichier CSV et extraire les en-têtes
  Future<List<String>> validateCsvFile(String csvContent) async {
    try {
      // Supprimer le BOM UTF-8 s'il est présent au début du fichier
      if (csvContent.startsWith('\uFEFF')) {
        csvContent = csvContent.substring(1);
      }
      
      final lines = LineSplitter.split(csvContent).toList();
      if (lines.isEmpty) {
        throw Exception('Le fichier CSV est vide');
      }
      
      // Utiliser notre parseur de CSV personnalisé pour gérer correctement les guillemets et accents
      final headers = _parseCSVLine(lines.first);
      if (headers.isEmpty) {
        throw Exception('L\'en-tête du fichier CSV est invalide');
      }
      
      // Vérifier les en-têtes minimaux requis
      if (!headers.any((h) => h.trim().toLowerCase() == 'titre')) {
        throw Exception('Le fichier CSV doit contenir une colonne "titre"');
      }
      
      print('Le fichier CSV est valide. ${lines.length - 1} lignes de données trouvées.');
      return headers;
    } catch (e) {
      print('Erreur lors de la validation du fichier CSV: $e');
      rethrow;
    }
  }
  
  // Prévisualiser les données CSV
  Future<List<Map<String, dynamic>>> previewCsvData(
    String csvContent, 
    {int previewRows = 5}
  ) async {
    try {
      // Supprimer le BOM UTF-8 s'il est présent au début du fichier
      if (csvContent.startsWith('\uFEFF')) {
        csvContent = csvContent.substring(1);
      }
      
      final lines = LineSplitter.split(csvContent).toList();
      if (lines.isEmpty) {
        return [];
      }
      
      // Utiliser notre parseur de CSV personnalisé pour gérer correctement les guillemets et accents
      final headers = _parseCSVLine(lines.first);
      
      final result = <Map<String, dynamic>>[];
      
      // Limiter le nombre de lignes à prévisualiser
      final dataLines = lines.sublist(1, lines.length > previewRows + 1 
          ? previewRows + 1 
          : lines.length);
      
      for (final line in dataLines) {
        final values = _parseCSVLine(line);
        if (values.length != headers.length) {
          // Ajuster les valeurs pour correspondre au nombre d'en-têtes
          if (values.length < headers.length) {
            values.addAll(List.filled(headers.length - values.length, ''));
          } else {
            values.removeRange(headers.length, values.length);
          }
        }
        
        final Map<String, dynamic> rowData = {};
        for (int i = 0; i < headers.length; i++) {
          rowData[headers[i]] = values[i];
        }
        
        result.add(rowData);
      }
      
      return result;
    } catch (e) {
      print('Erreur lors de la prévisualisation des données CSV: $e');
      rethrow;
    }
  }
  
  // Fonction pour parser une ligne CSV en tenant compte des guillemets et des accents
  List<String> _parseCSVLine(String line) {
    // Filtrer le caractère BOM UTF-8 s'il est présent au début de la ligne
    if (line.startsWith('\uFEFF')) {
      line = line.substring(1);
    }
    
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer field = StringBuffer();
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        // Toggle l'état "entre guillemets"
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        // Si on trouve une virgule hors guillemets, c'est un séparateur de champ
        result.add(field.toString().trim().replaceAll('"', ''));
        field = StringBuffer();
      } else {
        // Ajouter le caractère courant au champ
        field.write(char);
      }
    }
    
    // Ajouter le dernier champ
    result.add(field.toString().trim().replaceAll('"', ''));
    
    return result;
  }
  
  // Importer les tâches depuis le CSV
  Future<CsvImportResult> importTasks(
    String csvContent,
    String projectId,
    Map<String, String> columnMapping,
    {int batchSize = 50}
  ) async {
    try {
      final currentUserId = await _authService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Supprimer le BOM UTF-8 s'il est présent au début du fichier
      if (csvContent.startsWith('\uFEFF')) {
        csvContent = csvContent.substring(1);
      }
      
      final lines = LineSplitter.split(csvContent).toList();
      if (lines.length < 2) {
        throw Exception('Le fichier CSV ne contient pas de données');
      }
      
      // Ignorer l'en-tête et traiter les lignes de données
      final dataLines = lines.sublist(1);
      final totalRows = dataLines.length;
      
      // Vérifier que les phases existent
      final phases = await _phaseService.getPhasesByProject(projectId);
      final phaseIds = phases.map((phase) => phase.id).toSet();
      
      // Vérifier que les équipes existent
      final teams = await _teamService.getTeamsByProject(projectId);
      final teamIds = teams.map((team) => team.id).toSet();
      
      // Résultats
      final successRows = <Map<String, dynamic>>[];
      final errorRows = <Map<String, dynamic>>[];
      final errorMessages = <String>[];
      
      // Traitement par lots
      for (int i = 0; i < dataLines.length; i += batchSize) {
        final end = (i + batchSize < dataLines.length) ? i + batchSize : dataLines.length;
        final batch = dataLines.sublist(i, end);
        
        // Traiter chaque ligne dans le lot
        for (final line in batch) {
          try {
            final values = _parseCSVLine(line);
            final headers = _parseCSVLine(lines.first);
            
            // Créer un map de la ligne
            final Map<String, dynamic> rowData = {};
            for (int j = 0; j < headers.length && j < values.length; j++) {
              rowData[headers[j]] = values[j];
            }
            
            // Convertir en données de tâche
            final taskData = CsvTaskData.fromMap(rowData, columnMapping);
            
            // Valider les données
            if (taskData.title.isEmpty) {
              throw Exception('Le titre de la tâche est requis');
            }
            
            // Résoudre les références par nom en UUIDs avant de créer la tâche
            final resolvedPhaseId = await _resolveNameToUuid(taskData.phaseId, 'phase', projectId) 
                ?? taskData.phaseId;
            
            final resolvedSubPhaseId = await _resolveNameToUuid(taskData.subPhaseId, 'subphase', projectId)
                ?? taskData.subPhaseId;
            
            final resolvedAssignedTo = await _resolveNameToUuid(taskData.assignedTo, 'user', projectId)
                ?? taskData.assignedTo;
                
            final resolvedTeamId = await _resolveNameToUuid(taskData.teamId, 'team', projectId)
                ?? taskData.teamId;
            
            // Valider les ID après la résolution
            if (resolvedPhaseId != null && resolvedPhaseId.isNotEmpty && !phaseIds.contains(resolvedPhaseId)) {
              throw Exception('La phase spécifiée n\'existe pas dans ce projet. ' + 
                             'Nom/ID fourni: ${taskData.phaseId}');
            }
            
            if (resolvedTeamId != null && resolvedTeamId.isNotEmpty && !teamIds.contains(resolvedTeamId)) {
              throw Exception('L\'équipe spécifiée n\'existe pas dans ce projet. ' + 
                             'Nom/ID fourni: ${taskData.teamId}');
            }
            
            // Créer un modèle de tâche avec les UUIDs résolus
            final task = taskData.toTaskModel(projectId, currentUserId);
            
            // Mettre à jour les ID résolus
            final updatedTask = task.copyWith(
              phaseId: resolvedPhaseId,
              subPhaseId: resolvedSubPhaseId,
              assignedTo: resolvedAssignedTo
            );
            
            // Créer la tâche
            final createdTask = await _projectService.createTask(updatedTask);
            
            // Si une équipe est spécifiée, créer l'association
            if (taskData.teamId != null && taskData.teamId!.isNotEmpty) {
              // Utiliser l'ID d'équipe déjà résolu
              final teamId = resolvedTeamId;
              if (teamId != null) {
                await _teamService.assignTaskToTeam(createdTask.id, teamId);
              }
            }
            
            // Ajouter aux réussites
            successRows.add(rowData);
          } catch (e) {
            print('Erreur lors de l\'importation de la ligne: $e');
            
            // Créer un map de la ligne
            final values = _parseCSVLine(line);
            final headers = _parseCSVLine(lines.first);
            
            final Map<String, dynamic> rowData = {};
            for (int j = 0; j < headers.length && j < values.length; j++) {
              rowData[headers[j]] = values[j];
            }
            
            errorRows.add(rowData);
            errorMessages.add(e.toString());
          }
        }
      }
      
      return CsvImportResult(
        totalRows: totalRows,
        successCount: successRows.length,
        errorCount: errorRows.length,
        successRows: successRows,
        errorRows: errorRows,
        errorMessages: errorMessages,
      );
    } catch (e) {
      print('Erreur lors de l\'importation des tâches: $e');
      rethrow;
    }
  }
  
  // Convertir les données CSV en modèles de tâche
  List<Task> convertCsvToTasks(
    List<Map<String, dynamic>> csvData,
    String projectId,
    String createdBy,
    Map<String, String> columnMapping,
  ) {
    final tasks = <Task>[];
    
    for (final row in csvData) {
      try {
        final taskData = CsvTaskData.fromMap(row, columnMapping);
        final task = taskData.toTaskModel(projectId, createdBy);
        tasks.add(task);
      } catch (e) {
        print('Erreur lors de la conversion de la ligne en tâche: $e');
        // Continuer avec la prochaine ligne
      }
    }
    
    return tasks;
  }
  
  // Récupérer les vrais noms d'utilisateurs depuis Supabase
  Future<Map<String, String>> _getRealUserNames(List<String> userIds) async {
    final Map<String, String> userDisplayNames = {};
    
    if (userIds.isEmpty) return userDisplayNames;
    
    try {
      // Approche simple : récupérer individuellement les informations de chaque utilisateur
      for (final id in userIds) {
        try {
          // Récupérer un seul profil à la fois pour éviter les problèmes de syntaxe
          final data = await _supabaseClient
              .from('profiles')
              .select('id, display_name, email')
              .eq('id', id)
              .single();
          
          if (data != null) {
            String displayName = data['display_name'] as String? ?? '';
            
            // Si le nom d'affichage est vide, utiliser l'email ou un nom générique
            if (displayName.isEmpty) {
              final email = data['email'] as String? ?? '';
              displayName = email.isNotEmpty ? email : 'Utilisateur-${id.substring(0, 8)}';
            }
            
            userDisplayNames[id] = displayName;
          } else {
            // Fallback si aucune donnée n'est trouvée
            userDisplayNames[id] = 'Utilisateur-${id.substring(0, 8)}';
          }
        } catch (e) {
          print('Erreur lors de la récupération du profil $id: $e');
          // Fallback en cas d'erreur
          userDisplayNames[id] = 'Utilisateur-${id.length >= 8 ? id.substring(0, 8) : id}';
        }
      }
      
      return userDisplayNames;
    } catch (e) {
      print('Exception lors de la récupération des noms d\'utilisateurs: $e');
      
      // En cas d'erreur, revenir à la méthode de secours avec des noms génériques
      for (final id in userIds) {
        if (id.length >= 8) {
          userDisplayNames[id] = 'Utilisateur-${id.substring(0, 8)}';
        } else {
          userDisplayNames[id] = 'Utilisateur-$id';
        }
      }
      
      return userDisplayNames;
    }
  }
  
  // Générer un fichier CSV à partir des tâches existantes
  Future<String> generateCsvFromTasks(String projectId, {int limit = 5}) async {
    try {
      // Récupérer les tâches du projet
      final tasks = await _projectService.getTasksByProject(projectId);
      
      // Récupérer les informations sur les phases
      final phases = await _phaseService.getPhasesByProject(projectId);
      final subPhases = <String, Phase>{};
      for (final phase in phases) {
        final phaseSubPhases = await _phaseService.getSubPhasesByParentId(phase.id);
        for (final subPhase in phaseSubPhases) {
          subPhases[subPhase.id] = subPhase;
        }
      }
      
      // Récupérer les informations sur les utilisateurs assignés
      final userIds = tasks.where((t) => t.assignedTo != null).map((t) => t.assignedTo!).toSet().toList();
      final userDisplayNames = await _getRealUserNames(userIds);
      
      // Limiter le nombre de tâches si nécessaire
      final limitedTasks = tasks.length > limit ? tasks.sublist(0, limit) : tasks;
      
      if (limitedTasks.isEmpty) {
        // Générer des exemples si aucune tâche n'existe
        return _generateSampleCsv(projectId);
      }
      
      // Entêtes du CSV
      final headers = [
        'titre',
        'description',
        'priorite',
        'statut',
        'date_echeance',
        'phase', // Renommé pour plus de clarté
        'sous_phase', // Renommé pour plus de clarté
        'assigne_a',
        'equipe'
      ];
      
      // Lignes de données
      final rows = <List<String>>[];
      rows.add(headers);
      
      // Convertir chaque tâche en ligne CSV
      for (final task in limitedTasks) {
        // Récupérer l'ID et le nom de l'équipe si la tâche est assignée à une équipe
        String? teamName;
        if (task.assignedTo == null) {
          final teams = await _teamService.getTeamsByTask(task.id);
          teamName = teams.isNotEmpty ? teams.first.name : null;
        }
        
        // Trouver les noms des phases (sans UUID)
        String phaseName = '';
        String subPhaseName = '';
        
        if (task.phaseId != null) {
          // Rechercher la phase par ID
          final phaseMatches = phases.where((p) => p.id == task.phaseId).toList();
          if (phaseMatches.isNotEmpty) {
            final phase = phaseMatches.first;
            phaseName = phase.name; // Afficher uniquement le nom
          } else {
            phaseName = task.phaseId ?? '';
          }
        }
        
        if (task.subPhaseId != null) {
          final subPhase = subPhases[task.subPhaseId];
          if (subPhase != null) {
            subPhaseName = subPhase.name; // Afficher uniquement le nom
          } else {
            subPhaseName = task.subPhaseId ?? '';
          }
        }
        
        // Afficher uniquement le nom lisible pour l'utilisateur assigné
        String assignedToDisplay = '';
        if (task.assignedTo != null) {
          final displayName = userDisplayNames[task.assignedTo];
          if (displayName != null && displayName.isNotEmpty) {
            assignedToDisplay = displayName;
          } else {
            assignedToDisplay = task.assignedTo ?? '';
          }
        }
        
        // Convertir la priorité numérique en texte lisible
        String priorityText = '';
        try {
          final priorityEnum = TaskPriority.fromValue(task.priority);
          priorityText = '${priorityEnum.displayName} (${task.priority})';
        } catch (e) {
          priorityText = task.priority.toString();
        }
        
        final row = [
          task.title,
          task.description,
          priorityText,
          TaskStatus.fromValue(task.status).displayName, // Statut lisible
          task.dueDate?.toIso8601String() ?? '',
          phaseName,
          subPhaseName,
          assignedToDisplay,
          teamName ?? ''
        ];
        
        rows.add(row);
      }
      
      // Convertir en CSV
      return _convertToCsv(rows);
    } catch (e) {
      print('Erreur lors de la génération du CSV: $e');
      // En cas d'erreur, retourner le CSV d'exemple
      return _generateSampleCsv(projectId);
    }
  }
  
  // Générer un exemple de CSV
  String _generateSampleCsv(String projectId) {
    final headers = [
      'titre',
      'description',
      'priorite',
      'statut',
      'date_echeance',
      'phase',
      'sous_phase',
      'assigne_a',
      'equipe'
    ];
    
    final rows = <List<String>>[];
    rows.add(headers);
    
    // Exemple de tâches avec des valeurs plus explicites, sans UUID
    rows.add(['“Configuration serveur”', '“Installer et configurer l\'environnement de test”', 'Haute (2)', 'À faire', '2025-05-15', 'Phase initiale', '', '', '']);
    rows.add(['“Mise à jour documentation”', '“Préparation des nouveaux documents”', 'Moyenne (1)', 'En cours', '2025-04-30', 'Phase initiale', 'Documentation', 'Jean Dupont', '']);
    rows.add(['“Correction bug #123”', '“Résoudre problème d\'authentification”', 'Urgente (3)', 'En revue', '', 'Phase Dev', 'Bugs', '', 'Équipe Dev']);
    rows.add(['“Optimisation base de données”', '“Réduire le temps de réponse des requêtes”', 'Haute (2)', 'À faire', '2025-06-10', 'Phase Performance', '', '', '']);
    rows.add(['“Refactoring du code”', '“Améliorer la qualité du code selon les standards”', 'Moyenne (1)', 'À faire', '', 'Phase Dev', 'Qualité', 'Marie Martin', '']);
    
    return _convertToCsv(rows);
  }
  
  // Convertir les lignes en format CSV avec encodage UTF-8
  String _convertToCsv(List<List<String>> rows) {
    // Ajouter le BOM UTF-8 au début du fichier pour garantir que les accents soient bien interprétés
    final bom = '\uFEFF';
    
    final csvContent = rows.map((row) {
      return row.map((cell) {
        // Échapper les guillemets et entourer de guillemets si nécessaire
        // Toujours entourer de guillemets si la cellule contient des caractères accentués
        if (cell.contains('"') || cell.contains(',') || cell.contains('\n') || 
            _containsAccents(cell)) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(',');
    }).join('\n');
    
    return bom + csvContent;
  }
  
  // Vérifier si une chaîne contient des caractères accentués
  bool _containsAccents(String text) {
    final accentedChars = RegExp(r'[À-ÿ]');
    return accentedChars.hasMatch(text);
  }
}
