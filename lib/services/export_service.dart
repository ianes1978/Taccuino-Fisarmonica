import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/entry.dart';
import '../models/notation.dart';
import '../models/saved_song.dart';

/// Import/Export: PDF (stampa/condivisione) e JSON (portabile).
class ExportService {
  static const String appTag = 'taccuino-fisarmonica';
  static const int formatVersion = 1;

  /// Nome file sicuro (senza caratteri problematici).
  static String safeName(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[^\w\-. ]+'), '_');
    return cleaned.isEmpty ? 'taccuino' : cleaned;
  }

  // --- PDF -----------------------------------------------------------------

  static Future<void> exportPdf({
    required List<Entry> entries,
    required bool italian,
    String? title,
  }) async {
    final doc = pw.Document();
    final heading = title ?? 'Taccuino Fisarmonica';
    final tokens = entries.map((e) => formatEntry(e, italian: italian)).toList();
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(heading,
              style: pw.TextStyle(font: monoBold, fontSize: 20)),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tokens)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border:
                        pw.Border.all(color: PdfColors.grey600, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(t,
                      style: pw.TextStyle(font: mono, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${safeName(heading)}.pdf');
  }

  // --- JSON ----------------------------------------------------------------

  /// Esporta una musica in un file `[titolo].json` autoconsistente.
  static Future<void> exportSongJson(SavedSong song) async {
    final envelope = {
      'app': appTag,
      'version': formatVersion,
      'song': song.toJson(),
    };
    final str = const JsonEncoder.withIndent('  ').convert(envelope);
    final bytes = Uint8List.fromList(utf8.encode(str));
    await FileSaver.instance.saveFile(
      name: safeName(song.name),
      bytes: bytes,
      ext: 'json',
      mimeType: MimeType.other,
    );
  }

  /// Esporta TUTTE le musiche in un unico file `taccuino-fisarmonica.json`.
  static Future<void> exportAllSongs(List<SavedSong> songs) async {
    final envelope = {
      'app': appTag,
      'version': formatVersion,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
    final str = const JsonEncoder.withIndent('  ').convert(envelope);
    final bytes = Uint8List.fromList(utf8.encode(str));
    await FileSaver.instance.saveFile(
      name: 'taccuino-fisarmonica',
      bytes: bytes,
      ext: 'json',
      mimeType: MimeType.other,
    );
  }

  /// Importa da un file JSON scelto dall'utente. Accetta sia un singolo brano
  /// (`song`/`entries`) sia una libreria (`songs`). Ritorna null se annullato
  /// o non valido, altrimenti la lista (1+ musiche).
  static Future<List<SavedSong>?> importSongs() async {
    // file_picker 10.x: API a istanza (la 11 passa ai metodi statici).
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final data = res.files.first.bytes;
    if (data == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      if (map['songs'] is List) {
        return (map['songs'] as List)
            .whereType<Map>()
            .map((e) => SavedSong.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      final songJson = (map['song'] is Map)
          ? (map['song'] as Map).cast<String, dynamic>()
          : map;
      if (songJson['entries'] is! List) return null;
      return [SavedSong.fromJson(songJson)];
    } catch (_) {
      return null;
    }
  }
}
