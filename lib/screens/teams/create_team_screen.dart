import 'package:flutter/material.dart';
import '../../models/team_model.dart';
import '../../services/team_service/team_service.dart';
import '../../services/role_service.dart';
import '../../widgets/islamic_patterns.dart';
import 'team_detail_screen.dart';
import '../../config/supabase_config.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TeamService _teamService = TeamService();
  final RoleService _roleService = RoleService();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasCreatePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    
    // Tracer les informations RBAC
    _logUserAccessInfo();
  }

  Future<void> _checkPermissions() async {
    try {
      final hasPermission = await _roleService.hasPermission('create_team');
      setState(() {
        _hasCreatePermission = hasPermission;
      });
      
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Vous n\'avez pas la permission de créer une équipe';
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
    }
  }
  
  /// Journalise les informations détaillées sur l'utilisateur pour le débogage RBAC
  Future<void> _logUserAccessInfo() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        print('ERREUR: CreateTeamScreen - Aucun utilisateur connecté');
        return;
      }
      
      print('\n===== INFORMATIONS D\'ACCÈS UTILISATEUR (CreateTeamScreen) =====');
      print('ID utilisateur: ${user.id}');
      print('Email: ${user.email}');
      
      // Vérifier spécifiquement la permission pour créer une équipe
      final hasCreateTeam = await _roleService.hasPermission('create_team');
      
      print('\nPermission "create_team" (création équipe): ${hasCreateTeam ? 'ACCORDÉE' : 'REFUSÉE'}');
      
      print('============================================================\n');
    } catch (e) {
      print('ERREUR lors de la récupération des informations d\'accès: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTeam() async {
    if (!_hasCreatePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous n\'avez pas la permission de créer une équipe')),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Récupérer l'ID de l'utilisateur actuel
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception("Utilisateur non connecté");
      }
      
      final team = Team(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: currentUser.id,  // Utiliser l'ID de l'utilisateur actuel
      );

      final createdTeam = await _teamService.createTeam(team);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Équipe "${createdTeam.name}" créée avec succès')),
        );
        
        // Naviguer vers l'écran de détail de l'équipe
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailScreen(team: createdTeam),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la création de l\'équipe: $e';
      });
      print(_errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une équipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec illustration
              Center(
                child: Column(
                  children: [
                    const IslamicPatternPlaceholder(
                      size: 120,
                      color: Color(0xFF1F4E5F),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Créer une nouvelle équipe',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Créez une équipe pour collaborer avec d\'autres utilisateurs sur des projets',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              
              // Affichage des erreurs
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Formulaire
              const Text(
                'Informations de l\'équipe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Nom de l'équipe
              TextFormField(
                controller: _nameController,
                enabled: _hasCreatePermission,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'équipe',
                  hintText: 'Ex: Équipe Marketing',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom d\'équipe';
                  }
                  if (value.trim().length < 3) {
                    return 'Le nom doit contenir au moins 3 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description de l'équipe
              TextFormField(
                controller: _descriptionController,
                enabled: _hasCreatePermission,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnelle)',
                  hintText: 'Ex: Équipe responsable des campagnes marketing',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              
              // Bouton de création
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_hasCreatePermission) ? null : _createTeam,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Créer l\'équipe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
