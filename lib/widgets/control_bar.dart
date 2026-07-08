import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Barra controlli compatta su due righe:
///  1) modalità (accordo, abbellimento, prova) + cancella
///  2) durata (− n +), dita 1..5 (ri-tocco = toglie), velocità ↝ (cicla 1..5)
class ControlBar extends StatelessWidget {
  final AppState state;
  const ControlBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hasTarget = state.targetEntry != null;
    return Container(
      color: Palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ToggleChip(
                      label: '≡ accordo',
                      active: state.chordMode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        state.toggleChordMode();
                      },
                    ),
                    _ToggleChip(
                      label: '↝ abbell.',
                      active: state.runMode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        state.toggleRunMode();
                      },
                    ),
                    _ToggleChip(
                      label: '✎ prova',
                      active: state.practiceMode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        state.togglePracticeMode();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _SquareBtn(
                width: 46,
                tooltip: 'Cancella voce',
                enabled: hasTarget,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  state.deleteTarget();
                },
                child: Icon(Icons.backspace_outlined,
                    size: 20,
                    color: hasTarget ? Palette.brass : Palette.brassDeep),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Durata: − n +
              _StepperGroup(
                value: state.targetEntry?.len ?? 0,
                enabled: hasTarget,
                min: 0,
                max: 8,
                decTooltip: 'Meno durata',
                incTooltip: 'Più durata',
                onDec: () {
                  HapticFeedback.lightImpact();
                  state.decLen();
                },
                onInc: () {
                  HapticFeedback.lightImpact();
                  state.incLen();
                },
              ),
              const Spacer(),
              // Dita 1..5: ri-toccare il dito attivo lo toglie.
              for (var f = 1; f <= 5; f++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _SquareBtn(
                    width: 36,
                    tooltip: 'Dito $f',
                    enabled: hasTarget,
                    active: state.currentFinger == f,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (state.currentFinger == f) {
                        state.clearFinger();
                      } else {
                        state.setFinger(f);
                      }
                    },
                    child: Text(
                      '$f',
                      style: mono(
                        size: 14,
                        weight: FontWeight.w700,
                        color: state.currentFinger == f
                            ? Palette.bg
                            : (hasTarget ? Palette.brass : Palette.brassDeep),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              // Velocità abbellimenti: un chip che cicla 1..5.
              _SquareBtn(
                width: 52,
                tooltip: 'Velocità abbellimenti (1..5)',
                enabled: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  state.cycleOrnamentSpeed();
                },
                child: Text(
                  '↝${state.ornamentSpeed}',
                  style: mono(
                      size: 14, weight: FontWeight.w700, color: Palette.brass),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Palette.brass : Palette.panel,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: active ? Palette.brass : Palette.brassDim, width: 1.5),
          ),
          child: Text(
            label,
            style: mono(
              size: 12,
              weight: FontWeight.w700,
              color: active ? Palette.bg : Palette.brass,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsante quadrato compatto (40 px di altezza).
class _SquareBtn extends StatelessWidget {
  final double width;
  final String tooltip;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final Widget child;
  const _SquareBtn({
    required this.width,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: width,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Palette.brass : Palette.panel,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? Palette.brass
                  : (enabled ? Palette.brassDim : Palette.brassDeep),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gruppo − n + compatto.
class _StepperGroup extends StatelessWidget {
  final int value;
  final bool enabled;
  final int min;
  final int max;
  final String decTooltip;
  final String incTooltip;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _StepperGroup({
    required this.value,
    required this.enabled,
    required this.min,
    required this.max,
    required this.decTooltip,
    required this.incTooltip,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, bool on, VoidCallback tap) {
      return Semantics(
        button: true,
        enabled: on,
        label: tip,
        child: InkWell(
          onTap: on ? tap : null,
          child: SizedBox(
            width: 34,
            height: 40,
            child: Icon(icon,
                size: 20, color: on ? Palette.brass : Palette.brassDeep),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Palette.brassDim, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, decTooltip, enabled && value > min, onDec),
          SizedBox(
            width: 22,
            child: Center(
              child: Text('$value',
                  style: mono(size: 14, weight: FontWeight.w700)),
            ),
          ),
          btn(Icons.add, incTooltip, enabled && value < max, onInc),
        ],
      ),
    );
  }
}
