import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/entry.dart';
import '../models/notation.dart';
import '../theme.dart';

/// Vista a tutto schermo delle note, formattata e con a-capo automatici,
/// senza tastiera. + / − per ridimensionare il testo.
class ScoreView extends StatefulWidget {
  final List<Entry> entries;
  final String? title;
  final bool italian;
  final Str tr;
  const ScoreView({
    super.key,
    required this.entries,
    required this.italian,
    required this.tr,
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
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(widget.tr.noNotes,
                          style: mono(size: 15, color: Palette.muted)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildSections(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ScoreViewState {
  /// Le etichette di testo diventano sottotitoli che dividono in sezioni;
  /// tra un sottotitolo e l'altro, le note scorrono in un Wrap.
  List<Widget> _buildSections() {
    final out = <Widget>[];
    var tokens = <Widget>[];

    void flush() {
      if (tokens.isEmpty) return;
      out.add(Wrap(
        spacing: _size * 0.45,
        runSpacing: _size * 0.55,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: tokens,
      ));
      tokens = <Widget>[];
    }

    for (final e in widget.entries) {
      if (e.isText) {
        flush();
        out.add(Padding(
          padding: EdgeInsets.only(
              top: out.isEmpty ? 0 : _size * 0.8, bottom: _size * 0.45),
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
      } else {
        tokens.add(
          _Token(text: formatEntry(e, italian: widget.italian), size: _size),
        );
      }
    }
    flush();
    return out;
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
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      child: Text(
        text,
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
