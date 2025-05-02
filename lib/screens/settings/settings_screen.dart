import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'delete_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Paramètres du compte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            subtitle: const Text('Modifier vos informations personnelles'),
            onTap: () {
              // Navigation vers l'écran de profil
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Gérer vos préférences de notifications'),
            onTap: () {
              // Navigation vers l'écran de notifications
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Sécurité'),
            subtitle: const Text('Modifier votre mot de passe'),
            onTap: () {
              // Navigation vers l'écran de sécurité
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Danger',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Supprimer mon compte'),
            subtitle: const Text('Supprimer définitivement votre compte et toutes vos données'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DeleteAccountScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
