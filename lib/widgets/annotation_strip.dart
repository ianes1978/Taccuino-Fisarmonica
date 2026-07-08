import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../models/notation.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'score_view.dart';

/// Striscia dell'annotazione: chip inline per note singole, chip con note
/// incolonnate per gli accordi. Header con play, copia e svuota.
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
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 6),
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
                  icon: Icons.visibility_outlined,
                  tooltip: 'Visualizza a schermo intero',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScoreView(
                          entries: List.of(state.sequence),
                          title: state.loadedName,
                          italian: state.italian,
                        ),
                      ),
                    );
                  },
                ),
                _HeaderButton(
                  icon: state.isPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: state.isPlaying ? 'Ferma' : 'Ascolta',
                  filled: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.togglePlay();
                  },
                ),
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
          const SizedBox(height: 2),
          SizedBox(
            height: 68,
            child: empty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tocca un tasto per iniziare.\nLe note appaiono qui.',
                      style: mono(size: 13, color: Palette.muted),
                    ),
                  )
                : ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: state.sequence.length,
                    onReorder: state.moveEntry,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: child,
                    ),
                    itemBuilder: (context, i) {
                      final entry = state.sequence[i];
                      // Tieni premuto per spostare; tocco singolo per
                      // selezionare.
                      return ReorderableDelayedDragStartListener(
                        key: ObjectKey(entry),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _EntryChip(
                            entry: entry,
                            italian: state.italian,
                            isTarget: state.targetIndex == i,
                            isPlaying: state.playingIndex == i,
                            chordMode: state.chordMode,
                            runMode: state.runMode,
                            focusMidi: state.targetIndex == i
                                ? state.effectiveFocusMidi
                                : null,
                            onTapChip: () => state.selectEntry(i),
                            onTapNote: (m) => state.focusNoteInEntry(i, m),
                          ),
                        ),
                      );
                    },
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
  final bool filled;
  final VoidCallback onTap;
  const _HeaderButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      icon: Icon(icon,
          size: 20, color: filled ? Palette.bg : Palette.brass),
      style: filled
          ? IconButton.styleFrom(backgroundColor: Palette.brass)
          : null,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
  }
}

class _EntryChip extends StatelessWidget {
  final Entry entry;
  final bool italian;
  final bool isTarget;
  final bool isPlaying;
  final bool chordMode;
  final bool runMode;
  final int? focusMidi;
  final VoidCallback onTapChip;
  final ValueChanged<int> onTapNote;

  const _EntryChip({
    required this.entry,
    required this.italian,
    required this.isTarget,
    required this.isPlaying,
    required this.chordMode,
    required this.runMode,
    required this.focusMidi,
    required this.onTapChip,
    required this.onTapNote,
  });

  @override
  Widget build(BuildContext context) {
    final dashes = '-' * entry.len;
    final Widget content;
    if (entry.run) {
      // Abbellimento: note in fila orizzontale (nell'ordine), fra graffe.
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('{',
              style: mono(
                  size: 17, weight: FontWeight.w700, color: Palette.brass)),
          for (var k = 0; k < entry.midis.length; k++)
            GestureDetector(
              onTap: () => onTapNote(entry.midis[k]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: focusMidi == entry.midis[k]
                    ? BoxDecoration(
                        color: Palette.brass.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(noteLabel(entry.midis[k], italian: italian),
                        style: mono(size: 13, weight: FontWeight.w700)),
                    _fingerBadge(entry.fingerOf(entry.midis[k])),
                  ],
                ),
              ),
            ),
          Text('}',
              style: mono(
                  size: 17, weight: FontWeight.w700, color: Palette.brass)),
          if (dashes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(dashes,
                  style: mono(size: 16, weight: FontWeight.w700)),
            ),
        ],
      );
    } else if (entry.midis.length == 1) {
      final m = entry.midis.first;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${noteLabel(m, italian: italian)}$dashes',
              style: mono(size: 16, weight: FontWeight.w700)),
          _fingerBadge(entry.fingerOf(m)),
        ],
      );
    } else {
      // Accordo: note incolonnate (acuta in alto, grave in basso), toccabili.
      // Con più di 3 note la colonna scorre verticalmente dentro il chip,
      // così anche le note nascoste restano selezionabili.
      final descending = entry.midis.reversed.toList();
      final noteColumn = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in descending)
            GestureDetector(
              onTap: () => onTapNote(m),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                decoration: focusMidi == m
                    ? BoxDecoration(
                        color: Palette.brass.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(noteLabel(m, italian: italian),
                        style: mono(
                            size: 13, weight: FontWeight.w700, height: 1.2)),
                    _fingerBadge(entry.fingerOf(m)),
                  ],
                ),
              ),
            ),
        ],
      );
      final manyNotes = descending.length > 3;
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (manyNotes)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 50, maxWidth: 96),
              child: ScrollConfiguration(
                // Consenti il drag anche col mouse (web/desktop).
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                  scrollbars: false,
                ),
                child: SingleChildScrollView(child: noteColumn),
              ),
            )
          else
            noteColumn,
          if (manyNotes)
            const Padding(
              padding: EdgeInsets.only(left: 1),
              child: Icon(Icons.unfold_more, size: 13, color: Palette.muted),
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

    // Bersaglio: bordo pieno (normale) o tratteggiato quando è attiva una
    // modalità di impilamento (accordo o abbellimento).
    final dashed = isTarget && (chordMode || runMode);
    final child = Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaying
            ? Palette.brass.withValues(alpha: 0.30)
            : (isTarget ? Palette.brassDeep.withValues(alpha: 0.35) : Palette.bg),
        borderRadius: BorderRadius.circular(8),
        border: dashed
            ? null
            : Border.all(
                color: isPlaying
                    ? Palette.brass
                    : (isTarget ? Palette.brass : Palette.line),
                width: (isTarget || isPlaying) ? 2 : 1,
              ),
      ),
      alignment: Alignment.center,
      child: content,
    );

    return GestureDetector(
      onTap: onTapChip,
      child: dashed
          ? CustomPaint(foregroundPainter: _DashedBorderPainter(), child: child)
          : child,
    );
  }

  Widget _fingerBadge(int? finger) {
    if (finger == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 1),
      child: Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Palette.brass,
          shape: BoxShape.circle,
        ),
        child: Text('$finger',
            style: mono(
                size: 9, weight: FontWeight.w700, color: Palette.bg)),
      ),
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
