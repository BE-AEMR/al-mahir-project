import 'package:flutter/material.dart';

/// Widget qui fait défiler le texte horizontalement (effet marquee)
/// lorsque le texte est trop long pour être affiché entièrement.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double blankSpace;
  final double velocity;
  final double startAfter;
  final Duration startAfterDuration;
  final Duration pauseAfterRound;
  final int? numberOfRounds;
  final bool showFadingOnlyWhenScrolling;
  final double fadingWidth;
  final Curve accelerationCurve;
  final Curve decelerationCurve;
  final bool forwardOnly;

  const MarqueeText({
    Key? key,
    required this.text,
    this.style,
    this.blankSpace = 80.0,
    this.velocity = 50.0, // pixels/second
    this.startAfter = 1.0,
    this.startAfterDuration = const Duration(seconds: 1),
    this.pauseAfterRound = const Duration(seconds: 1),
    this.numberOfRounds,
    this.showFadingOnlyWhenScrolling = false,
    this.fadingWidth = 15.0,
    this.accelerationCurve = Curves.easeInOut,
    this.decelerationCurve = Curves.easeInOut,
    this.forwardOnly = false,
  }) : super(key: key);

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  double _containerWidth = 0;
  double _textWidth = 0;
  bool _needsToScroll = false;
  int _roundCounter = 0;
  bool _measuring = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  void _initialize() {
    setState(() {
      _measuring = false;
    });
    
    final RenderBox? containerBox = context.findRenderObject() as RenderBox?;
    final RenderBox textBox = _keyText.currentContext?.findRenderObject() as RenderBox;
    
    if (containerBox != null) {
      _containerWidth = containerBox.size.width;
      _textWidth = textBox.size.width;
      
      if (_textWidth > _containerWidth) {
        _needsToScroll = true;
        _startAnimation();
      }
    }
  }

  void _startAnimation() {
    Future.delayed(widget.startAfterDuration, () {
      if (!mounted) return;
      
      final scrollDistance = _textWidth - _containerWidth + widget.blankSpace;
      final duration = Duration(milliseconds: (scrollDistance / widget.velocity * 1000).round());
      
      _animationController.duration = duration;
      
      _forwardAnimation();
    });
  }

  void _forwardAnimation() {
    if (!mounted) return;
    
    _animationController.forward().then((_) {
      _roundCounter++;
      
      if (widget.numberOfRounds != null && _roundCounter >= widget.numberOfRounds!) {
        return;
      }
      
      _scrollController.jumpTo(0);
      
      Future.delayed(widget.pauseAfterRound, () {
        if (mounted) {
          if (widget.forwardOnly) {
            _animationController.reset();
            _forwardAnimation();
          } else {
            _backwardAnimation();
          }
        }
      });
    });
  }

  void _backwardAnimation() {
    if (!mounted) return;
    
    _animationController.reverse().then((_) {
      Future.delayed(widget.pauseAfterRound, () {
        if (mounted) {
          _forwardAnimation();
        }
      });
    });
  }

  final GlobalKey _keyText = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (_measuring) {
      return _buildMeasuringText();
    }
    
    if (!_needsToScroll) {
      return _buildText();
    }
    
    return _buildMarquee();
  }

  Widget _buildMeasuringText() {
    return Container(
      key: _keyText,
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }

  Widget _buildText() {
    return Text(
      widget.text,
      style: widget.style,
    );
  }

  Widget _buildMarquee() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scrollPosition = _animationController.value * (_textWidth - _containerWidth + widget.blankSpace);
        _scrollController.jumpTo(scrollPosition);
        
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.white,
                Colors.white,
              ],
              stops: [0.0, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            width: _containerWidth,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                  ),
                  SizedBox(width: widget.blankSpace),
                  Text(
                    widget.text,
                    style: widget.style,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
