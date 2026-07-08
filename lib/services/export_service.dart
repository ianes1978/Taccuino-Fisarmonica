import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    List<Entry> bassEntries = const [],
    String bassHeading = 'Bassi',
  }) async {
    final doc = pw.Document();
    final heading = title ?? 'Taccuino Fisarmonica';
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();

    pw.Widget token(String t) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(t, style: pw.TextStyle(font: mono, fontSize: 12)),
        );

    // Le etichette di testo diventano sottotitoli che dividono in sezioni.
    final body = <pw.Widget>[];
    var tokens = <pw.Widget>[];
    void flush() {
      if (tokens.isEmpty) return;
      body.add(pw.Wrap(spacing: 6, runSpacing: 6, children: tokens));
      tokens = <pw.Widget>[];
    }

    for (final e in entries) {
      if (e.isText) {
        flush();
        body.add(pw.Padding(
          padding: pw.EdgeInsets.only(top: body.isEmpty ? 0 : 14, bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(e.label ?? '',
                  style: pw.TextStyle(font: monoBold, fontSize: 14)),
              pw.SizedBox(height: 2),
              pw.Container(height: 1, width: 110, color: PdfColors.grey700),
            ],
          ),
        ));
      } else {
        tokens.add(token(formatEntry(e, italian: italian)));
      }
    }
    flush();

    if (bassEntries.isNotEmpty) {
      body.add(pw.Padding(
        padding: pw.EdgeInsets.only(top: body.isEmpty ? 0 : 16, bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(bassHeading,
                style: pw.TextStyle(font: monoBold, fontSize: 14)),
            pw.SizedBox(height: 2),
            pw.Container(height: 1, width: 110, color: PdfColors.grey700),
          ],
        ),
      ));
      body.add(pw.Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in bassEntries) token(formatEntry(e, italian: italian)),
      ]));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(heading,
              style: pw.TextStyle(font: monoBold, fontSize: 20)),
          pw.SizedBox(height: 16),
          ...body,
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${safeName(heading)}.pdf');
  }

  // --- JSON ----------------------------------------------------------------

  /// Salva bytes JSON in modo visibile all'utente:
  ///  - web: download automatico (saveFile);
  ///  - Android/desktop: dialog di sistema "Salva con nome" (saveAs).
  ///    saveFile su Android scriverebbe nella cartella privata dell'app,
  ///    invisibile all'utente — per questo l'export "sembrava non funzionare".
  static Future<void> _saveJsonBytes(String name, Uint8List bytes) async {
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
    } else {
      await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
    }
  }

  /// Esporta una musica in un file `[titolo].json` autoconsistente.
  static Future<void> exportSongJson(SavedSong song) async {
    final envelope = {
      'app': appTag,
      'version': formatVersion,
      'song': song.toJson(),
    };
    final str = const JsonEncoder.withIndent('  ').convert(envelope);
    final bytes = Uint8List.fromList(utf8.encode(str));
    await _saveJsonBytes(safeName(song.name), bytes);
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
    await _saveJsonBytes('taccuino-fisarmonica', bytes);
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
