import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// Solution cross-platform pour le web
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../services/auth_service.dart';
import '../../services/project_service/project_service.dart';
import '../../services/phase_service/phase_service.dart';
import '../../services/team_service/team_service.dart';
import '../../services/csv_import_service.dart';
import '../../widgets/rbac_gated_screen.dart';
import '../../widgets/permission_gated.dart';

class TaskCsvImportScreen extends StatefulWidget {
  final String projectId;

  const TaskCsvImportScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<TaskCsvImportScreen> createState() => _TaskCsvImportScreenState();
}

class _TaskCsvImportScreenState extends State<TaskCsvImportScreen> {
  final ProjectService _projectService = ProjectService();
  final PhaseService _phaseService = PhaseService();
  final TeamService _teamService = TeamService();
  final AuthService _authService = AuthService();
  late final CsvImportService _csvImportService;

  // États de l'écran
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;
  
  // Données du fichier
  String? _fileName;
  String? _fileContent;
  List<String> _csvHeaders = [];
  List<Map<String, dynamic>> _previewData = [];
  
  // Mapping des colonnes
  final Map<String, String> _columnMapping = {
    'titre': '',
    'description': '',
    'priorite': '',
    'statut': '',
    'date_echeance': '',
    'phase_id': '',
    'sous_phase_id': '',
    'assigne_a': '',
    'equipe_id': '',
  };
  
  // Options d'importation
  bool _ignoreErrors = true;
  bool _generateReport = true;
  bool _notifyAssignees = false;
  
  // Résultats d'importation
  CsvImportResult? _importResult;
  
  @override
  void initState() {
    super.initState();
    _csvImportService = CsvImportService(
      projectService: _projectService,
      phaseService: _phaseService,
      teamService: _teamService,
      authService: _authService,
    );
  }
  
  // Sélectionner un fichier CSV
  Future<void> _pickCsvFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileBytes = file.bytes;
        
        if (fileBytes == null) {
          throw Exception('Impossible de lire le fichier');
        }
        
        final content = utf8.decode(fileBytes);
        
        setState(() {
          _fileName = file.name;
          _fileContent = content;
        });
        
