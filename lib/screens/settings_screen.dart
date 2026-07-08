import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Impostazioni: per ora la lingua dell'interfaccia.
class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final tr = state.tr;
        return Scaffold(
          backgroundColor: Palette.bg,
          appBar: AppBar(
            backgroundColor: Palette.bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Palette.brass),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(tr.settingsTitle,
                style: display(size: 18, weight: FontWeight.w600)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(tr.language,
                    style: mono(
                        size: 12,
                        color: Palette.muted,
                        weight: FontWeight.w700,
                        spacing: 1)),
              ),
              _langTile(context, 'system', tr.systemLanguage),
              _langTile(context, 'it', 'Italiano'),
              _langTile(context, 'en', 'English'),
              _langTile(context, 'pt', 'Português'),
            ],
          ),
        );
      },
    );
  }

  Widget _langTile(BuildContext context, String value, String label) {
    final selected = state.uiLang == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? Palette.brass : Palette.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => state.setUiLang(value),
        title: Text(label,
            style: mono(
                size: 15,
                weight: FontWeight.w700,
                color: selected ? Palette.brass : Palette.ivory)),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Palette.brass)
            : const Icon(Icons.circle_outlined, color: Palette.muted),
      ),
    );
  }
}
