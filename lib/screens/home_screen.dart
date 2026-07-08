import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/saved_song.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';
import 'settings_screen.dart';
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
                    focusMidi: state.keyboardFocusMidi,
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
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Taccuino Fisarmonica',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: display(size: 17, weight: FontWeight.w600)),
          ),
          _HeaderToggle(
            label: state.italian ? 'Do Re Mi' : 'C D E',
            tooltip: state.tr.namesTooltip,
            onTap: () {
              HapticFeedback.selectionClick();
              state.toggleNames();
            },
          ),
          const SizedBox(width: 8),
          _HeaderToggle(
            label: state.audioOn ? '♪' : '×',
            tooltip: state.audioOn ? state.tr.audioOn : state.tr.muted,
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
        } else if (v == 'list') {
          _showLoadSheet(context, state);
        } else if (v == 'pdf') {
          _exportPdf(context, state);
        } else if (v == 'settings') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SettingsScreen(state: state)),
          );
        }
      },
      itemBuilder: (context) => [
        _menuItem(
            'quicksave',
            Icons.save,
            state.loadedName != null
                ? state.tr.menuSaveNamed(state.loadedName!)
                : state.tr.menuSave),
        _menuItem('saveas', Icons.save_as_outlined, state.tr.menuSaveAs),
        _menuItem('list', Icons.library_music_outlined, state.tr.menuList),
        const PopupMenuDivider(),
        _menuItem('pdf', Icons.picture_as_pdf_outlined, state.tr.menuExportPdf),
        _menuItem('settings', Icons.settings_outlined, state.tr.menuSettings),
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
    _toast(context, state.tr.nothingToExport);
    return;
  }
  final title = await _promptText(
    context,
    heading: state.tr.pdfDialogTitle,
    hint: state.tr.pdfTitleHint,
    initial: state.loadedName ?? '',
    confirm: state.tr.export,
    cancel: state.tr.cancel,
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
    if (context.mounted) _toast(context, state.tr.pdfExportFailed);
  }
}

/// Dialog generico con un campo di testo. Ritorna null se annullato.
Future<String?> _promptText(
  BuildContext context, {
  required String heading,
  required String hint,
  String initial = '',
  String confirm = 'OK',
  String cancel = 'Annulla',
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
          child: Text(cancel, style: mono(size: 14, color: Palette.muted)),
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
    if (context.mounted) _toast(context, state.tr.importNothing);
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
            ? state.tr.importedOne(lastName ?? '')
            : state.tr.importedMany(list.length));
  }
}

void _quickSave(BuildContext context, AppState state) {
  if (state.isEmpty) {
    _toast(context, state.tr.nothingToSave);
    return;
  }
  final name = state.loadedName;
  if (name == null) {
    // Nessun brano caricato: chiedi il nome.
    _showSaveDialog(context, state);
    return;
  }
  state.saveCurrentAs(name);
  _toast(context, state.tr.savedToast(name));
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
        content: Text(state.tr.nothingToSave, style: mono(size: 13)),
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
      title: Text(state.tr.menuSaveAs, style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: state.tr.songNameHint,
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
          child: Text(state.tr.cancel, style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(state.tr.save, style: mono(size: 14, color: Palette.brass)),
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
              overwrite
                  ? state.tr.overwrittenToast(name)
                  : state.tr.savedToast(name),
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
                Text(state.tr.savedSongs,
                    style: display(size: 18, weight: FontWeight.w600)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _importJson(context, state),
                      icon: const Icon(Icons.file_upload_outlined,
                          size: 18, color: Palette.brass),
                      label: Text(state.tr.importFile,
                          style: mono(size: 12, color: Palette.brass)),
                    ),
                    const Spacer(),
                    if (songs.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          ExportService.exportAllSongs(state.songs);
                          _toast(context, state.tr.exportedAll(state.songs.length));
                        },
                        icon: const Icon(Icons.archive_outlined,
                            size: 18, color: Palette.brass),
                        label: Text(state.tr.exportAll,
                            style: mono(size: 12, color: Palette.brass)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (songs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(state.tr.noSongs,
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
                            '${state.tr.entriesCount(s.noteCount)} · ${_fmtDate(s.savedAt)}',
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
                            tooltip: state.tr.actions,
                            onSelected: (v) {
                              switch (v) {
                                case 'preview':
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ScoreView(
                                        entries: s.entries,
                                        title: s.name,
                                        italian: state.italian,
                                        tr: state.tr,
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
                                  state.tr.preview),
                              _menuItem('json', Icons.download_outlined,
                                  state.tr.exportJson),
                              _menuItem('rename', Icons.edit_outlined,
                                  state.tr.rename),
                              _menuItem('delete', Icons.delete_outline,
                                  state.tr.delete),
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
      title: Text(state.tr.rename, style: display(size: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: mono(size: 15),
        cursorColor: Palette.brass,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: state.tr.newNameHint,
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
          child: Text(state.tr.cancel, style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(state.tr.rename, style: mono(size: 14, color: Palette.brass)),
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
      title: Text(state.tr.deleteQuestion, style: display(size: 17)),
      content: Text(state.tr.deleteMessage(name),
          style: mono(size: 14, color: Palette.ivory)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(state.tr.cancel, style: mono(size: 14, color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(state.tr.delete, style: mono(size: 14, color: Palette.brass)),
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
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.panel,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active ? Palette.brassDim : Palette.brassDeep,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: mono(
                size: 12,
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
