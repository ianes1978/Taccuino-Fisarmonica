import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/notation.dart';
import '../theme.dart';

/// Bottoniera bassi Stradella (72 bassi, stile FR-1X): 12 righe ordinate
/// per quinte × 6 colonne (contrabbasso, basso, Magg, min, 7ª, dim).
/// Le colonne sono sfalsate in diagonale come sullo strumento e i bassi
/// di riferimento (La♭, Do, Mi) portano la "fossetta".
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
  static const double btn = 46;

  /// Sfalsamento verticale fra colonne adiacenti: crea le diagonali
  /// dei bassi come sulla bottoniera reale.
  static const double diag = 22;

  /// Righe per quinte (dall'alto): Fa#, Si, Mi, La, Re, Sol, DO, Fa,
  /// Sib, Mib, Lab, Reb — i diesis verso l'alto, i bemolli verso il basso.
  static const List<int> _fifths = [6, 11, 4, 9, 2, 7, 0, 5, 10, 3, 8, 1];

  /// Indice della riga del Do.
  static const int _doRow = 6;

  final ScrollController _scroll = ScrollController();
  bool _didCenter = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Posizione verticale del bottone: la colonna più a destra (dim) è più
  /// in alto, quella del contrabbasso più in basso — diagonali che salgono
  /// verso destra, come sullo strumento.
  double _topOf(int rowIdx, int type) =>
      rowIdx * rowH + (rowH - btn) / 2 + (5 - type) * diag;

  @override
  Widget build(BuildContext context) {
    final totalH = 12 * rowH + 5 * diag;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_didCenter) {
          _didCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            // Centra sulla riga del Do.
            final target = _topOf(_doRow, 1) +
                btn / 2 -
                (constraints.maxHeight - 26) / 2;
            _scroll
                .jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
          });
        }
        final colW = constraints.maxWidth / 6;
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
                  child: SizedBox(
                    height: totalH,
                    width: constraints.maxWidth,
                    child: Stack(
                      children: [
                        for (var r = 0; r < _fifths.length; r++)
                          for (var type = 0; type < 6; type++)
                            Positioned(
                              left: type * colW + (colW - btn) / 2,
                              top: _topOf(r, type),
                              child: _button(_fifths[r], type),
                            ),
                      ],
                    ),
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

  Widget _button(int pc, int type) {
    final code = type * 12 + pc;
    final label = bassLabel(code, italian: widget.italian);
    final isBassCol = type == 1;
    // "Fossette" di riferimento come sullo strumento: Do (principale),
    // Mi e Lab (secondarie) sulla colonna dei bassi.
    final isDoBass = isBassCol && pc == 0;
    final isRefBass = isBassCol && (pc == 4 || pc == 8);
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
          width: btn,
          height: btn,
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
                  : (isRefBass
                      ? Palette.brassDim
                      : (isBassCol ? Palette.brassDim : Palette.line)),
              width: (isDoBass || isRefBass) ? 2.5 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54, blurRadius: 3, offset: Offset(1, 2)),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
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
              // Fossetta: puntino sotto l'etichetta.
              if (isDoBass || isRefBass)
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDoBass ? Palette.brass : Palette.brassDim,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
