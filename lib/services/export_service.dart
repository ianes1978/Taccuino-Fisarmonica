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

    String giro(Entry a) =>
        a.basses.map((c) => bassLabel(c, italian: italian)).join(' ');

    // Layout a "sistemi": righe di voci; sotto le voci coperte da un appunto
    // di bassi, il giro in GRASSETTO allineato. La linea di copertura alterna
    // continua e tratteggiata fra appunti adiacenti: leggibile anche in
    // bianco e nero, pure quando il giro prosegue nella riga successiva.
    // Courier è monospaziato: larghezza carattere = 0.6 * corpo.
    const tokenFs = 12.0;
    const bassFs = 11.0;
    const gap = 6.0;
    double tokenW(String t) => t.length * tokenFs * 0.6 + 13;
    final avail = PdfPageFormat.a4.width - 64; // margini 32 + 32

    final anns = List.of(bassEntries)
      ..sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
    final labelDone = <Entry>{};
    final shown = <Entry>{};

    final body = <pw.Widget>[];
    var line = <(int, String, double)>[];
    var lineW = 0.0;

    pw.Widget lineWidget(List<(int, String, double)> line) {
      final xs = <double>[];
      var x = 0.0;
      for (final t in line) {
        xs.add(x);
        x += t.$3 + gap;
      }
      final lineWidth = x - gap;
      final segs = <pw.Widget>[];
      for (final a in anns) {
        int? first;
        int? last;
        for (var k = 0; k < line.length; k++) {
          if (line[k].$1 >= a.anchorStart && line[k].$1 < a.anchorEnd) {
            first ??= k;
            last = k;
          }
        }
        if (first == null || last == null) continue;
        shown.add(a);
        final left = xs[first];
        final w = xs[last] + line[last].$3 - left;
        // Linea continua o tratteggiata, alternate fra appunti adiacenti.
        final dashedLine = anns.indexOf(a).isOdd;
        // Etichetta solo sul primo segmento; le continuazioni hanno la linea.
        final label = labelDone.contains(a) ? '' : giro(a);
        labelDone.add(a);
        segs.add(pw.Positioned(
          left: left,
          top: 0,
          child: dashedLine
              ? pw.Container(
                  width: w,
                  height: 1.5,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.black,
                        width: 1.5,
                        style: pw.BorderStyle.dashed,
                      ),
                    ),
                  ),
                )
              : pw.Container(width: w, height: 1.5, color: PdfColors.black),
        ));
        if (label.isNotEmpty) {
          // Centrato sull'intervallo (allargato se l'etichetta è più lunga).
          final labelW = label.length * bassFs * 0.6 + 2;
          final effW = labelW > w ? labelW : w;
          segs.add(pw.Positioned(
            left: left - (effW - w) / 2,
            top: 3,
            child: pw.Container(
              width: effW,
              alignment: pw.Alignment.center,
              child: pw.Text(label,
                  style: pw.TextStyle(font: monoBold, fontSize: bassFs)),
            ),
          ));
        }
      }
      final melody = pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var k = 0; k < line.length; k++)
            pw.Padding(
              padding: pw.EdgeInsets.only(
                  right: k == line.length - 1 ? 0 : gap),
              child: token(line[k].$2),
            ),
        ],
      );
      if (segs.isEmpty) {
        return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6), child: melody);
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            melody,
            pw.SizedBox(height: 2),
            pw.SizedBox(
              width: lineWidth,
              height: 3 + bassFs * 1.3,
              child: pw.Stack(children: segs),
            ),
          ],
        ),
      );
    }

    void flushLine() {
      if (line.isEmpty) return;
      body.add(lineWidget(line));
      line = <(int, String, double)>[];
      lineW = 0;
    }

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.isText) {
        flushLine();
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
        continue;
      }
      final text = formatEntry(e, italian: italian);
      final w = tokenW(text);
      if (line.isNotEmpty && lineW + gap + w > avail) flushLine();
      lineW = line.isEmpty ? w : lineW + gap + w;
      line.add((i, text, w));
    }
    flushLine();

    final leftover = anns.where((a) => !shown.contains(a)).toList();
    if (leftover.isNotEmpty) {
      body.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(leftover.map(giro).join('   '),
            style: pw.TextStyle(font: monoBold, fontSize: bassFs)),
      ));
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
