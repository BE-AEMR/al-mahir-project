import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/preferences_service.dart';

class FullscreenCagnotte extends StatefulWidget {
  final String? url;
  
  const FullscreenCagnotte({
    Key? key, 
    this.url,
  }) : super(key: key);

  @override
  State<FullscreenCagnotte> createState() => _FullscreenCagnotteState();
}

class _FullscreenCagnotteState extends State<FullscreenCagnotte> {
  final PreferencesService _preferencesService = PreferencesService();
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    setState(() {
      _isLoading = true;
    });

    final url = widget.url ?? await _preferencesService.getCagnotteUrl();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Optimiser l'affichage pour le mobile
            _controller.runJavaScript('''
              document.querySelector('meta[name="viewport"]').content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
              document.body.style.overflow = 'auto';
              document.body.style.maxWidth = '100%';
              
              // Permettre le défilement sur les éléments
              var elements = document.querySelectorAll('body, div');
              for (var i = 0; i < elements.length; i++) {
                elements[i].style.touchAction = 'auto';
                elements[i].style.overflowY = 'auto';
                elements[i].style.webkitOverflowScrolling = 'touch';
              }
              
              // Empêcher les éléments de capturer les événements de défilement
              document.addEventListener('touchmove', function(e) {
                e.stopPropagation();
              }, { passive: true });
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: ${error.description}')),
            );
          },
        ),
      )
      ..enableZoom(true)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cagnotte en ligne',
          overflow: TextOverflow.ellipsis,
        ),
        titleSpacing: 0, // Réduire l'espace autour du titre
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            padding: EdgeInsets.zero, // Réduire le padding de l'icône
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
