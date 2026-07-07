import 'package:flutter/material.dart';

import '../models/notation.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Vista a tutto schermo delle note, formattata e con a-capo automatici,
/// senza tastiera. + / − per ridimensionare il testo.
class ScoreView extends StatefulWidget {
  final AppState state;
  const ScoreView({super.key, required this.state});

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
    final state = widget.state;
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
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      state.loadedName ?? 'Anteprima',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: display(size: 18, weight: FontWeight.w600),
                    ),
                  ),
                  _RoundBtn(
                    icon: Icons.remove,
                    tooltip: 'Riduci',
                    enabled: _size > _min,
                    onTap: () => _bump(-4),
                  ),
                  const SizedBox(width: 8),
                  _RoundBtn(
                    icon: Icons.add,
                    tooltip: 'Ingrandisci',
                    enabled: _size < _max,
                    onTap: () => _bump(4),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: state,
                builder: (context, _) {
                  if (state.isEmpty) {
                    return Center(
                      child: Text('Nessuna nota.',
                          style: mono(size: 15, color: Palette.muted)),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: _size * 0.45,
                      runSpacing: _size * 0.55,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final e in state.sequence)
                          _Token(
                            text: formatEntry(e, italian: state.italian),
                            size: _size,
                          ),
                      ],
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
