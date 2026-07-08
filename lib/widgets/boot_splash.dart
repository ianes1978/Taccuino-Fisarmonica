import 'dart:async';

import 'package:flutter/material.dart';

/// Mostra l'artwork di avvio a tutto schermo per un attimo, poi dissolve
/// verso l'app. Uguale su Android e web (dove lo splash nativo è limitato).
class BootSplash extends StatefulWidget {
  final Widget child;
  const BootSplash({super.key, required this.child});

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash> {
  bool _visible = true;
  bool _gone = false;

  static const _hold = Duration(milliseconds: 1400);
  static const _fade = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    Timer(_hold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fade,
            onEnd: () {
              if (!_visible && mounted) setState(() => _gone = true);
            },
            child: LayoutBuilder(
              builder: (context, c) {
                // Verticale: riempi lo schermo; orizzontale/desktop: contieni
                // su fondo scuro per non tagliare l'artwork.
                final portrait = c.maxHeight >= c.maxWidth;
                return Container(
                  color: const Color(0xFF0B0805),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/splash/splash.png',
                    fit: portrait ? BoxFit.cover : BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
