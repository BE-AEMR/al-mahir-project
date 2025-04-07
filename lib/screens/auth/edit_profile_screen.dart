import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../../widgets/snackbar_helper.dart';
import '../../models/country_code.dart';
import '../../widgets/country_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  CountryCode _selectedCountryCode = CountryCode.getAll().first;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Récupérer l'utilisateur actuel
      final user = _authService.currentUser;
      
      if (user == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }
      
      // Récupérer le profil depuis la base de données
      final profile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
        
      // Remplir les contrôleurs avec les données existantes
      if (profile != null) {
        setState(() {
          _displayNameController.text = profile['display_name'] ?? '';
          
          // Traiter le numéro de téléphone s'il existe
          final phoneNumber = profile['phone_number'] as String?;
          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            // Essayer de détecter le code pays
            for (var countryCode in CountryCode.getAll()) {
              if (phoneNumber.startsWith(countryCode.dialCode)) {
                setState(() {
                  _selectedCountryCode = countryCode;
                  _phoneController.text = phoneNumber.substring(countryCode.dialCode.length).trim();
                });
                break;
              }
            }
            
            // Si aucun code pays n'est détecté, juste remplir le champ
            if (_phoneController.text.isEmpty) {
              _phoneController.text = phoneNumber;
            }
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Formater le numéro de téléphone avec le code pays
      final formattedPhone = _phoneController.text.isEmpty 
          ? null 
          : '${_selectedCountryCode.dialCode} ${_phoneController.text.trim()}';
      
      // Mettre à jour le profil dans la base de données
      await Supabase.instance.client
        .from('profiles')
        .update({
          'display_name': _displayNameController.text.trim(),
          'phone_number': formattedPhone,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);
      
      if (!mounted) return;
      
      SnackbarHelper.showSuccessSnackBar(
        context, 
        'Profil mis à jour avec succès',
      );
      
      Navigator.of(context).pop(true); // Retour avec résultat positif
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sauvegarde: $e';
      });
      
      SnackbarHelper.showErrorSnackBar(
        context, 
        'Erreur lors de la mise à jour du profil: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête décoratif
                  const IslamicDecorativeHeader(
                    title: 'Informations du profil',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  
                  // Champ pour le nom d'affichage
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'affichage',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un nom d\'affichage';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sélecteur de pays
                  CountryPicker(
                    value: _selectedCountryCode,
                    onChanged: (CountryCode? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedCountryCode = newValue;
                        });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Exemple de format de téléphone
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Exemple: ${_selectedCountryCode.example}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Champ pour le téléphone
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                      hintText: _selectedCountryCode.example,
                      prefixIcon: const Icon(Icons.phone),
                      prefixText: '${_selectedCountryCode.dialCode} ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Bouton de sauvegarde
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: const Icon(Icons.save),
                    label: Text(_isLoading ? 'Sauvegarde en cours...' : 'Sauvegarder le profil'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF1F4E5F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
