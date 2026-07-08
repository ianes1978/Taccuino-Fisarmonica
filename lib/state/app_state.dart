import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/synth.dart';
import '../l10n/strings.dart';
import '../models/entry.dart';
import '../models/notation.dart';
import '../models/saved_song.dart';

class AppState extends ChangeNotifier {
  final Synth _synth = Synth();

  final List<Entry> sequence = [];

  /// Appunti di bassi: ciascuno è ancorato a un intervallo contiguo di voci
  /// della melodia (promemoria visivo, non riprodotto dal Play).
  final List<Entry> bassSeq = [];

  /// Indice dell'appunto di bassi selezionato; null = ultimo.
  int? selectedBass;

  /// Intervallo di voci della melodia selezionato (in modalità bassi) a cui
  /// ancorare il prossimo appunto: indici inclusivi, start <= end.
  int? bassSelStart;
  int? bassSelEnd;

  bool get hasBassRange => bassSelStart != null && bassSelEnd != null;

  /// Indice del bottone a fuoco dentro l'appunto selezionato (per cancellare
  /// un solo basso del giro); null = ultimo.
  int? bassFocusIdx;

  /// Musiche salvate con nome.
  final List<SavedSong> songs = [];

  /// Nome della musica attualmente caricata/salvata (null = bozza).
  String? loadedName;

  /// Indice della voce selezionata; null = "l'ultima".
  int? selected;

  /// Nota (midi) messa a fuoco dentro la voce bersaglio, per la diteggiatura.
  int? focusMidi;

  bool chordMode = false;

  /// Modalità abbellimento: i tasti si accodano in orizzontale (in ordine).
  bool runMode = false;

  bool italian = true;
  bool audioOn = true;

  /// Lingua dell'interfaccia: 'system' | 'it' | 'en' | 'pt'.
  String uiLang = 'system';

  /// Stringhe UI nella lingua corrente.
  Str get tr => resolveStrings(uiLang);

  void setUiLang(String v) {
    uiLang = v;
    _commit();
  }

  /// Velocità degli abbellimenti (1 = lento .. 5 = veloce).
  int ornamentSpeed = 3;
  static const List<int> _gapMs = [150, 110, 80, 55, 35];
  int get ornamentGapMs => _gapMs[(ornamentSpeed - 1).clamp(0, 4)];

  /// Modalità "prova": i tasti suonano soltanto, senza scrivere.
  bool practiceMode = false;

  /// Bottoniera bassi al posto della tastiera.
  bool bassMode = false;

  void toggleBassMode() {
    bassMode = !bassMode;
    notifyListeners();
  }

  /// Riproduzione in corso.
  bool isPlaying = false;
  int? playingIndex;
  int _playToken = 0;

  SharedPreferences? _prefs;

  // --- Ciclo di vita -------------------------------------------------------

