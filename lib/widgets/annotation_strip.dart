import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entry.dart';
import '../models/notation.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'score_view.dart';
import 'text_prompt.dart';

/// Striscia dell'annotazione: chip inline per note singole, chip con note
/// incolonnate per gli accordi. Sotto, la riga degli appunti di bassi (rossi),
/// centrati sull'intervallo di voci che coprono. Header con play, copia, ecc.
class AnnotationStrip extends StatefulWidget {
  final AppState state;
  const AnnotationStrip({super.key, required this.state});

  @override
  State<AnnotationStrip> createState() => _AnnotationStripState();
}

class _AnnotationStripState extends State<AnnotationStrip> {
  // Le due righe (voci e bassi) scorrono insieme.
  final ScrollController _melCtrl = ScrollController();
  final ScrollController _bassCtrl = ScrollController();
  bool _syncing = false;

  // Geometria dei chip dell'ultimo build (per le maniglie di stretch).
  List<double> _xs = const [];
  List<double> _ws = const [];
  double _dragX = 0;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _melCtrl.addListener(() => _sync(_melCtrl, _bassCtrl));
    _bassCtrl.addListener(() => _sync(_bassCtrl, _melCtrl));
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  void dispose() {
    _melCtrl.dispose();
    _bassCtrl.dispose();
    super.dispose();
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: state.exportText));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(state.tr.copied, style: mono(size: 13)),
          backgroundColor: Palette.brassDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  // --- Larghezze dei chip ---------------------------------------------------
  // Per centrare gli appunti di bassi sotto le voci coperte serve la posizione
  // orizzontale di ogni chip: la calcoliamo misurando il testo con gli stessi
  // stili usati da _EntryChip (i chip vengono poi FORZATI a questa larghezza,
  // così le due righe restano allineate anche fuori dallo schermo).

  static const double _gap = 8; // spazio fra i chip
  static const double _chrome = 28; // padding orizzontale + bordo del chip
  static const double _slack = 6; // margine di sicurezza

  double _textW(String s, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  double _badgeW(int? f, int? f2) {
    if (f == null) return 0;
    final label = f2 == null ? '$f' : '$f-$f2';
    final w = _textW(label, mono(size: 9, weight: FontWeight.w700)) + 6;
    return 2 + (w < 14 ? 14 : w);
  }

  double _chipWidth(Entry e, bool italian) {
    final dashes = '-' * e.len;
    double content;
    if (e.isBass) {
      // Voce bassi rimasta inline (dati vecchi).
      content = 15 +
          _textW('⟨', mono(size: 16, weight: FontWeight.w700)) +
          _textW('⟩', mono(size: 16, weight: FontWeight.w700));
      for (final c in e.basses) {
        content +=
            4 + _textW(bassLabel(c, italian: italian), mono(size: 13, weight: FontWeight.w700));
      }
      if (dashes.isNotEmpty) {
        content += 3 + _textW(dashes, mono(size: 16, weight: FontWeight.w700));
      }
    } else if (e.isText) {
      final w = _textW(e.label ?? '', display(size: 14, weight: FontWeight.w600));
      content = 14 + 5 + (w > 150 ? 150 : w);
    } else if (e.run) {
      content = _textW('{', mono(size: 17, weight: FontWeight.w700)) +
          _textW('}', mono(size: 17, weight: FontWeight.w700));
      for (final m in e.midis) {
        content += 6 +
            _textW(noteLabel(m, italian: italian),
                mono(size: 13, weight: FontWeight.w700)) +
            _badgeW(e.fingerOf(m), e.finger2Of(m));
      }
      if (dashes.isNotEmpty) {
        content += 4 + _textW(dashes, mono(size: 16, weight: FontWeight.w700));
      }
    } else if (e.midis.length == 1) {
      final m = e.midis.first;
      content = _textW('${noteLabel(m, italian: italian)}$dashes',
              mono(size: 16, weight: FontWeight.w700)) +
          _badgeW(e.fingerOf(m), e.finger2Of(m));
    } else {
      // Accordo: colonna larga quanto la nota più larga.
      double col = 0;
      for (final m in e.midis) {
        final w = 4 +
            _textW(noteLabel(m, italian: italian),
                mono(size: 13, weight: FontWeight.w700)) +
            _badgeW(e.fingerOf(m), e.finger2Of(m));
        if (w > col) col = w;
      }
      final many = e.midis.length > 3;
      if (many && col > 96) col = 96;
      content = col + (many ? 14 : 0);
      if (dashes.isNotEmpty) {
        content += 4 + _textW(dashes, mono(size: 16, weight: FontWeight.w700));
      }
    }
    final w = content + _chrome + _slack;
    return w < 44 ? 44 : w;
  }

  @override
  Widget build(BuildContext context) {
    final empty = state.isEmpty;
    final n = state.sequence.length;
    final widths = <double>[
      for (final e in state.sequence) _chipWidth(e, state.italian),
    ];
    // Posizione x di ogni chip (il k-esimo inizia dopo k chip + spazi).
    final xs = <double>[];
    var acc = 0.0;
    for (final w in widths) {
      xs.add(acc);
      acc += w + _gap;
    }
    final totalW = acc;
    _xs = xs;
    _ws = widths;

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
              Text(state.tr.annotation,
                  style: mono(
                      size: 11,
                      color: Palette.muted,
                      weight: FontWeight.w700,
                      spacing: 1.5)),
              const Spacer(),
              _HeaderButton(
                icon: state.bassMode
                    ? Icons.piano
                    : Icons.radio_button_checked,
                tooltip: state.bassMode
                    ? state.tr.switchToKeyboard
                    : state.tr.switchToBass,
                onTap: () {
                  HapticFeedback.selectionClick();
                  state.toggleBassMode();
                },
              ),
              if (!empty) ...[
                _HeaderButton(
                  icon: Icons.visibility_outlined,
                  tooltip: state.tr.fullscreenView,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScoreView(
                          entries: List.of(state.sequence),
                          bassEntries: List.of(state.bassSeq),
                          title: state.loadedName,
                          italian: state.italian,
                          tr: state.tr,
                        ),
                      ),
                    );
                  },
                ),
                _HeaderButton(
                  icon: state.isPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: state.isPlaying ? state.tr.stop : state.tr.listen,
                  filled: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.togglePlay();
                  },
                ),
                _HeaderButton(
                  icon: Icons.copy_all_outlined,
                  tooltip: state.tr.copy,
                  onTap: () => _copy(context),
                ),
                _HeaderButton(
                  icon: Icons.refresh,
                  tooltip: state.tr.clear,
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
                      state.tr.emptyHint,
                      style: mono(size: 13, color: Palette.muted),
                    ),
                  )
                : ReorderableListView.builder(
                    scrollController: _melCtrl,
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: n,
                    onReorder: state.moveEntry,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: child,
                    ),
                    itemBuilder: (context, i) {
                      final entry = state.sequence[i];
                      final inRange = state.bassMode &&
                          state.hasBassRange &&
                          i >= state.bassSelStart! &&
                          i <= state.bassSelEnd!;
                      // Tieni premuto per spostare; tocco singolo per
                      // selezionare (in modalità bassi: scegli l'intervallo).
                      return ReorderableDelayedDragStartListener(
                        key: ObjectKey(entry),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(right: _gap),
                          child: SizedBox(
                            width: widths[i],
                            child: _EntryChip(
                              entry: entry,
                              italian: state.italian,
                              isTarget:
                                  !state.bassMode && state.targetIndex == i,
                              isPlaying: state.playingIndex == i,
                              chordMode: state.chordMode,
                              runMode: state.runMode,
                              inBassRange: inRange,
                              focusMidi:
                                  !state.bassMode && state.targetIndex == i
                                      ? state.effectiveFocusMidi
                                      : null,
                              onTapChip: () async {
                                if (state.bassMode) {
                                  state.tapMelodyForBassRange(i);
                                  return;
                                }
                                if (entry.isText) {
                                  // Tap sul testo: selezione + modifica.
                                  state.selectEntry(i);
                                  final text = await promptText(
                                    context,
                                    heading: state.tr.editText,
                                    hint: state.tr.textEmptyDeletes,
                                    initial: entry.label ?? '',
                                    confirm: state.tr.save,
                                    cancel: state.tr.cancel,
                                  );
                                  if (text != null) {
                                    state.editTextEntry(i, text);
                                  }
                                } else {
                                  state.selectEntry(i);
                                }
                              },
                              onTapNote: (m) {
                                if (state.bassMode) {
                                  state.tapMelodyForBassRange(i);
                                } else {
                                  state.focusNoteInEntry(i, m);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Riga degli appunti di bassi, allineata sotto le voci coperte.
          if (state.bassSeq.isNotEmpty || state.bassMode) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: _buildBassRow(n, widths, xs, totalW),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBassRow(
      int n, List<double> widths, List<double> xs, double totalW) {
    if (state.bassSeq.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(state.tr.bassNoteHint,
            style: mono(size: 11, color: Palette.muted)),
      );
    }
    if (n == 0) {
      // Appunti senza melodia (dati vecchi): fila semplice.
      return ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var j = 0; j < state.bassSeq.length; j++)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 5),
              child: _bassChip(j),
            ),
        ],
      );
    }
    final children = <Widget>[];
    // Intervallo selezionato: guida leggera sotto le voci scelte.
    if (state.bassMode && state.hasBassRange) {
      final s = state.bassSelStart!.clamp(0, n - 1);
      final e = state.bassSelEnd!.clamp(s, n - 1);
      final left = xs[s];
      final w = xs[e] + widths[e] - left;
      children.add(Positioned(
        left: left,
        top: 0,
        width: w,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.bassRed.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: Palette.bassRed.withValues(alpha: 0.35), width: 1),
          ),
        ),
      ));
    }
    for (var j = 0; j < state.bassSeq.length; j++) {
      final a = state.bassSeq[j];
      final s = a.anchorStart.clamp(0, n - 1);
      final e = (a.anchorEnd - 1).clamp(s, n - 1);
      final left = xs[s];
      final w = xs[e] + widths[e] - left;
      final selected = state.bassMode && state.selectedBass == j;
      // Linea di copertura: da dove a dove vale l'appunto.
      children.add(Positioned(
        left: left,
        top: 0,
        width: w,
        height: 3,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.bassRed.withValues(alpha: selected ? 0.95 : 0.55),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
      // Chip centrato sull'intervallo coperto.
      children.add(Positioned(
        left: left,
        top: 6,
        width: w,
        height: 30,
        child: Center(
          child: OverflowBox(
            maxWidth: double.infinity,
            child: _bassChip(j, selected: selected),
          ),
        ),
      ));
    }
    // Maniglie ai bordi dell'intervallo: trascina per stirare la selezione
    // (o l'appunto selezionato) senza sovrapporsi ai vicini.
    if (state.bassMode && state.hasBassRange) {
      final s = state.bassSelStart!.clamp(0, n - 1);
      final e = state.bassSelEnd!.clamp(s, n - 1);
      final left = xs[s];
      final right = xs[e] + widths[e];
      children.add(_edgeHandle(x: left, leftEdge: true));
      children.add(_edgeHandle(x: right, leftEdge: false));
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
        scrollbars: false,
      ),
      child: SingleChildScrollView(
        controller: _bassCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalW < 1 ? 1 : totalW,
          height: 40,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }

  /// Maniglia di stretch al bordo dell'intervallo selezionato.
  Widget _edgeHandle({required double x, required bool leftEdge}) {
    return Positioned(
      left: x - 10,
      top: 0,
      width: 20,
      height: 40,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          final n = _xs.length;
          if (n == 0 || !state.hasBassRange) return;
          final s = state.bassSelStart!.clamp(0, n - 1);
          final e = state.bassSelEnd!.clamp(s, n - 1);
          // Parte dal centro del chip al bordo: la soglia di aggancio
          // all'indice successivo scatta a metà chip.
          _dragX = leftEdge ? _xs[s] + _ws[s] / 2 : _xs[e] + _ws[e] / 2;
        },
        onHorizontalDragUpdate: (d) {
          if (_xs.isEmpty) return;
          _dragX += d.delta.dx;
          state.setBassRangeEdge(leftEdge: leftEdge, index: _indexAtX(_dragX));
        },
        child: Center(
          child: Container(
            width: 5,
            height: 26,
            decoration: BoxDecoration(
              color: Palette.bassRed,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  int _indexAtX(double x) {
    for (var i = 0; i < _xs.length; i++) {
      if (x < _xs[i] + _ws[i] + _gap / 2) return i;
    }
    return _xs.length - 1;
  }

  Widget _bassChip(int j, {bool selected = false}) {
    final entry = state.bassSeq[j];
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        state.selectBassEntry(j);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? Palette.bassRedDim.withValues(alpha: 0.55)
              : Palette.blackMid,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? Palette.bassRed
                : Palette.bassRed.withValues(alpha: 0.55),
            width: selected ? 2 : 1,
          ),
        ),
        // Ogni bottone del giro è toccabile: fuoco sul singolo basso
        // (⌫ cancella solo quello).
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 0; k < entry.basses.length; k++)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  state.focusBassInEntry(j, k);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: (selected && state.bassFocusIdx == k)
                      ? BoxDecoration(
                          color: Palette.bassRed.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    bassLabel(entry.basses[k], italian: state.italian),
                    style: mono(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Palette.bassRed),
                  ),
                ),
              ),
          ],
        ),
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

