# WebXio - Application de Gestion de Projets

Une application mobile Flutter pour la gestion de projets et de tâches, avec authentification et stockage des données dans Supabase.

## Démonstration de l'Application

Voici une démonstration des fonctionnalités principales de l'application :

![Démo WebXio](assets/demo/compressed/demo_full_optimized.gif)

Si la démonstration ci-dessus ne s'affiche pas correctement, vous pouvez [télécharger la vidéo complète ici](https://github.com/Yahia-ELECHI/webxio_new/raw/main/assets/demo/compressed/demo_compressed.mp4).

## Fonctionnalités

- Authentification des utilisateurs (connexion, inscription)
- Gestion des projets (création, modification, suppression)
- Gestion des tâches (création, modification, suppression, changement de statut)
- Système de phases pour les projets (non démarré, en cours, terminé, en attente, annulé)
- Système complet de notifications pour les événements clés (projets, phases, tâches)
- Gestion des budgets avec alertes automatiques
- Stockage des données dans Supabase

## Système de Phases

Chaque projet peut avoir plusieurs phases, permettant une organisation plus structurée :
- Phases ordonnées avec un statut (non démarré, en cours, terminé, en attente, annulé)
- Chaque phase peut contenir plusieurs tâches
- Les tâches peuvent être associées à une phase spécifique

## Système de Notifications

L'application intègre un système complet de notifications couvrant les événements suivants :

1. Projets :
   - Création de projet
   - Changement de statut de projet
   - Alertes de budget (à 70%, 90% et 100% du budget alloué)

2. Phases :
   - Création de phase
   - Changement de statut de phase

3. Tâches :
   - Assignation de tâche
   - Échéance proche (7 jours, 3 jours, 1 jour)
   - Tâche en retard
   - Changement de statut

## Technologies et Versions

### Environnement de développement
- Dart SDK : ^3.7.0
- Flutter : dernière version stable

### Frameworks et bibliothèques principales
- Supabase Flutter : ^2.8.4
- Supabase : ^2.0.8
- Flutter DotEnv : ^5.2.1
- UUID : ^4.5.1
- Flutter Animate : ^4.5.2
- Table Calendar : ^3.0.9
- Intl : ^0.19.0
- FL Chart : ^0.70.2

### Configuration Android
- Java : Version 11
- NDK : 27.0.12077973
- Target SDK : Flutter SDK (dernière version)
- Min SDK : Flutter SDK (dernière version)

### Bibliothèques UI et fonctionnalités spécifiques
- Cupertino Icons : ^1.0.8
- Syncfusion Flutter Charts : ^28.2.9
- Lottie : ^3.3.1
- Cached Network Image : ^3.4.1
- Image Picker : ^1.1.2
- File Picker : ^9.0.2
- Share Plus : ^10.1.4
- URL Launcher : ^6.3.1
- WebView Flutter : ^4.7.0
- Flutter PDF View : ^1.4.0

## Configuration de Supabase

Pour configurer la base de données Supabase, suivez ces étapes :

1. Connectez-vous à l'interface d'administration de Supabase : https://qxjxzbmihbapoeaebdvk.supabase.co
2. Allez dans l'onglet "SQL Editor"
3. Copiez et collez le contenu du fichier `supabase/schema_complete.sql`
4. Exécutez le script SQL pour créer toutes les tables et les politiques de sécurité

Alternativement, si vous avez la CLI Supabase installée, vous pouvez appliquer les migrations directement :

```bash
# Installation de la CLI Supabase (si nécessaire)
npm install -g supabase

# Connexion à votre projet
supabase login
supabase link --project-ref qxjxzbmihbapoeaebdvk

# Application des migrations
supabase db push
```

Pour créer un utilisateur de test et des données de test, exécutez :

```bash
dart run lib/scripts/create_test_user_direct.dart
```

## Démarrage

1. Assurez-vous que Flutter est installé sur votre machine
2. Clonez ce dépôt
3. Exécutez `flutter pub get` pour installer les dépendances
4. Exécutez `flutter run` pour lancer l'application

## Identifiants de test

- Email : test@example.com
- Mot de passe : password123

## Structure du projet

- `lib/models/` : Modèles de données (Project, Task, Phase, Notification, etc.)
- `lib/services/` : Services pour interagir avec Supabase
  - `project_service/` : Services liés aux projets
  - `task_service/` : Services liés aux tâches
  - `phase_service/` : Services liés aux phases
  - `notification_service.dart` : Service de gestion des notifications
  - `budget_service.dart` : Service de gestion des budgets
- `lib/screens/` : Écrans de l'application
  - `auth/` : Écrans d'authentification
  - `projects/` : Écrans de gestion des projets
  - `tasks/` : Écrans de gestion des tâches
  - `dashboard/` : Tableau de bord principal
  - `budget/` : Écrans de gestion des budgets
  - `calendar/` : Vue calendrier
  - `notifications/` : Écrans de gestion des notifications
- `lib/scripts/` : Scripts utilitaires pour la configuration de Supabase
- `supabase/` : Scripts SQL pour la configuration de Supabase
  - `migrations/` : Fichiers de migration pour les modifications de schéma
  - `schema_complete.sql` : Schéma complet de la base de données
