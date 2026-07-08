import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_song.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/annotation_strip.dart';
import '../widgets/control_bar.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/score_view.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            return Column(
              children: [
                _Header(state: state),
                AnnotationStrip(state: state),
                ControlBar(state: state),
                Expanded(
                  child: PianoKeyboard(
                    italian: state.italian,
                    onTap: state.onKeyTap,
                    highlightedMidis: state.highlightedMidis,
                    fingers: state.highlightedFingers,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.bg,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Taccuino Fisarmonica',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(size: 21, weight: FontWeight.w600)),
                Text('blocco note musicale',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(size: 10, color: Palette.muted, spacing: 1)),
              ],
            ),
          ),
          _HeaderToggle(
            label: state.italian ? 'Do Re Mi' : 'C D E',
            tooltip: 'Sistema nomi',
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleNames();
            },
          ),
          const SizedBox(width: 8),
          _HeaderToggle(
            label: state.audioOn ? '♪' : '×',
            tooltip: state.audioOn ? 'Audio attivo' : 'Muto',
            active: state.audioOn,
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleAudio();
            },
          ),
          const SizedBox(width: 4),
          _MenuButton(state: state),
        ],
      ),
    );
  }
}

/// Menu con Salva con nome / Carica.
class _MenuButton extends StatelessWidget {
  final AppState state;
  const _MenuButton({required this.state});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: const Icon(Icons.menu, color: Palette.brass),
      color: Palette.panel,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onSelected: (v) {
        if (v == 'quicksave') {
          _quickSave(context, state);
        } else if (v == 'saveas') {
          _showSaveDialog(context, state);
        } else if (v == 'load') {
          _showLoadSheet(context, state);
        } else if (v == 'pdf') {
          _exportPdf(context, state);
        } else if (v == 'import') {
          _importJson(context, state);
        }
      },
      itemBuilder: (context) => [
        _menuItem('quicksave', Icons.save,
            state.loadedName != null ? 'Salva "${state.loadedName}"' : 'Salva'),
        _menuItem('saveas', Icons.save_as_outlined, 'Salva con nome'),
        _menuItem('load', Icons.folder_open_outlined, 'Carica…'),
        const PopupMenuDivider(),
        _menuItem('pdf', Icons.picture_as_pdf_outlined, 'Esporta PDF'),
        _menuItem('import', Icons.file_upload_outlined, 'Importa JSON…'),
      ],
    );
  }
}

PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(children: [
      Icon(icon, size: 20, color: Palette.ivory),
      const SizedBox(width: 10),
      Text(label, style: mono(size: 14)),
    ]),
  );
}

Future<void> _exportPdf(BuildContext context, AppState state) async {
  if (state.isEmpty) {
    _toast(context, 'Niente da esportare');
    return;
  }
  final title = await _promptText(
    context,
    heading: 'Esporta PDF',
    hint: 'Titolo del PDF',
    initial: state.loadedName ?? '',
    confirm: 'Esporta',
  );
  if (title == null) return; // annullato
  final t = title.trim();
  try {
    await ExportService.exportPdf(
      entries: state.sequence,
      italian: state.italian,
      title: t.isEmpty ? null : t,
    );
  } catch (_) {
    if (context.mounted) _toast(context, 'Export PDF non riuscito');
  }
}

/// Dialog generico con un campo di testo. Ritorna null se annullato.
Future<String?> _promptText(
  BuildContext context, {
  required String heading,
  required String hint,
  String initial = '',
  String confirm = 'OK',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text(heading, style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: mono(size: 14, color: Palette.muted),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brassDim)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brass)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Annulla', style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirm, style: mono(size: 14, color: Palette.brass)),
        ),
      ],
    ),
  );
}

Future<void> _importJson(BuildContext context, AppState state) async {
  List<SavedSong>? list;
  try {
    list = await ExportService.importSongs();
  } catch (_) {
    list = null;
  }
  if (list == null || list.isEmpty) {
    if (context.mounted) _toast(context, 'Nessun file importato');
    return;
  }
  String? lastName;
  for (final s in list) {
    lastName = state.addImportedSong(s);
  }
  if (context.mounted) {
    _toast(
        context,
        list.length == 1
            ? 'Importato "$lastName"'
            : 'Importate ${list.length} musiche');
  }
}