class _EntryChip extends StatefulWidget {
  final Entry entry;
  final bool italian;
  final bool isTarget;
  final bool isPlaying;
  final bool chordMode;
  final bool runMode;

  /// In modalità bassi: la voce fa parte dell'intervallo selezionato.
  final bool inBassRange;
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
    required this.inBassRange,
    required this.focusMidi,
    required this.onTapChip,
    required this.onTapNote,
  });

  @override
  State<_EntryChip> createState() => _EntryChipState();
}

class _EntryChipState extends State<_EntryChip> {
  // Controller della colonna dell'accordo: permette di far scorrere le note
  // trascinando OVUNQUE sul chip, non solo sopra la colonna.
  final ScrollController _chordScroll = ScrollController();

  Entry get entry => widget.entry;
  bool get italian => widget.italian;
  bool get isTarget => widget.isTarget;
  bool get isPlaying => widget.isPlaying;
  bool get chordMode => widget.chordMode;
  bool get runMode => widget.runMode;
  int? get focusMidi => widget.focusMidi;
  VoidCallback get onTapChip => widget.onTapChip;
  ValueChanged<int> get onTapNote => widget.onTapNote;

  @override
  void dispose() {
    _chordScroll.dispose();
    super.dispose();
  }

  void _dragChord(DragUpdateDetails d) {
    if (!_chordScroll.hasClients) return;
    final max = _chordScroll.position.maxScrollExtent;
    _chordScroll.jumpTo(
      (_chordScroll.offset - d.delta.dy).clamp(0.0, max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashes = '-' * entry.len;
    final Widget content;
    if (entry.isBass) {
      // Giro di bassi: bottoni in fila fra parentesi angolari.
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radio_button_checked,
              size: 12, color: Palette.muted),
          const SizedBox(width: 3),
          Text('⟨',
              style: mono(
                  size: 16, weight: FontWeight.w700, color: Palette.brass)),
          for (final c in entry.basses)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(bassLabel(c, italian: italian),
                  style: mono(size: 13, weight: FontWeight.w700)),
            ),
          Text('⟩',
              style: mono(
                  size: 16, weight: FontWeight.w700, color: Palette.brass)),
          if (dashes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child:
                  Text(dashes, style: mono(size: 16, weight: FontWeight.w700)),
            ),
        ],
      );
    } else if (entry.isText) {
      // Etichetta di sezione: stile distinto (Fraunces, icona testo).
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.text_fields, size: 14, color: Palette.muted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              entry.label ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: display(
                  size: 14, weight: FontWeight.w600, color: Palette.brass),
            ),
          ),
        ],
      );
    } else if (entry.run) {
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
                    _fingerBadge(entry.fingerOf(entry.midis[k]), entry.finger2Of(entry.midis[k])),
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
          _fingerBadge(entry.fingerOf(m), entry.finger2Of(m)),
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
                    _fingerBadge(entry.fingerOf(m), entry.finger2Of(m)),
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
                child: SingleChildScrollView(
                  controller: _chordScroll,
                  child: noteColumn,
                ),
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
    // modalità di impilamento (accordo o abbellimento). In modalità bassi
    // le voci dell'intervallo scelto si tingono di rosso.
    final dashed = isTarget && (chordMode || runMode);
    final inRange = widget.inBassRange;
    final child = Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaying
            ? Palette.brass.withValues(alpha: 0.30)
            : (inRange
                ? Palette.bassRed.withValues(alpha: 0.14)
                : (isTarget
                    ? Palette.brassDeep.withValues(alpha: 0.35)
                    : Palette.bg)),
        borderRadius: BorderRadius.circular(8),
        border: dashed
            ? null
            : Border.all(
                color: isPlaying
                    ? Palette.brass
                    : (inRange
                        ? Palette.bassRed
                        : (isTarget ? Palette.brass : Palette.line)),
                width: (isTarget || isPlaying || inRange) ? 2 : 1,
              ),
      ),
      alignment: Alignment.center,
      child: content,
    );

    // Accordo con molte note: il drag verticale su TUTTO il chip fa scorrere
    // la colonna (più comodo col dito che centrare la colonna stessa).
    final scrollableChord = !entry.run && entry.midis.length > 3;
    return GestureDetector(
      onTap: onTapChip,
      onVerticalDragUpdate: scrollableChord ? _dragChord : null,
      child: dashed
          ? CustomPaint(foregroundPainter: _DashedBorderPainter(), child: child)
          : child,
    );
  }

  Widget _fingerBadge(int? finger, [int? finger2]) {
    if (finger == null) return const SizedBox.shrink();
    final label = finger2 == null ? '$finger' : '$finger-$finger2';
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 1),
      child: Container(
        constraints: const BoxConstraints(minWidth: 14),
        height: 14,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.brass,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
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
