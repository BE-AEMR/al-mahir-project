import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/islamic_patterns.dart';
import '../../widgets/logo_widget.dart';
import 'login_screen.dart';

class AccountConfirmationScreen extends StatefulWidget {
  final String token;
  
  const AccountConfirmationScreen({
    super.key,
    required this.token,
  });

  @override
  State<AccountConfirmationScreen> createState() => _AccountConfirmationScreenState();
}

class _AccountConfirmationScreenState extends State<AccountConfirmationScreen> {
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  String? _errorMessage;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Vérifier la confirmation du compte automatiquement
    print("====== DÉBUT TRAITEMENT CONFIRMATION COMPTE ======");
    print("Token reçu: ${widget.token}");
    _checkConfirmation();
  }

  Future<void> _checkConfirmation() async {
    print("Début de la vérification de confirmation de compte...");
    try {
      print("1. Tentative d'utilisation du token reçu: ${widget.token}");

      // Vérifier si le token est déjà traité automatiquement par Supabase
      print("2. Vérification de l'état de la session actuelle");
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        print("3a. Session trouvée - Utilisateur déjà connecté: ${session.user.email}");
        print("    ID utilisateur: ${session.user.id}");
        print("    Email vérifié: ${session.user.emailConfirmedAt != null}");
        
        setState(() {
          _isLoading = false;
          _isConfirmed = true;
        });
      } else {
        print("3b. Aucune session trouvée - Tentative de traitement manuel du token");
        
        try {
          // Essayer de traiter manuellement le token si nécessaire
          print("4a. Tentative de récupération des paramètres du token");
          
          // En théorie, ce code ne devrait pas être nécessaire car Supabase gère automatiquement
          // le token, mais nous l'incluons pour le débogage
          final response = await Supabase.instance.client.auth.verifyOTP(
            token: widget.token,
            type: OtpType.signup,
          );
          
          if (response.session != null) {
            print("5a. Token traité avec succès - Utilisateur: ${response.user?.email}");
            setState(() {
              _isLoading = false;
              _isConfirmed = true;
            });
          } else {
            print("5b. Échec du traitement manuel - Aucune session retournée");
            setState(() {
              _isLoading = false;
              _errorMessage = "La confirmation du compte n'a pas pu être effectuée automatiquement. Veuillez réessayer ou contacter le support.";
            });
          }
        } catch (innerError) {
          print("4b. ERREUR lors du traitement manuel: $innerError");
          setState(() {
            _isLoading = false;
            _errorMessage = "Erreur lors de la confirmation: $innerError";
          });
        }
      }
    } catch (e) {
      print("ERREUR PRINCIPALE: $e");
      print("Stack trace: ${StackTrace.current}");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Une erreur s\'est produite: $e';
      });
    } finally {
      print("Fin de la vérification de confirmation - Statut: ${_isConfirmed ? 'CONFIRMÉ' : 'NON CONFIRMÉ'}");
      if (_errorMessage != null) {
        print("Message d'erreur: $_errorMessage");
      }
      print("====== FIN TRAITEMENT CONFIRMATION COMPTE ======");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fond avec dégradé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1F4E5F),
                  const Color(0xFF0D2B36),
                ],
              ),
            ),
          ),
          
          // Motif islamique en arrière-plan
          Positioned.fill(
            child: Opacity(
              opacity: 0.09,
              child: IslamicPatternBackground(
                color: const Color.fromARGB(198, 255, 217, 0), // Couleur dorée
              ),
            ),
          ),
          
          // Contenu principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo 
                    Center(
                      child: const LogoWidget(
                        isGold: false, // Logo blanc pour l'écran de confirmation
                        size: 180,
                        animationType: LogoAnimationType.float,
                        animationDuration: Duration(milliseconds: 1500),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Titre
                    const Text(
                      'Confirmation de compte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      'Nous vérifions la confirmation de votre compte...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Indicateur de chargement
                    if (_isLoading)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Vérification en cours...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Message d'erreur
                    if (!_isLoading && _errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de confirmation',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                backgroundColor: Colors.red.withOpacity(0.3),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Retour à la connexion',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Message de succès
                    if (!_isLoading && _isConfirmed)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Compte confirmé !',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Votre compte a été confirmé avec succès. Vous pouvez maintenant vous connecter.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                backgroundColor: Colors.green.withOpacity(0.3),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
