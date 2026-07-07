import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Barra controlli: toggle modalità accordo, gruppo durata (− +), cancella.
class ControlBar extends StatelessWidget {
  final AppState state;
  const ControlBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hasTarget = state.targetEntry != null;
    return Container(
      color: Palette.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _ToggleChip(
            label: '≡ accordo',
            active: state.chordMode,
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleChordMode();
            },
          ),
          const Spacer(),
          _DurationGroup(state: state, enabled: hasTarget),
          const SizedBox(width: 10),
          _IconAction(
            icon: Icons.backspace_outlined,
            tooltip: 'Cancella voce',
            enabled: hasTarget,
            onTap: () {
              HapticFeedback.mediumImpact();
              state.deleteTarget();
            },
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Palette.brass : Palette.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? Palette.brass : Palette.brassDim, width: 1.5),
          ),
          child: Text(
            label,
            style: mono(
              size: 14,
              weight: FontWeight.w700,
              color: active ? Palette.bg : Palette.brass,
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationGroup extends StatelessWidget {
  final AppState state;
  final bool enabled;
  const _DurationGroup({required this.state, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final len = state.targetEntry?.len ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.brassDim, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconAction(
            icon: Icons.remove,
            tooltip: 'Meno durata',
            enabled: enabled && len > 0,
            flat: true,
            onTap: () {
              HapticFeedback.lightImpact();
              state.decLen();
            },
          ),
          Container(
            width: 34,
            alignment: Alignment.center,
            child: Text('$len',
                style: mono(size: 15, weight: FontWeight.w700)),
          ),
          _IconAction(
            icon: Icons.add,
            tooltip: 'Più durata',
            enabled: enabled && len < 8,
            flat: true,
            onTap: () {
              HapticFeedback.lightImpact();
              state.incLen();
            },
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool flat;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Palette.brass : Palette.brassDeep;
    final child = Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      alignment: Alignment.center,
      decoration: flat
          ? null
          : BoxDecoration(
              color: Palette.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.brassDim, width: 1.5),
            ),
      child: Icon(icon, color: color, size: 22),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}
