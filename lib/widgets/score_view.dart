import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/entry.dart';
import '../models/notation.dart';
import '../theme.dart';

/// Vista a tutto schermo delle note, formattata e con a-capo automatici,
/// senza tastiera. + / − per ridimensionare il testo.
///
/// Se ci sono appunti di bassi, ogni riga diventa un "sistema" a due righe:
/// sopra le voci della tastiera, sotto (in rosso) i giri di bassi allineati
/// alle voci coperte. Quando un giro prosegue nella riga dopo, lo indica
/// una freccia (→).
class ScoreView extends StatefulWidget {
  final List<Entry> entries;
  final List<Entry> bassEntries;
  final String? title;
  final bool italian;
  final Str tr;
  const ScoreView({
    super.key,
    required this.entries,
    required this.italian,
    required this.tr,
    this.bassEntries = const [],
    this.title,
  });

  @override
  State<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends State<ScoreView> {
  double _size = 24;

  static const double _min = 14;
  static const double _max = 60;

  void _bump(double delta) {
    setState(() => _size = (_size + delta).clamp(_min, _max));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superiore
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: const BoxDecoration(
                color: Palette.bg,
                border: Border(bottom: BorderSide(color: Palette.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Palette.brass),
                    tooltip: widget.tr.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.title ?? widget.tr.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(size: 18, weight: FontWeight.w600),
                    ),
                  ),
                  _RoundBtn(
                    icon: Icons.remove,
                    tooltip: widget.tr.smaller,
                    enabled: _size > _min,
                    onTap: () => _bump(-4),
                  ),
                  const SizedBox(width: 8),
                  _RoundBtn(
                    icon: Icons.add,
                    tooltip: widget.tr.larger,
                    enabled: _size < _max,
                    onTap: () => _bump(4),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: widget.entries.isEmpty && widget.bassEntries.isEmpty
                  ? Center(
                      child: Text(widget.tr.noNotes,
                          style: mono(size: 15, color: Palette.muted)),
                    )
                  : LayoutBuilder(
                      builder: (context, cons) {
                        final avail = cons.maxWidth - 36; // padding 18+18
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                _buildSections(avail < 60 ? 60 : avail),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Token misurato: indice della voce, testo formattato, larghezza.
class _Tok {
  final int idx;
  final String text;
  final double w;
  _Tok(this.idx, this.text, this.w);
}

extension on _ScoreViewState {
  double _textW(String s, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  String _giro(Entry a) => a.basses
      .map((c) => bassLabel(c, italian: widget.italian))
      .join(' ');

  /// Spezza le voci in righe che stanno nella larghezza disponibile;
  /// le etichette di testo restano sottotitoli di sezione.
  List<Widget> _buildSections(double avail) {
    final out = <Widget>[];
    final gap = _size * 0.45;
    final runGap = _size * 0.55;
    final tokPad = _size * 0.7 + 4; // padding orizzontale + bordo + slack

    final anns = List.of(widget.bassEntries)
      ..sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
    final labelDone = <Entry>{};
    final shown = <Entry>{};

    var line = <_Tok>[];
    var lineW = 0.0;

    void flushLine() {
      if (line.isEmpty) return;
      out.add(_lineWidget(line, anns, labelDone, shown, gap, runGap));
      line = <_Tok>[];
      lineW = 0;
    }

    for (var i = 0; i < widget.entries.length; i++) {
      final e = widget.entries[i];
      if (e.isText) {
        flushLine();
        out.add(Padding(
          padding: EdgeInsets.only(
              top: out.isEmpty ? 0 : _size * 0.6, bottom: _size * 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.label ?? '',
                style: display(
                    size: _size * 0.95,
                    weight: FontWeight.w600,
                    color: Palette.brass),
              ),
              const SizedBox(height: 3),
              Container(height: 1.5, width: 120, color: Palette.brassDim),
            ],
          ),
        ));
        continue;
      }
      final text = formatEntry(e, italian: widget.italian);
      final w =
          _textW(text, mono(size: _size, weight: FontWeight.w700)) + tokPad;
      if (line.isNotEmpty && lineW + gap + w > avail) flushLine();
      lineW = line.isEmpty ? w : lineW + gap + w;
      line.add(_Tok(i, text, w));
    }
    flushLine();

    // Appunti mai mostrati (ancore oltre la fine: dati vecchi).
    final leftover = anns.where((a) => !shown.contains(a)).toList();
    if (leftover.isNotEmpty) {
      out.add(Padding(
        padding: EdgeInsets.only(top: _size * 0.4),
        child: Text(
          leftover.map(_giro).join('   '),
          style: mono(
              size: _size * 0.85,
              weight: FontWeight.w700,
              color: Palette.bassRed),
        ),
      ));
    }
    return out;
  }

  /// Una riga del "sistema": voci sopra; se coperte da appunti, giri di
  /// bassi in rosso sotto, allineati (con frecce di continuazione).
  Widget _lineWidget(List<_Tok> line, List<Entry> anns, Set<Entry> labelDone,
      Set<Entry> shown, double gap, double runGap) {
    final xs = <double>[];
    var x = 0.0;
    for (final t in line) {
      xs.add(x);
      x += t.w + gap;
    }
    final lineWidth = x - gap;
    final lastIdx = line.last.idx;

    final segs = <Widget>[];
    for (final a in anns) {
      int? first;
      int? last;
      for (var k = 0; k < line.length; k++) {
        if (line[k].idx >= a.anchorStart && line[k].idx < a.anchorEnd) {
          first ??= k;
          last = k;
        }
      }
      if (first == null || last == null) continue;
      shown.add(a);
      final left = xs[first];
      final w = xs[last] + line[last].w - left;
      final contNext = a.anchorEnd - 1 > lastIdx;
      String label;
      if (labelDone.contains(a)) {
        label = contNext ? '→   →' : '→';
      } else {
        label = _giro(a);
        if (contNext) label = '$label →';
        labelDone.add(a);
      }
      segs.add(Positioned(
        left: left,
        top: 0,
        width: w,
        height: 2.5,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.bassRed.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ));
      segs.add(Positioned(
        left: left,
        top: 4,
        width: w,
        height: _size * 1.15,
        child: Center(
          child: OverflowBox(
            maxWidth: double.infinity,
            child: Text(
              label,
              maxLines: 1,
              style: mono(
                  size: _size * 0.8,
                  weight: FontWeight.w700,
                  color: Palette.bassRed),
            ),
          ),
        ),
      ));
    }

    final melody = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var k = 0; k < line.length; k++)
          Padding(
            padding:
                EdgeInsets.only(right: k == line.length - 1 ? 0 : gap),
            child: SizedBox(
              width: line[k].w,
              child: _Token(text: line[k].text, size: _size),
            ),
          ),
      ],
    );

    if (segs.isEmpty) {
      return Padding(
          padding: EdgeInsets.only(bottom: runGap), child: melody);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: runGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          melody,
          const SizedBox(height: 3),
          SizedBox(
            width: lineWidth,
            height: 4 + _size * 1.15,
            child: Stack(clipBehavior: Clip.none, children: segs),
          ),
        ],
      ),
    );
  }
}

class _Token extends StatelessWidget {
  final String text;
  final double size;
  const _Token({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.35, vertical: size * 0.2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: mono(size: size, weight: FontWeight.w700),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  const _RoundBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Palette.brassDim, width: 1.5),
          ),
          child: Icon(icon,
              color: enabled ? Palette.brass : Palette.brassDeep, size: 22),
        ),
      ),
    );
  }
}