void _quickSave(BuildContext context, AppState state) {
  if (state.isEmpty) {
    _toast(context, 'Niente da salvare');
    return;
  }
  final name = state.loadedName;
  if (name == null) {
    // Nessun brano caricato: chiedi il nome.
    _showSaveDialog(context, state);
    return;
  }
  state.saveCurrentAs(name);
  _toast(context, 'Salvato "$name"');
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: mono(size: 13)),
      backgroundColor: Palette.brassDeep,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1500),
    ));
}

Future<void> _showSaveDialog(BuildContext context, AppState state) async {
  if (state.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Niente da salvare', style: mono(size: 13)),
        backgroundColor: Palette.brassDeep,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ));
    return;
  }
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text('Salva con nome', style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Nome della musica',
          hintStyle: mono(size: 14, color: Palette.muted),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brassDim)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brass)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Annulla', style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text('Salva', style: mono(size: 14, color: Palette.brass)),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty) {
    final overwrite = state.hasSongNamed(name);
    state.saveCurrentAs(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
              overwrite ? 'Sovrascritto "$name"' : 'Salvato "$name"',
              style: mono(size: 13)),
          backgroundColor: Palette.brassDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ));
    }
  }
}

void _showLoadSheet(BuildContext context, AppState state) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    builder: (ctx) => AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final songs = [...state.songs]
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Musiche salvate',
                    style: display(size: 18, weight: FontWeight.w600)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _importJson(context, state),
                      icon: const Icon(Icons.file_upload_outlined,
                          size: 18, color: Palette.brass),
                      label: Text('Importa file',
                          style: mono(size: 12, color: Palette.brass)),
                    ),
                    const Spacer(),
                    if (songs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          ExportService.exportAllSongs(state.songs);
                          _toast(context, 'Esportate ${state.songs.length} musiche');
                        },
                        icon: const Icon(Icons.archive_outlined,
                            size: 18, color: Palette.brass),
                        label: Text('Esporta tutte',
                            style: mono(size: 12, color: Palette.brass)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (songs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nessuna musica salvata.',
                        style: mono(size: 14, color: Palette.muted)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: songs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Palette.line, height: 1),
                      itemBuilder: (context, i) {
                        final s = songs[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.name,
                              style: mono(size: 15, weight: FontWeight.w700)),
                          subtitle: Text(
                            '${s.noteCount} voci · ${_fmtDate(s.savedAt)}',
                            style: mono(size: 11, color: Palette.muted),
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            state.loadSong(s);
                            Navigator.pop(ctx);
                          },
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Palette.muted),
                            color: Palette.panel,
                            tooltip: 'Azioni',
                            onSelected: (v) {
                              switch (v) {
                                case 'preview':
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ScoreView(
                                        entries: s.entries,
                                        title: s.name,
                                        italian: state.italian,
                                      ),
                                    ),
                                  );
                                  break;
                                case 'json':
                                  ExportService.exportSongJson(s);
                                  break;
                                case 'rename':
                                  _showRenameDialog(context, state, s.name);
                                  break;
                                case 'delete':
                                  _confirmDelete(context, state, s.name);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              _menuItem('preview', Icons.visibility_outlined,
                                  'Anteprima'),
                              _menuItem('json', Icons.download_outlined,
                                  'Esporta JSON'),
                              _menuItem(
                                  'rename', Icons.edit_outlined, 'Rinomina'),
                              _menuItem(
                                  'delete', Icons.delete_outline, 'Elimina'),
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
      },
    ),
  );
}

Future<void> _showRenameDialog(
    BuildContext context, AppState state, String oldName) async {
  final controller = TextEditingController(text: oldName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text('Rinomina', style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Nuovo nome',
          hintStyle: mono(size: 14, color: Palette.muted),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brassDim)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Palette.brass)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Annulla', style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text('Rinomina', style: mono(size: 14, color: Palette.brass)),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty && name.trim() != oldName) {
    state.renameSong(oldName, name);
  }
}

Future<void> _confirmDelete(
    BuildContext context, AppState state, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.panel,
      title: Text('Eliminare?', style: display(size: 17)),
      content: Text('Rimuovo "$name" dalle musiche salvate.',
          style: mono(size: 14, color: Palette.ivory)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Annulla', style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Elimina', style: mono(size: 14, color: Palette.brass)),
        ),
      ],
    ),
  );
  if (ok == true) state.deleteSong(name);
}

String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _HeaderToggle extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _HeaderToggle({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? Palette.brassDim : Palette.brassDeep,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: mono(
                size: 14,
                weight: FontWeight.w700,
                color: active ? Palette.brass : Palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
