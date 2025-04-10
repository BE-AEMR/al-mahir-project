import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webxio_new/widgets/logo_widget.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/role_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/projects/projects_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/profile_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/teams/teams_screen.dart';
import 'screens/teams/invitations_screen.dart';
import 'screens/teams/invitation_acceptance_screen.dart';
import 'screens/budget/finance_dashboard_screen.dart';
import 'screens/finance/project_finance_dashboard_screen.dart'; // Nouvel emplacement plus approprié
import 'screens/notifications/notifications_screen.dart';
import 'screens/budget/categories/transaction_categories_screen.dart'; // Import pour l'écran de catégories
import 'widgets/sidebar_menu.dart';
import 'widgets/islamic_patterns.dart';
import 'widgets/notification_popup.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'package:app_links/app_links.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';

// Clé globale pour accéder au navigateur depuis n'importe où
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Instance de AppLinks pour la gestion des liens profonds
final appLinks = AppLinks();

void main() async {
  // Capture toutes les erreurs non gérées
  FlutterError.onError = (FlutterErrorDetails details) {
    print('FlutterError: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les données de locale
  await initializeDateFormatting('fr_FR', null);

  // Initialiser le service de cache
  await CacheService().initialize();

  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");

  // Lancer l'application sans attendre Supabase
  runApp(const MyApp());

  // Initialiser Supabase en arrière-plan
  _initializeSupabase();

  // Gestion des liens profonds (deep links)
  _handleDeepLinks();
}

// Initialiser Supabase en arrière-plan
Future<void> _initializeSupabase() async {
  try {
    print("Tentative d'initialisation de Supabase...");
    final supabaseUrl = 'https://qxjxzbmihbapoeaebdvk.supabase.co';
    final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4anh6Ym1paGJhcG9lYWViZHZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEwNzk4MzUsImV4cCI6MjA1NjY1NTgzNX0.x8fV1oOxZyUAvB2eono3TCthWdRpJFc3c2RQ7oU80zw';

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      print("Erreur: URL ou clé Supabase manquante dans le fichier .env");
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      debug: false
    );
    print("Supabase initialisé avec succès!");
  } catch (e, stackTrace) {
    print("Erreur lors de l'initialisation de Supabase: $e");
    print("Stack trace: $stackTrace");
  }
}

// Gestion des liens profonds (deep links)
Future<void> _handleDeepLinks() async {
  try {
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      print("Lien initial: $initialLink");
      _processLink(initialLink.toString());
    }

    // Écouter les liens dynamiques (DynamicLinks)
    appLinks.uriLinkStream.listen((link) {
      print("Lien reçu: $link");
      _processLink(link.toString());
    }, onError: (error) {
      print("Erreur lors de la réception du lien: $error");
    });
  } catch (e) {
    print("Erreur lors de la gestion des liens profonds: $e");
  }
}

// Traiter un lien deep link
void _processLink(String link) {
  try {
    final uri = Uri.parse(link);

    if (uri.host == 'invitation' || uri.path == '/invitation') {
      // Extraire les paramètres
      final token = uri.queryParameters['token'] ?? '';
      final teamId = uri.queryParameters['team'] ?? '';

      if (token.isNotEmpty && teamId.isNotEmpty) {
        print("Invitation reçue - Token: $token, Team ID: $teamId");

        // Accéder au navigateur global
        navigatorKey.currentState?.pushNamed(
          '/invitation',
          arguments: {
            'token': token,
            'team': teamId,
          },
        );
      }
    }
  } catch (e) {
    print("Erreur lors du traitement du lien: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoleProvider()),
      ],
      child: MaterialApp(
        title: 'AL MAHIR Project',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1F4E5F),
            primary: const Color(0xFF1F4E5F),
            secondary: const Color(0xFFE57373),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F4E5F),
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1F4E5F),
                width: 2,
              ),
            ),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        locale: const Locale('fr', 'FR'),
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainAppScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/transaction-categories': (context) => const TransactionCategoriesScreen(),
          '/invitation': (context) {
            // Récupérer les paramètres d'URL pour l'invitation
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>?;
            final token = args?['token'] ?? Uri.base.queryParameters['token'] ?? '';
            final teamId = args?['team'] ?? Uri.base.queryParameters['team'] ?? '';

            // Rediriger vers l'écran d'acceptation d'invitation
            return InvitationAcceptanceScreen(
              token: token,
              teamId: teamId,
            );
          },
        },
        initialRoute: '/',
        navigatorKey: navigatorKey, // Ajouter la clé de navigateur globale
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _checkAuthentication();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainAppScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F4E5F),
              Color(0xFF0D2B36),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo doré avec animation de pulsation
                const LogoWidget(
                  isGold: false,
                  size: 180,
                  animationType: LogoAnimationType.pulse,
                  repeat: true,
                  animationDuration: Duration(milliseconds: 1500),
                ),

                const SizedBox(height: 24),

                const Text(
                  'AL MAHIR Project',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestion de Projets',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainAppScreen extends StatefulWidget {
  final int initialIndex;

  const MainAppScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final AuthService _authService = AuthService();
  late int _selectedIndex;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProjectsScreen(),
    const TeamsScreen(),
    const CalendarScreenWrapper(), // Utilisation du wrapper pour éviter le flash d'écran d'accès refusé
    const StatisticsScreenWrapper(), // Utilisation du wrapper pour les statistiques
    const ProjectFinanceDashboardScreenWrapper(), // Utilisation du wrapper pour les finances
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isAuthenticated = user != null;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (!isAuthenticated) {
      return const LoginScreen();
    }

    return Scaffold(
      body: isSmallScreen
          ? _screens[_selectedIndex]
          : Row(
              children: [
                // Menu latéral
                SidebarMenu(
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  selectedIndex: _selectedIndex,
                ),

                // Contenu principal
                Expanded(
                  child: _screens[_selectedIndex],
                ),
              ],
            ),
      bottomNavigationBar: isSmallScreen
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: const Color(0xFF1F4E5F),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Tableau de bord',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment),
                  label: 'Projets',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Équipes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendrier',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Statistiques',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money),
                  label: 'Finance',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            )
          : null,
      drawer: isSmallScreen
          ? Drawer(
              child: SidebarMenu(
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context); // Fermer le drawer après sélection
                },
                selectedIndex: _selectedIndex,
                isDrawer: true,
              ),
            )
          : null,
      appBar: isSmallScreen
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64.0),
              child: LayoutBuilder(
                builder: (context, constraints) {

                  return AppBar(
                    toolbarHeight: 60, // Augmenter la hauteur de la barre d'outils
                    title: Padding(
                      padding: const EdgeInsets.only(left: 8.0), // Ajouter un peu d'espace à gauche
                      child: SvgPicture.asset(
                        'assets/logo/almahir_blanc_texte_v2.svg',
                        height: 150,
                        width: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    titleSpacing: 0,
                    centerTitle: false,
                    leadingWidth: 36,
                    backgroundColor: const Color(0xFF1F4E5F),
                    foregroundColor: Colors.white,
                    flexibleSpace: Stack(
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.09,
                            child: IslamicPatternBackground(
                              color: const Color.fromARGB(198, 255, 217, 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      NotificationIcon(),
                    ],
                  );
                }
              ),
            )
          : null,
    );
  }
}
