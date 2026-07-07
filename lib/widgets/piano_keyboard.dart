import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notation.dart';
import '../theme.dart';

/// Tastiera verticale in vista fisarmonica: nota più grave in cima,
/// più acuta in fondo. Si3 (B3, 59) in cima .. Do6 (C6, 84) in fondo.
class PianoKeyboard extends StatefulWidget {
  final bool italian;
  final ValueChanged<int> onTap;

  /// Note evidenziate (voce selezionata o in riproduzione).
  final Set<int> highlightedMidis;

  /// Diteggiatura da mostrare sui tasti evidenziati.
  final Map<int, int> fingers;

  const PianoKeyboard({
    super.key,
    required this.italian,
    required this.onTap,
    this.highlightedMidis = const {},
    this.fingers = const {},
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  static const double whiteH = 44;
  static const double blackH = 30;
  static const double blackWidthFactor = 0.56;

  final ScrollController _scroll = ScrollController();
  final Set<int> _flash = {};
  bool _didCenter = false;

  late final List<int> _whiteMidis; // ascendente
  late final List<int> _blackMidis;

  @override
  void initState() {
    super.initState();
    _whiteMidis = [
      for (var m = kLowMidi; m <= kHighMidi; m++)
        if (!isBlackKey(m)) m
    ];
    _blackMidis = [
      for (var m = kLowMidi; m <= kHighMidi; m++)
        if (isBlackKey(m)) m
    ];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Indice di display (0 = più grave, in cima — vista fisarmonica).
  int _whiteDisplayIndex(int midi) => _whiteMidis.indexOf(midi);

  double get _totalHeight => _whiteMidis.length * whiteH;

  void _handleTap(int midi) {
    widget.onTap(midi);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      setState(() => _flash.add(midi));
      Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _flash.remove(midi));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // All'avvio, centra la tastiera.
        if (!_didCenter) {
          _didCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            final target = (_totalHeight - constraints.maxHeight) / 2;
            _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
          });
        }

        final width = constraints.maxWidth;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.bg,
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: _totalHeight,
              width: width,
              child: Stack(
                children: [
                  ..._whiteMidis.map(_buildWhiteKey),
                  ..._blackMidis.map((m) => _buildBlackKey(m, width)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhiteKey(int midi) {
    final i = _whiteDisplayIndex(midi);
    final pressed = _flash.contains(midi);
    final highlighted = widget.highlightedMidis.contains(midi);
    final active = pressed || highlighted;
    final finger = highlighted ? widget.fingers[midi] : null;
    return Positioned(
      top: i * whiteH,
      left: 0,
      right: 0,
      height: whiteH,
      child: _KeyTouch(
        onTap: () => _handleTap(midi),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Palette.brass, Color(0xFFD9BD7C), Palette.brassDim]
                  : const [Palette.whiteTop, Palette.whiteMid, Palette.whiteBot],
            ),
            border: Border(
              left: BorderSide(
                  color: highlighted ? Palette.ivory : Palette.brass,
                  width: highlighted ? 5 : 3),
              bottom: const BorderSide(color: Palette.line, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _fingerOnKey(finger, small: false),
              const Spacer(),
              _keyLabel(
                midi,
                color: active ? Palette.brassDeep : const Color(0xFF6B5E4C),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlackKey(int midi, double keyboardWidth) {
    // Centrato sul confine tra i due tasti bianchi corretti. In vista
    // fisarmonica il bianco più grave (midi-1) sta più in alto: il confine con
    // quello più acuto (midi+1) è il suo bordo INFERIORE.
    final lowerWhiteIndex = _whiteDisplayIndex(midi - 1);
    final boundaryY = (lowerWhiteIndex + 1) * whiteH;
    final pressed = _flash.contains(midi);
    final highlighted = widget.highlightedMidis.contains(midi);
    final active = pressed || highlighted;
    final finger = highlighted ? widget.fingers[midi] : null;
    return Positioned(
      top: boundaryY - blackH / 2,
      right: 0,
      height: blackH,
      width: keyboardWidth * blackWidthFactor,
      child: SizedBox.expand(
        child: _KeyTouch(
          onTap: () => _handleTap(midi),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: active
                    ? const [Palette.brass, Palette.brassDim, Palette.brassDeep]
                    : const [Palette.blackTop, Palette.blackMid, Palette.blackBot],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
              border: highlighted
                  ? const Border(
                      left: BorderSide(color: Palette.ivory, width: 2),
                      top: BorderSide(color: Palette.ivory, width: 2),
                      bottom: BorderSide(color: Palette.ivory, width: 2),
                    )
                  : null,
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(-1, 1)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _fingerOnKey(finger, small: true),
                const Spacer(),
                _keyLabel(
                  midi,
                  color: active ? Palette.bg : Palette.brass,
                  small: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pallino con il numero del dito, mostrato sul tasto evidenziato.
  Widget _fingerOnKey(int? finger, {required bool small}) {
    if (finger == null) return const SizedBox.shrink();
    final d = small ? 17.0 : 22.0;
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.brassDeep,
        shape: BoxShape.circle,
        border: Border.all(color: Palette.ivory, width: 1.5),
      ),
      child: Text('$finger',
          style: mono(
              size: small ? 10 : 12,
              weight: FontWeight.w800,
              color: Palette.ivory)),
    );
  }

  Widget _keyLabel(int midi, {required Color color, bool small = false}) {
    final name = noteName(midi, italian: widget.italian);
    final oct = octaveOf(midi).toString();
    return RichText(
      text: TextSpan(
        style: mono(
          size: small ? 11 : 13,
          weight: FontWeight.w700,
          color: color,
        ),
        children: [
          TextSpan(text: name),
          // Ottava piccola, come pedice.
          TextSpan(
            text: oct,
            style: mono(
              size: small ? 8 : 9,
              weight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyTouch extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _KeyTouch({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
