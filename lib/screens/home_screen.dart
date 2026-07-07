import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/annotation_strip.dart';
import '../widgets/control_bar.dart';
import '../widgets/piano_keyboard.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            return Column(
              children: [
                _Header(state: state),
                AnnotationStrip(state: state),
                ControlBar(state: state),
                Expanded(
                  child: PianoKeyboard(
                    italian: state.italian,
                    onTap: state.onKeyTap,
                    highlightedMidis: state.highlightedMidis,
                    fingers: state.highlightedFingers,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.bg,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Taccuino Fisarmonica',
                    style: display(size: 21, weight: FontWeight.w600)),
                Text('blocco note musicale',
                    style: mono(size: 10, color: Palette.muted, spacing: 1)),
              ],
            ),
          ),
          _HeaderToggle(
            label: state.italian ? 'Do Re Mi' : 'C D E',
            tooltip: 'Sistema nomi',
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleNames();
            },
          ),
          const SizedBox(width: 8),
          _HeaderToggle(
            label: state.audioOn ? '♪' : '×',
            tooltip: state.audioOn ? 'Audio attivo' : 'Muto',
            active: state.audioOn,
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleAudio();
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderToggle extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _HeaderToggle({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? Palette.brassDim : Palette.brassDeep,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: mono(
                size: 14,
                weight: FontWeight.w700,
                color: active ? Palette.brass : Palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
