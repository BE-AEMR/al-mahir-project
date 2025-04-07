import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScrollableWebView extends StatefulWidget {
  final WebViewController controller;
  final bool isLoading;
  
  const ScrollableWebView({
    Key? key,
    required this.controller,
    required this.isLoading,
  }) : super(key: key);
  
  @override
  State<ScrollableWebView> createState() => _ScrollableWebViewState();
}

class _ScrollableWebViewState extends State<ScrollableWebView> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Permet de capturer les événements de défilement sans les bloquer
            return false;
          },
          child: InteractiveViewer(
            constrained: true,
            panEnabled: true,
            scaleEnabled: false,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: GestureDetector(
                // Capture les gestes pour éviter que les parents les interceptent
                onVerticalDragUpdate: (_) {},
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: WebViewWidget(
                        controller: widget.controller,
                      ),
                    ),
                    if (widget.isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
