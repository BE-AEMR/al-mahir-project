import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre mot de passe pour confirmer')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Vérifier le mot de passe avant de supprimer le compte
      await _authService.signInWithEmailAndPassword(
        email: _authService.currentUser!.email!,
        password: _passwordController.text,
      );
      
      // Supprimer le compte
      await _authService.deleteAccount();
      
      // Rediriger vers l'écran de connexion
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre compte a été supprimé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
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
        title: const Text('Supprimer mon compte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supprimer votre compte',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Attention: Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            const Text(
              'Veuillez entrer votre mot de passe pour confirmer la suppression:',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Supprimer mon compte définitivement',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