  Future<void> load() async {
    await _synth.init();
    _prefs = await SharedPreferences.getInstance();
    italian = _prefs?.getBool('italian') ?? true;
    audioOn = _prefs?.getBool('audioOn') ?? true;
    ornamentSpeed = (_prefs?.getInt('ornamentSpeed') ?? 3).clamp(1, 5);
    uiLang = _prefs?.getString('uiLang') ?? 'system';
    playbackSpeed = (_prefs?.getDouble('playbackSpeed') ?? 1.0).clamp(0.5, 2.0);
    final raw = _prefs?.getString('sequence');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        sequence
          ..clear()
          ..addAll(list
              .map((e) => Entry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // dati corrotti: riparti pulito
      }
    }
    final rawBass = _prefs?.getString('bassSequence');
    if (rawBass != null && rawBass.isNotEmpty) {
      try {
        final list = jsonDecode(rawBass) as List;
        bassSeq
          ..clear()
          ..addAll(
              list.map((e) => Entry.fromJson(e as Map<String, dynamic>)));
        bassSeq.sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
      } catch (_) {}
    }
    final rawSongs = _prefs?.getString('songs');
    if (rawSongs != null && rawSongs.isNotEmpty) {
      try {
        final list = jsonDecode(rawSongs) as List;
        songs
          ..clear()
          ..addAll(list
              .map((e) => SavedSong.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    notifyListeners();
  }

  void _persistSongs() {
    final raw = jsonEncode(songs.map((s) => s.toJson()).toList());
    _prefs?.setString('songs', raw);
  }

  void _persist() {
    final raw = jsonEncode(sequence.map((e) => e.toJson()).toList());
    _prefs?.setString('sequence', raw);
    _prefs?.setString(
        'bassSequence', jsonEncode(bassSeq.map((e) => e.toJson()).toList()));
    _prefs?.setBool('italian', italian);
    _prefs?.setBool('audioOn', audioOn);
    _prefs?.setInt('ornamentSpeed', ornamentSpeed);
    _prefs?.setString('uiLang', uiLang);
    _prefs?.setDouble('playbackSpeed', playbackSpeed);
  }

  void incOrnamentSpeed() {
    if (ornamentSpeed < 5) {
      ornamentSpeed++;
      _commit();
    }
  }

  void decOrnamentSpeed() {
    if (ornamentSpeed > 1) {
      ornamentSpeed--;
      _commit();
    }
  }

  /// Cicla la velocità 1 -> 2 -> ... -> 5 -> 1 (per il chip compatto).
  void cycleOrnamentSpeed() {
    ornamentSpeed = ornamentSpeed % 5 + 1;
    _commit();
  }

  /// Imposta la velocità direttamente (slider nelle Impostazioni).
  void setOrnamentSpeed(int v) {
    ornamentSpeed = v.clamp(1, 5);
    _commit();
  }

  /// Velocità globale di riproduzione (0.5x .. 2x): scala tutte le durate
  /// del Play (note, accordi, abbellimenti, pause).
  double playbackSpeed = 1.0;

  void setPlaybackSpeed(double v) {
    playbackSpeed = v.clamp(0.5, 2.0);
    _commit();
  }

  /// Durata scalata dalla velocità globale.
  int _scaledMs(num baseMs) => (baseMs / playbackSpeed).round();

  // --- Voce bersaglio ------------------------------------------------------

  /// Indice della voce su cui agiscono +, − e ⌫ (default = ultima).
  int? get targetIndex {
    if (sequence.isEmpty) return null;
    final s = selected;
    if (s != null && s >= 0 && s < sequence.length) return s;
    return sequence.length - 1;
  }

  Entry? get targetEntry {
    final i = targetIndex;
    return i == null ? null : sequence[i];
  }

  /// Bersaglio nella riga dei bassi (default = ultima voce).
  int? get bassTargetIndex {
    if (bassSeq.isEmpty) return null;
    final s = selectedBass;
    if (s != null && s >= 0 && s < bassSeq.length) return s;
    return bassSeq.length - 1;
  }

  Entry? get bassTargetEntry {
    final i = bassTargetIndex;
    return i == null ? null : bassSeq[i];
  }

  /// Bersaglio dei controlli (durata/cancella): riga bassi se la bottoniera
  /// è attiva, altrimenti la melodia.
  Entry? get controlTarget => bassMode ? bassTargetEntry : targetEntry;

  /// Voce "attiva" da rispecchiare sulla tastiera: quella in riproduzione se si
  /// sta ascoltando, altrimenti la voce bersaglio (selezionata o ultima).
  Entry? get _activeEntry {
    final p = playingIndex;
    if (isPlaying && p != null && p >= 0 && p < sequence.length) {
      return sequence[p];
    }
    return targetEntry;
  }

  /// Note da evidenziare sui tasti.
  Set<int> get highlightedMidis => _activeEntry?.midis.toSet() ?? const {};

  /// Diteggiatura da riportare sui tasti evidenziati.
  Map<int, int> get highlightedFingers => _activeEntry?.fingers ?? const {};

  /// Sostituzioni di dito da riportare sui tasti evidenziati.
  Map<int, int> get highlightedFingers2 => _activeEntry?.fingers2 ?? const {};

  /// Nota a fuoco da marcare più forte sulla tastiera (solo per voci con
  /// più note e fuori dalla riproduzione: per la nota singola basta
  /// l'evidenziazione normale).
  int? get keyboardFocusMidi {
    if (isPlaying) return null;
    final e = targetEntry;
    if (e == null || e.midis.length <= 1) return null;
    return effectiveFocusMidi;
  }

  /// Nota effettivamente a fuoco (per la diteggiatura) nella voce bersaglio.
  int? get effectiveFocusMidi {
    final e = targetEntry;
    if (e == null) return null;
    if (focusMidi != null && e.midis.contains(focusMidi)) return focusMidi;
    return e.midis.isNotEmpty ? e.midis.last : null;
  }

  // --- Interazioni tastiera ------------------------------------------------

  void onKeyTap(int midi) {
    _playIfOn(midi);
    if (practiceMode) return; // prova: suona soltanto, non scrive
    if (runMode) {
      _runNote(midi);
    } else if (chordMode) {
      _stackNote(midi);
    } else {
      _appendNote(midi);
    }
  }

  /// Abbellimento: come l'accordo, impila sulla voce bersaglio — convertendola
  /// in abbellimento se non lo è già. Con sequenza vuota crea la prima voce.
  void _runNote(int midi) {
    final i = targetIndex;
    if (i == null) {
      sequence.add(Entry.run([midi]));
      _bassAnchorsOnInsert(sequence.length - 1);
      selected = 0;
      focusMidi = midi;
      _commit();
      return;
    }
    final t = sequence[i];
    // Etichette di testo e giri di bassi: crea un abbellimento dopo.
    if (t.isText || t.isBass) {
      sequence.insert(i + 1, Entry.run([midi]));
      _bassAnchorsOnInsert(i + 1);
      selected = i + 1;
      focusMidi = midi;
      _commit();
      return;
    }
    if (!t.run) t.toRun();
    t.addNote(midi);
    focusMidi = midi;
    _commit();
  }

  void _appendNote(int midi) {
    // Inserisce SUBITO DOPO la voce bersaglio (default = ultima), così si
    // possono inserire note anche in mezzo. La nuova voce diventa selezionata.
    final i = targetIndex;
    final insertAt = i == null ? 0 : i + 1;
    sequence.insert(insertAt, Entry.single(midi));
    _bassAnchorsOnInsert(insertAt);
    selected = insertAt;
    focusMidi = midi;
    _commit();
  }

  void _stackNote(int midi) {
    final i = targetIndex;
    if (i == null) {
      sequence.add(Entry.single(midi));
      _bassAnchorsOnInsert(sequence.length - 1);
      selected = null;
      focusMidi = midi;
      _commit();
      return;
    }
    final entry = sequence[i];
    // Etichette di testo e giri di bassi non ospitano note: voce nuova dopo.
    if (entry.isText || entry.isBass) {
      sequence.insert(i + 1, Entry.single(midi));
      _bassAnchorsOnInsert(i + 1);
      selected = i + 1;
      focusMidi = midi;
      _commit();
      return;
    }
    // In modalità accordo un abbellimento bersaglio viene convertito in accordo.
    if (entry.run) entry.toChord();
    if (entry.midis.contains(midi)) {
      final emptied = entry.removeNote(midi);
      if (emptied) {
        sequence.removeAt(i);
        _bassAnchorsOnRemove(i);
        selected = null;
        focusMidi = null;
      }
    } else {
      entry.addNote(midi);
      focusMidi = midi;
    }
    _commit();
  }

  /// Limiti (indici inclusivi) entro cui può stare un intervallo che
  /// contiene [s..e] senza sovrapporsi agli altri appunti; `exclude` è
  /// l'appunto che si sta ridimensionando.
  (int, int) _bassRangeBounds(int s, int e, Entry? exclude) {
    var lo = 0, hi = sequence.length - 1;
    for (final b in bassSeq) {
      if (identical(b, exclude)) continue;
      if (b.anchorEnd <= s && b.anchorEnd > lo) lo = b.anchorEnd;
      if (b.anchorStart > e && b.anchorStart - 1 < hi) hi = b.anchorStart - 1;
    }
    return (lo, hi);
  }

  /// Tocco su una voce della melodia in modalità bassi: sceglie l'intervallo
  /// a cui ancorare l'appunto. Primo tocco = inizio; secondo tocco su
  /// un'altra voce = estende l'intervallo (senza invadere gli altri appunti);
  /// un tocco successivo riparte. Un tocco su una voce già coperta
  /// seleziona quell'appunto.
  void tapMelodyForBassRange(int i) {
    if (i < 0 || i >= sequence.length) return;
    final covered = bassSeq
        .indexWhere((b) => i >= b.anchorStart && i < b.anchorEnd);
    if (covered >= 0) {
      // Seleziona l'appunto ma suona la sequenza coperta (il giro si
      // ascolta toccando il chip rosso nella riga sotto).
      selectBassEntry(covered, playSound: false);
      _playRangePreview();
      return;
    }
    selectedBass = null; // nuova selezione = nuovo appunto
    bassFocusIdx = null;
    final s = bassSelStart, e = bassSelEnd;
    if (s != null && s == e && s != i && s < sequence.length) {
      final (lo, hi) = _bassRangeBounds(s, s, null);
      final j = i.clamp(lo, hi);
      bassSelStart = j < s ? j : s;
      bassSelEnd = j < s ? s : j;
    } else {
      bassSelStart = i;
      bassSelEnd = i;
    }
    _playRangePreview();
    notifyListeners();
  }

  /// Suona in sequenza le voci della melodia selezionate (anteprima
  /// dell'intervallo in modalità bassi), evidenziando man mano il chip
  /// che sta suonando.
  Future<void> _playRangePreview() async {
    if (!audioOn || !hasBassRange || sequence.isEmpty) return;
    if (isPlaying) stopPlayback();
    _playToken++; // interrompe un'eventuale anteprima precedente
    final token = _playToken;
    final s = bassSelStart!.clamp(0, sequence.length - 1);
    final e = bassSelEnd!.clamp(s, sequence.length - 1);
    for (var k = s; k <= e; k++) {
      if (token != _playToken) return;
      final entry = sequence[k];
      if (entry.isText || entry.isBass) continue;
      playingIndex = k;
      notifyListeners();
      await _playEntrySound(entry);
      await Future.delayed(Duration(milliseconds: _scaledMs(240)));
    }
    if (token == _playToken) {
      playingIndex = null;
      notifyListeners();
    }
  }

  /// Ridimensiona l'intervallo trascinando un bordo fino all'indice dato.
  /// Se c'è un appunto selezionato, ridimensiona la sua ancora; altrimenti la
  /// selezione in corso. Mai oltre gli appunti vicini.
  void setBassRangeEdge({required bool leftEdge, required int index}) {
    if (sequence.isEmpty || !hasBassRange) return;
    var s = bassSelStart!.clamp(0, sequence.length - 1);
    var e = bassSelEnd!.clamp(s, sequence.length - 1);
    final sel = selectedBass;
    final selEntry = (sel != null && sel >= 0 && sel < bassSeq.length)
        ? bassSeq[sel]
        : null;
    final (lo, hi) = _bassRangeBounds(s, e, selEntry);
    final i = index.clamp(0, sequence.length - 1);
    if (leftEdge) {
      s = i.clamp(lo, e);
    } else {
      e = i.clamp(s, hi);
    }
    if (s == bassSelStart && e == bassSelEnd) return;
    bassSelStart = s;
    bassSelEnd = e;
    if (selEntry != null) {
      selEntry.anchorStart = s;
      selEntry.anchorSpan = e - s + 1;
      bassSeq.sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
      selectedBass = bassSeq.indexOf(selEntry);
      _commit();
    } else {
      notifyListeners();
    }
  }

  /// Tocco su un bottone della bottoniera: suona e — se c'è un appunto
  /// selezionato o un intervallo scelto — aggiunge il bottone al giro.
  void onBassTap(int code) {
    _playBassCode(code);
    if (practiceMode) return;
    final sel = selectedBass;
    if (sel != null && sel >= 0 && sel < bassSeq.length) {
      // Appunto selezionato: il bottone si accoda al giro.
      bassSeq[sel].addBass(code);
      bassFocusIdx = null;
      _commit();
      return;
    }
    if (!hasBassRange || sequence.isEmpty) {
      // Nessun bersaglio: suona soltanto.
      notifyListeners();
      return;
    }
    final start = bassSelStart!.clamp(0, sequence.length - 1);
    final span = (bassSelEnd!.clamp(0, sequence.length - 1)) - start + 1;
    // Se esiste già un appunto con questa ancora, accoda lì.
    final existing = bassSeq
        .indexWhere((e) => e.anchorStart == start && e.anchorSpan == span);
    if (existing >= 0) {
      bassSeq[existing].addBass(code);
      selectedBass = existing;
    } else {
      // Mai sovrapposto a un altro appunto (la selezione è già vincolata;
      // questa è una rete di sicurezza).
      final overlaps = bassSeq
          .any((b) => start < b.anchorEnd && b.anchorStart < start + span);
      if (overlaps) {
        notifyListeners();
        return;
      }
      final e = Entry.bass([code], anchorStart: start, anchorSpan: span);
      var at = bassSeq.indexWhere((b) => b.anchorStart > start);
      if (at < 0) at = bassSeq.length;
      bassSeq.insert(at, e);
      selectedBass = at;
    }
    bassFocusIdx = null;
    _commit();
  }

  void selectBassEntry(int index, {bool playSound = true}) {
    if (index < 0 || index >= bassSeq.length) return;
    selectedBass = index;
    bassFocusIdx = null;
    // Mostra sull'annotazione l'intervallo coperto dall'appunto.
    final e = bassSeq[index];
    if (sequence.isNotEmpty) {
      bassSelStart = e.anchorStart.clamp(0, sequence.length - 1);
      bassSelEnd = (e.anchorEnd - 1).clamp(0, sequence.length - 1);
    }
    if (playSound) _playEntrySound(e);
    notifyListeners();
  }

  /// Mette a fuoco un singolo bottone dentro un giro (per cancellare solo
  /// quello) e lo suona.
  void focusBassInEntry(int index, int k) {
    if (index < 0 || index >= bassSeq.length) return;
    final e = bassSeq[index];
    if (k < 0 || k >= e.basses.length) return;
    selectedBass = index;
    bassFocusIdx = k;
    if (sequence.isNotEmpty) {
      bassSelStart = e.anchorStart.clamp(0, sequence.length - 1);
      bassSelEnd = (e.anchorEnd - 1).clamp(0, sequence.length - 1);
    }
    _playBassCode(e.basses[k]);
    notifyListeners();
  }

  // --- Ancoraggio degli appunti di bassi alla melodia -----------------------

  /// Da chiamare dopo `sequence.insert(i, ...)`: fa scorrere le ancore.
  void _bassAnchorsOnInsert(int i) => _bassAnchorsOnInsertKeeping(i, const []);

  void _bassAnchorsOnInsertKeeping(int i, List<Entry> skip) {
    for (final e in bassSeq) {
      if (skip.contains(e)) continue;
      if (i <= e.anchorStart) {
        e.anchorStart++;
      } else if (i < e.anchorEnd) {
        e.anchorSpan++; // inserimento dentro l'intervallo: si allarga
      }
    }
    bassSelStart = bassSelEnd = null;
  }

  /// Da chiamare dopo `sequence.removeAt(i)`: restringe o elimina gli appunti.
  void _bassAnchorsOnRemove(int i) => _bassAnchorsOnRemoveKeeping(i, const []);

  void _bassAnchorsOnRemoveKeeping(int i, List<Entry> skip) {
    final dead = <Entry>[];
    for (final e in bassSeq) {
      if (skip.contains(e)) continue;
      if (i < e.anchorStart) {
        e.anchorStart--;
      } else if (i < e.anchorEnd) {
        e.anchorSpan--;
        if (e.anchorSpan <= 0) dead.add(e);
      }
    }
    if (dead.isNotEmpty) {
      bassSeq.removeWhere(dead.contains);
      selectedBass = null;
    }
    bassSelStart = bassSelEnd = null;
  }

  /// Suona un bottone Stradella: bassi = nota grave singola,
  /// accordi = triadi/settima nell'ottava medio-bassa.
  void _playBassCode(int code) {
    if (!audioOn || code < 0) return; // pausa: nessun suono
    final pc = code % 12;
    final type = code ~/ 12;
    switch (type) {
      case 0: // contrabbasso: terza reale, registro grave
        _synth.play(36 + (pc + 4) % 12);
      case 1: // basso
        _synth.play(36 + pc);
      case 2: // Maggiore
        for (final iv in const [0, 4, 7]) {
          _synth.play(48 + pc + iv);
        }
      case 3: // minore
        for (final iv in const [0, 3, 7]) {
          _synth.play(48 + pc + iv);
        }
      case 4: // settima (senza quinta, come sulla Stradella)
        for (final iv in const [0, 4, 10]) {
          _synth.play(48 + pc + iv);
        }
      default: // diminuita
        for (final iv in const [0, 3, 9]) {
          _synth.play(48 + pc + iv);
        }
    }
  }

  // --- Durata / cancellazione / selezione ----------------------------------

  void incLen() {
    final e = controlTarget;
    if (e != null && !e.isText && !e.isBass && e.len < kMaxLen) {
      e.len++;
      _commit();
    }
  }

  void decLen() {
    final e = controlTarget;
    if (e != null && !e.isText && !e.isBass && e.len > 0) {
      e.len--;
      _commit();
    }
  }

  // --- Voci di testo (sottotitoli di sezione) ------------------------------

  /// Inserisce un'etichetta di testo dopo la voce selezionata.
  void addTextEntry(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final i = targetIndex;
    final insertAt = i == null ? sequence.length : i + 1;
    sequence.insert(insertAt, Entry.text(t));
    _bassAnchorsOnInsert(insertAt);
    selected = insertAt;
    focusMidi = null;
    _commit();
  }

  /// Modifica un'etichetta; testo vuoto = eliminala.
  void editTextEntry(int index, String text) {
    if (index < 0 || index >= sequence.length) return;
    final e = sequence[index];
    if (!e.isText) return;
    final t = text.trim();
    if (t.isEmpty) {
      sequence.removeAt(index);
      _bassAnchorsOnRemove(index);
      selected = null;
    } else {
      e.label = t;
    }
    _commit();
  }

  void deleteTarget() {
    if (bassMode) {
      _deleteBassTarget();
      return;
    }
    final i = targetIndex;
    if (i == null) return;
    final e = sequence[i];
    final m = effectiveFocusMidi;
    if (e.isBass && e.basses.length > 1) {
      // Giro di bassi: toglie l'ultimo bottone.
      e.removeLastBass();
      _commit();
      return;
    }
    if (e.run && e.midis.length > 1) {
      // Abbellimento: toglie la nota a fuoco (un'occorrenza, per i trilli);
      // senza fuoco valido, l'ultima.
      if (m != null && e.midis.contains(m)) {
        e.removeNote(m);
      } else {
        e.removeLast();
      }
      focusMidi = e.midis.isNotEmpty ? e.midis.last : null;
    } else if (e.isChord && m != null) {
      // Accordo: cancella solo la nota a fuoco.
      e.removeNote(m);
      if (e.midis.isEmpty) {
        sequence.removeAt(i);
        _bassAnchorsOnRemove(i);
        selected = null;
        focusMidi = null;
      } else {
        focusMidi = e.midis.last;
      }
    } else {
      // Nota singola / abbellimento a una nota: cancella l'intera voce.
      sequence.removeAt(i);
      _bassAnchorsOnRemove(i);
      selected = null;
      focusMidi = null;
    }
    _commit();
  }

  /// Cancella l'appunto di bassi: giro -> toglie il bottone a fuoco
  /// (o l'ultimo); singolo -> rimuove l'appunto.
  void _deleteBassTarget() {
    final i = bassTargetIndex;
    if (i == null) return;
    final e = bassSeq[i];
    if (e.basses.length > 1) {
      final k = (selectedBass == i &&
              bassFocusIdx != null &&
              bassFocusIdx! < e.basses.length)
          ? bassFocusIdx!
          : e.basses.length - 1;
      e.basses.removeAt(k);
      bassFocusIdx = null;
      selectedBass = i;
    } else {
      bassSeq.removeAt(i);
      selectedBass = null;
      bassFocusIdx = null;
    }
    _commit();
  }

  /// Sposta una voce (drag & drop nell'annotazione).
  void moveEntry(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= sequence.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, sequence.length - 1);
    // Gli appunti ancorati SOLO alla voce spostata la seguono; gli altri
    // si adattano come per una rimozione + inserimento.
    final follow = bassSeq
        .where((b) => b.anchorSpan == 1 && b.anchorStart == oldIndex)
        .toList();
    final e = sequence.removeAt(oldIndex);
    _bassAnchorsOnRemoveKeeping(oldIndex, follow);
    sequence.insert(newIndex, e);
    _bassAnchorsOnInsertKeeping(newIndex, follow);
    for (final b in follow) {
      b.anchorStart = newIndex;
    }
    bassSeq.sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
    selectedBass = null;
    selected = newIndex;
    focusMidi = e.midis.isNotEmpty ? e.midis.last : null;
    _commit();
  }

  void selectEntry(int index) {
    selected = index;
    final e = sequence[index];
    // Per una nota singola il fuoco è automatico; per un accordo prendi l'acuta.
    focusMidi = e.midis.isNotEmpty ? e.midis.last : null;
    _playEntrySound(e); // feedback: il chip toccato suona
    notifyListeners();
  }

  /// Seleziona una nota specifica dentro un accordo (per la diteggiatura).
  void focusNoteInEntry(int index, int midi) {
    selected = index;
    focusMidi = midi;
    _playIfOn(midi); // suona la singola nota toccata
    notifyListeners();
  }

  /// Suona una voce: accordo insieme, abbellimento in rapida successione,
  /// appunto di bassi = giro in sequenza.
  Future<void> _playEntrySound(Entry e) async {
    if (!audioOn) return;
    if (e.isBass) {
      for (final c in e.basses) {
        _playBassCode(c);
        if (e.basses.length > 1) {
          await Future.delayed(Duration(milliseconds: _scaledMs(240)));
        }
      }
      return;
    }
    if (e.run) {
      for (final m in e.midis) {
        _synth.play(m);
        await Future.delayed(Duration(milliseconds: ornamentGapMs));
      }
    } else {
      for (final m in e.midis) {
        _synth.play(m);
      }
    }
  }

  void clearAll() {
    stopPlayback();
    sequence.clear();
    bassSeq.clear();
    selected = null;
    selectedBass = null;
    bassSelStart = bassSelEnd = null;
    bassFocusIdx = null;
    focusMidi = null;
    loadedName = null;
    _commit();
  }

  // --- Salva / Carica ------------------------------------------------------

  /// Salva la sequenza corrente con un nome (sovrascrive se il nome esiste).
  void saveCurrentAs(String name, {String? isoNow}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || (sequence.isEmpty && bassSeq.isEmpty)) return;
    final copy = sequence.map((e) => Entry.fromJson(e.toJson())).toList();
    final bassCopy = bassSeq.map((e) => Entry.fromJson(e.toJson())).toList();
    final song = SavedSong(
      name: trimmed,
      entries: copy,
      bassEntries: bassCopy,
      savedAt: isoNow ?? DateTime.now().toIso8601String(),
    );
    final idx =
        songs.indexWhere((s) => s.name.toLowerCase() == trimmed.toLowerCase());
    if (idx >= 0) {
      songs[idx] = song;
    } else {
      songs.add(song);
    }
    loadedName = trimmed;
    _persistSongs();
    notifyListeners();
  }

  /// Carica una musica salvata nella sequenza di lavoro (copia profonda).
  void loadSong(SavedSong song) {
    stopPlayback();
    sequence
      ..clear()
      ..addAll(song.cloneEntries());
    bassSeq
      ..clear()
      ..addAll(song.cloneBassEntries());
    bassSeq.sort((a, b) => a.anchorStart.compareTo(b.anchorStart));
    selected = null;
    selectedBass = null;
    bassSelStart = bassSelEnd = null;
    bassFocusIdx = null;
    focusMidi = null;
    loadedName = song.name;
    _commit();
  }

  void deleteSong(String name) {
    songs.removeWhere((s) => s.name == name);
    if (loadedName == name) loadedName = null;
    _persistSongs();
    notifyListeners();
  }

  /// Aggiunge una musica importata (evita di sovrascrivere un nome esistente).
  /// Ritorna il nome effettivo con cui è stata salvata.
  String addImportedSong(SavedSong song) {
    var name = song.name.trim().isEmpty ? 'Importato' : song.name.trim();
    while (songs.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      name = '$name (importato)';
    }
    songs.add(SavedSong(
      name: name,
      entries: song.entries,
      bassEntries: song.bassEntries,
      savedAt: song.savedAt.isEmpty ? '' : song.savedAt,
    ));
    _persistSongs();
    notifyListeners();
    return name;
  }

  /// Rinomina una musica salvata.
  void renameSong(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final idx = songs.indexWhere((s) => s.name == oldName);
    if (idx < 0) return;
    final old = songs[idx];
    songs[idx] = SavedSong(
        name: trimmed,
        entries: old.entries,
        bassEntries: old.bassEntries,
        savedAt: old.savedAt);
    if (loadedName == oldName) loadedName = trimmed;
    _persistSongs();
    notifyListeners();
  }

  bool hasSongNamed(String name) =>
      songs.any((s) => s.name.toLowerCase() == name.trim().toLowerCase());

  // --- Diteggiatura --------------------------------------------------------

  void setFinger(int finger) {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e != null && m != null) {
      e.setFinger(m, finger);
      e.clearFinger2(m); // nuovo principale: riparte senza sostituzione
      _commit();
    }
  }

  void clearFinger() {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e != null && m != null) {
      e.clearFinger(m);
      _commit();
    }
  }

