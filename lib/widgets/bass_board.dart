import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/notation.dart';
import '../theme.dart';

/// Bottoniera bassi Stradella (72 bassi, stile FR-1X): 12 righe ordinate
/// per quinte × 6 colonne (contrabbasso, basso, Magg, min, 7ª, dim).
/// Codice bottone = tipo*12 + nota (vedi Entry.basses).
class BassBoard extends StatefulWidget {
  final bool italian;
  final ValueChanged<int> onTap;

  const BassBoard({super.key, required this.italian, required this.onTap});

  @override
  State<BassBoard> createState() => _BassBoardState();
}

class _BassBoardState extends State<BassBoard> {
  static const double rowH = 52;

  /// Righe per quinte (dall'alto): Reb, Lab, Mib, Sib, Fa, DO, Sol, Re, La...
  static const List<int> _fifths = [1, 8, 3, 10, 5, 0, 7, 2, 9, 4, 11, 6];

  final ScrollController _scroll = ScrollController();
  bool _didCenter = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_didCenter) {
          _didCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            // Centra sulla riga del Do (indice 5).
            final target = 5 * rowH + rowH / 2 - constraints.maxHeight / 2;
            _scroll
                .jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
          });
        }
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.bg,
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      for (final pc in _fifths) _row(pc),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Intestazione colonne: 3ª  B  M  m  7  d
  Widget _header() {
    const labels = ['3ª', 'B', 'M', 'm', '7', 'd'];
    return Container(
      height: 26,
      decoration: const BoxDecoration(
        color: Palette.panel,
        border: Border(bottom: BorderSide(color: Palette.line)),
      ),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(l,
                    style: mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Palette.muted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(int pc) {
    return SizedBox(
      height: rowH,
      child: Row(
        children: [
          for (var type = 0; type < 6; type++)
            Expanded(child: Center(child: _button(pc, type))),
        ],
      ),
    );
  }

  Widget _button(int pc, int type) {
    final code = type * 12 + pc;
    final label = bassLabel(code, italian: widget.italian);
    final isBassCol = type == 1;
    // "Fossetta" di riferimento sul Do (come sullo strumento).
    final isDoBass = isBassCol && pc == 0;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(code);
        },
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isBassCol
                  ? const [Color(0xFF4A3D28), Palette.blackMid, Palette.blackBot]
                  : const [
                      Palette.blackTop,
                      Palette.blackMid,
                      Palette.blackBot
                    ],
            ),
            border: Border.all(
              color: isDoBass
                  ? Palette.brass
                  : (isBassCol ? Palette.brassDim : Palette.line),
              width: isDoBass ? 2.5 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 3, offset: Offset(1, 2)),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                style: mono(
                  size: isBassCol ? 13 : 11,
                  weight: isBassCol ? FontWeight.w800 : FontWeight.w700,
                  color: isBassCol ? Palette.brass : Palette.ivory,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