        await _validateAndPreviewCsv();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection du fichier: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Valider et prévisualiser le fichier CSV
  Future<void> _validateAndPreviewCsv() async {
    if (_fileContent == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Valider le fichier et récupérer les en-têtes
      final headers = await _csvImportService.validateCsvFile(_fileContent!);
      
      // Prévisualiser les données
      final previewData = await _csvImportService.previewCsvData(_fileContent!, previewRows: 5);
      
      setState(() {
        _csvHeaders = headers;
        _previewData = previewData;
        
        // Initialiser le mapping des colonnes automatiquement si possible
        _initializeColumnMapping(headers);
      });
      
      // Passer à l'étape suivante
      setState(() {
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la validation du fichier: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Initialiser automatiquement le mapping des colonnes
  void _initializeColumnMapping(List<String> headers) {
    final normalizedHeaders = headers.map((h) => h.toLowerCase().trim()).toList();
    
    // Correspondances possibles pour chaque champ
    final fieldMappings = {
      'titre': ['titre', 'title', 'name', 'nom', 'tache', 'task'],
      'description': ['description', 'desc', 'details', 'détails', 'contenu', 'content'],
      'priorite': ['priorite', 'priorité', 'priority', 'importance', 'niveau', 'level'],
      'statut': ['statut', 'status', 'etat', 'état', 'avancement', 'progress'],
      'date_echeance': ['date_echeance', 'date d\'échéance', 'due_date', 'date_limite', 'deadline', 'echeance', 'échéance'],
      'phase_id': ['phase_id', 'phase', 'id_phase', 'etape', 'étape'],
      'sous_phase_id': ['sous_phase_id', 'sous_phase', 'sub_phase', 'subphase', 'sous-phase'],
      'assigne_a': ['assigne_a', 'assigné à', 'assigned_to', 'user', 'utilisateur', 'responsable'],
      'equipe_id': ['equipe_id', 'équipe', 'team', 'team_id', 'groupe', 'group'],
    };
    
    // Pour chaque champ à mapper
    for (final field in _columnMapping.keys) {
      // Chercher une correspondance dans les en-têtes
      for (int i = 0; i < normalizedHeaders.length; i++) {
        final header = normalizedHeaders[i];
        final possibleMatches = fieldMappings[field]!;
        
        if (possibleMatches.contains(header)) {
          _columnMapping[field] = headers[i];
          break;
        }
      }
    }
  }
  
  // Lancer l'importation des tâches
  Future<void> _importTasks() async {
    if (_fileContent == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _importResult = null;
    });
    
    try {
      final result = await _csvImportService.importTasks(
        _fileContent!,
        widget.projectId,
        _columnMapping,
      );
      
      setState(() {
        _importResult = result;
        _currentStep = 2;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'importation: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Méthode pour exporter un fichier CSV
  Future<void> _exportCsv() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      // Générer le contenu CSV
      final csvContent = await _csvImportService.generateCsvFromTasks(widget.projectId);
      final fileName = 'tasks_template.csv';
      
      if (kIsWeb) {
        // Solution pour le web utilisant universal_html (compatible avec iOS)
        final bytes = utf8.encode(csvContent);
        
        // Créer un objet Blob depuis les données CSV
        final blob = html.Blob([bytes], 'text/csv');
        
        // Créer une URL pour le Blob
        final url = html.Url.createObjectUrlFromBlob(blob);
        
        // Créer un lien invisible et simuler un clic pour le téléchargement
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        
        // Ajouter l'élément au DOM, cliquer, puis le retirer
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        
        // Libérer l'URL
        html.Url.revokeObjectUrl(url);
      } else {
        // Solution pour mobile et desktop
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csvContent);
        
        // Partager le fichier avec d'autres applications
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Modèle de tâches CSV',
        );
      }
      
      // Afficher une confirmation 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modèle CSV téléchargé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'exportation: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RbacGatedScreen(
      permissionName: 'create_task',
      projectId: widget.projectId,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Importation de tâches CSV'),
          actions: [
            // Bouton d'exportation de CSV
            IconButton(
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              tooltip: 'Exporter un modèle CSV',
              onPressed: _isExporting ? null : _exportCsv,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }
  
  Widget _buildContent() {
    return Column(
      children: [
        // Section d'information sur l'exportation
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comment utiliser cette fonctionnalité ?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Exportez un modèle CSV en cliquant sur l\'icône de téléchargement en haut à droite'
                    '\n2. Modifiez le fichier CSV avec vos tâches'
                    '\n3. Importez le fichier CSV modifié en suivant les étapes ci-dessous',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Note: Le modèle contiendra les 5 premières tâches existantes ou des exemples si aucune tâche n\'existe.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Étapes d'importation
        Expanded(
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: () async {
              if (_currentStep == 0) {
                if (_fileContent == null) {
                  _pickCsvFile();
                } else {
                  setState(() {
                    _currentStep = 1;
                  });
                }
              } else if (_currentStep == 1) {
                await _importTasks();
              } else if (_currentStep == 2) {
                Navigator.of(context).pop();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
            steps: [
              Step(
                title: const Text('Sélection du fichier CSV'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sélectionnez un fichier CSV contenant les tâches à importer.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _pickCsvFile,
                      child: Text(_fileName == null ? 'Sélectionner un fichier' : 'Changer de fichier'),
                    ),
                    if (_fileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Fichier sélectionné: $_fileName'),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                isActive: _currentStep == 0,
              ),
              Step(
                title: const Text('Prévisualisation et mappage'),
                content: _csvHeaders.isEmpty
                    ? Text('Veuillez d\'abord sélectionner un fichier CSV.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Prévisualisation des données:'),
                          const SizedBox(height: 8),
                          _buildPreviewTable(),
                          const SizedBox(height: 16),
                          const Text('Mappage des colonnes:'),
                          const SizedBox(height: 8),
                          _buildColumnMappingSection(),
                          const SizedBox(height: 16),
                          const Text('Options d\'importation:'),
                          const SizedBox(height: 8),
                          _buildImportOptions(),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                isActive: _currentStep == 1,
              ),
              Step(
                title: const Text('Résultats d\'importation'),
                content: _importResult == null
                    ? Text('L\'importation n\'a pas encore été effectuée.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Importation terminée!',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text('Lignes traitées: ${_importResult!.totalRows}'),
                          Text('Tâches importées avec succès: ${_importResult!.successCount}'),
                          Text('Lignes en erreur: ${_importResult!.errorCount}'),
                          if (_importResult!.errorCount > 0) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Erreurs rencontrées:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildErrorTable(),
                          ],
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                isActive: _currentStep == 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Construire le tableau de prévisualisation
  Widget _buildPreviewTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _csvHeaders.map((header) => DataColumn(label: Text(header))).toList(),
        rows: _previewData.map((row) {
          return DataRow(
            cells: _csvHeaders.map((header) {
              return DataCell(Text(row[header]?.toString() ?? ''));
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
  
  // Construire la section de mappage des colonnes
  Widget _buildColumnMappingSection() {
    return Column(
      children: _columnMapping.entries.map((entry) {
        final fieldName = entry.key;
        final mappedColumn = entry.value;
        
        // Traduire les noms de champs pour l'affichage
        final displayNames = {
          'titre': 'Titre',
          'description': 'Description',
          'priorite': 'Priorité',
          'statut': 'Statut',
          'date_echeance': 'Date d\'échéance',
          'phase_id': 'Phase',
          'sous_phase_id': 'Sous-phase',
          'assigne_a': 'Assigné à',
          'equipe_id': 'Équipe',
        };
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(displayNames[fieldName] ?? fieldName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  value: mappedColumn.isNotEmpty ? mappedColumn : null,
                  hint: Text('Sélectionner une colonne'),
                  items: [
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text('- Non utilisé -'),
                    ),
                    ..._csvHeaders.map((header) {
                      return DropdownMenuItem<String>(
                        value: header,
                        child: Text(header),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _columnMapping[fieldName] = value ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  // Construire les options d'importation
  Widget _buildImportOptions() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Ignorer les lignes en erreur'),
          subtitle: const Text('Continuer l\'importation même en cas d\'erreur sur certaines lignes'),
          value: _ignoreErrors,
          onChanged: (value) {
            setState(() {
              _ignoreErrors = value ?? true;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Générer un rapport détaillé'),
          subtitle: const Text('Produire un rapport d\'importation complet'),
          value: _generateReport,
          onChanged: (value) {
            setState(() {
              _generateReport = value ?? true;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Notifier les utilisateurs assignés'),
          subtitle: const Text('Envoyer des notifications aux utilisateurs assignés aux tâches'),
          value: _notifyAssignees,
          onChanged: (value) {
            setState(() {
              _notifyAssignees = value ?? false;
            });
          },
        ),
      ],
    );
  }
  
  // Construire le tableau des erreurs
  Widget _buildErrorTable() {
    if (_importResult == null || _importResult!.errorRows.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Limiter l'affichage des erreurs pour les performances
    final maxErrorsToShow = 10;
    final errorsToShow = _importResult!.errorRows.length > maxErrorsToShow 
        ? _importResult!.errorRows.sublist(0, maxErrorsToShow) 
        : _importResult!.errorRows;
    final errorMessages = _importResult!.errorMessages.length > maxErrorsToShow 
        ? _importResult!.errorMessages.sublist(0, maxErrorsToShow) 
        : _importResult!.errorMessages;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Erreur')),
          ..._csvHeaders.map((header) => DataColumn(label: Text(header))).toList(),
        ],
        rows: List.generate(errorsToShow.length, (index) {
          final row = errorsToShow[index];
          final errorMessage = index < errorMessages.length ? errorMessages[index] : 'Erreur inconnue';
          
          return DataRow(
            cells: [
              DataCell(Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              )),
              ..._csvHeaders.map((header) {
                return DataCell(Text(row[header]?.toString() ?? ''));
              }).toList(),
            ],
          );
        }).toList(),
      ),
    );
  }
}