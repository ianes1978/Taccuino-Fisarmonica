import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../models/notation.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Striscia dell'annotazione: chip inline per note singole, chip con note
/// incolonnate per gli accordi. Header con copia/svuota.
class AnnotationStrip extends StatelessWidget {
  final AppState state;
  const AnnotationStrip({super.key, required this.state});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: state.exportText));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Copiato negli appunti', style: mono(size: 13)),
          backgroundColor: Palette.brassDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final empty = state.isEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Palette.panel,
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Annotazione',
                  style: mono(
                      size: 11,
                      color: Palette.muted,
                      weight: FontWeight.w700,
                      spacing: 1.5)),
              const Spacer(),
              if (!empty) ...[
                _HeaderButton(
                  icon: Icons.copy_all_outlined,
                  tooltip: 'Copia',
                  onTap: () => _copy(context),
                ),
                _HeaderButton(
                  icon: Icons.refresh,
                  tooltip: 'Svuota',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    state.clearAll();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: empty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tocca un tasto per iniziare.\nLe note appaiono qui.',
                      style: mono(size: 13, color: Palette.muted),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.sequence.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _EntryChip(
                      entry: state.sequence[i],
                      italian: state.italian,
                      isTarget: state.targetIndex == i,
                      chordMode: state.chordMode,
                      onTap: () => state.selectEntry(i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: Palette.brass),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      splashRadius: 22,
    );
  }
}

class _EntryChip extends StatelessWidget {
  final Entry entry;
  final bool italian;
  final bool isTarget;
  final bool chordMode;
  final VoidCallback onTap;

  const _EntryChip({
    required this.entry,
    required this.italian,
    required this.isTarget,
    required this.chordMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dashes = '-' * entry.len;
    final Widget content;
    if (entry.midis.length == 1) {
      content = Text(
        '${noteLabel(entry.midis.first, italian: italian)}$dashes',
        style: mono(size: 16, weight: FontWeight.w700),
      );
    } else {
      // Accordo: note incolonnate, la più acuta in alto e la più grave in
      // basso, con i trattini di durata a fianco.
      final descending = entry.midis.reversed.toList();
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in descending)
                Text(noteLabel(m, italian: italian),
                    style: mono(size: 13, weight: FontWeight.w700, height: 1.2)),
            ],
          ),
          if (dashes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(dashes,
                  style: mono(size: 16, weight: FontWeight.w700)),
            ),
        ],
      );
    }

    // Bersaglio: bordo ottone pieno in modalità normale, tratteggiato in
    // modalità accordo. Altrimenti bordo neutro.
    final dashed = isTarget && chordMode;
    final child = Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isTarget ? Palette.brassDeep.withValues(alpha: 0.35) : Palette.bg,
        borderRadius: BorderRadius.circular(8),
        border: dashed
            ? null
            : Border.all(
                color: isTarget ? Palette.brass : Palette.line,
                width: isTarget ? 2 : 1,
              ),
      ),
      alignment: Alignment.center,
      child: content,
    );

    return GestureDetector(
      onTap: onTap,
      child: dashed
          ? CustomPaint(
              foregroundPainter: _DashedBorderPainter(),
              child: child,
            )
          : child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final paint = Paint()
      ..color = Palette.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0.0, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