  /// Sostituzione del dito (long-press): imposta/toglie il secondo dito.
  /// Richiede un dito principale già impostato e diverso dal secondo.
  void toggleFinger2(int finger) {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e == null || m == null) return;
    final primary = e.fingerOf(m);
    if (primary == null || primary == finger) return;
    if (e.finger2Of(m) == finger) {
      e.clearFinger2(m);
    } else {
      e.setFinger2(m, finger);
    }
    _commit();
  }

  int? get currentFinger {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e == null || m == null) return null;
    return e.fingerOf(m);
  }

  int? get currentFinger2 {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e == null || m == null) return null;
    return e.finger2Of(m);
  }

  // --- Riproduzione --------------------------------------------------------

  /// Riproduce SOLO la melodia: gli appunti di bassi sono promemoria visivi.
  Future<void> playSequence() async {
    if (isPlaying || sequence.isEmpty) return;
    isPlaying = true;
    _playToken++;
    final token = _playToken;
    notifyListeners();
    await _playMelodyTrack(token);
    if (token == _playToken) {
      isPlaying = false;
      playingIndex = null;
      notifyListeners();
    }
  }

  Future<void> _playMelodyTrack(int token) async {
    for (var i = 0; i < sequence.length; i++) {
      if (token != _playToken) break;
      playingIndex = i;
      notifyListeners();
      final e = sequence[i];
      if (e.isText) {
        // Etichetta di sezione: breve pausa, nessun suono.
        await Future.delayed(Duration(milliseconds: _scaledMs(200)));
        continue;
      }
      if (e.isBass) {
        // Voce bassi rimasta inline (retrocompatibilità).
        for (final c in e.basses) {
          if (token != _playToken) break;
          _playBassCode(c);
          await Future.delayed(Duration(milliseconds: _scaledMs(320)));
        }
        await Future.delayed(Duration(milliseconds: _scaledMs(e.len * 170)));
        continue;
      }
      if (e.run) {
        // Abbellimento: note in rapida successione.
        for (final m in e.midis) {
          if (token != _playToken) break;
          _synth.play(m);
          await Future.delayed(Duration(milliseconds: _scaledMs(ornamentGapMs)));
        }
        await Future.delayed(
            Duration(milliseconds: _scaledMs(120 + e.len * 170)));
      } else {
        for (final m in e.midis) {
          _synth.play(m);
        }
        await Future.delayed(
            Duration(milliseconds: _scaledMs(280 + e.len * 170)));
      }
    }
  }

  void stopPlayback() {
    _playToken++;
    isPlaying = false;
    playingIndex = null;
    notifyListeners();
  }

  void togglePlay() {
    if (isPlaying) {
      stopPlayback();
    } else {
      playSequence();
    }
  }

  // --- Toggle --------------------------------------------------------------

  void toggleChordMode() {
    chordMode = !chordMode;
    if (chordMode) {
      runMode = false; // esclusivi
      // Se la voce selezionata è un abbellimento, convertila in accordo.
      final e = targetEntry;
      if (e != null && e.run) {
        e.toChord();
        focusMidi = e.midis.isNotEmpty ? e.midis.last : null;
        _commit();
        return;
      }
    }
    notifyListeners();
  }

  void toggleRunMode() {
    runMode = !runMode;
    if (runMode) {
      chordMode = false; // esclusivi
      // Se la voce selezionata è un accordo (o nota), convertila in
      // abbellimento: le note successive si accoderanno lì.
      final e = targetEntry;
      if (e != null && !e.run && e.midis.length > 1) {
        e.toRun();
        _commit();
        return;
      }
    }
    notifyListeners();
  }

  void togglePracticeMode() {
    practiceMode = !practiceMode;
    notifyListeners();
  }

  void toggleNames() {
    italian = !italian;
    _commit();
  }

  void toggleAudio() {
    audioOn = !audioOn;
    _commit();
  }

  // --- Esportazione --------------------------------------------------------

  String get exportText {
    final mel = formatSequence(sequence, italian: italian);
    if (bassSeq.isEmpty) return mel;
    // Appunti di bassi con la posizione (1-based) delle voci coperte:
    // B: [3-5] Do DoM | [8] Sol7
    final bass = bassSeq.map((e) {
      final labels =
          e.basses.map((c) => bassLabel(c, italian: italian)).join(' ');
      final a = e.anchorStart + 1;
      final b = e.anchorEnd;
      final pos = a == b ? '[$a]' : '[$a-$b]';
      return '$pos $labels';
    }).join(' | ');
    return mel.isEmpty ? 'B: $bass' : '$mel\nB: $bass';
  }

  bool get isEmpty => sequence.isEmpty && bassSeq.isEmpty;

  // --- Helpers -------------------------------------------------------------

  void _playIfOn(int midi) {
    if (audioOn) _synth.play(midi);
  }

  void _commit() {
    _persist();
    notifyListeners();
  }
}
