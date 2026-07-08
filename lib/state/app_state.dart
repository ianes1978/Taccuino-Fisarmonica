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
      selected = 0;
      focusMidi = midi;
      _commit();
      return;
    }
    final t = sequence[i];
    // Un'etichetta di testo non può ospitare note: crea un abbellimento dopo.
    if (t.isText) {
      sequence.insert(i + 1, Entry.run([midi]));
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
    selected = insertAt;
    focusMidi = midi;
    _commit();
  }

  void _stackNote(int midi) {
    final i = targetIndex;
    if (i == null) {
      sequence.add(Entry.single(midi));
      selected = null;
      focusMidi = midi;
      _commit();
      return;
    }
    final entry = sequence[i];
    // Un'etichetta di testo non può ospitare note: crea una voce nuova dopo.
    if (entry.isText) {
      sequence.insert(i + 1, Entry.single(midi));
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
        selected = null;
        focusMidi = null;
      }
    } else {
      entry.addNote(midi);
      focusMidi = midi;
    }
    _commit();
  }

  // --- Durata / cancellazione / selezione ----------------------------------

  void incLen() {
    final e = targetEntry;
    if (e != null && !e.isText && e.len < kMaxLen) {
      e.len++;
      _commit();
    }
  }

  void decLen() {
    final e = targetEntry;
    if (e != null && !e.isText && e.len > 0) {
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
      selected = null;
    } else {
      e.label = t;
    }
    _commit();
  }

  void deleteTarget() {
    final i = targetIndex;
    if (i == null) return;
    final e = sequence[i];
    final m = effectiveFocusMidi;
    if (e.run && e.midis.length > 1) {
      // Abbellimento: toglie l'ultima nota (si costruisce in ordine).
      e.removeLast();
      focusMidi = e.midis.last;
    } else if (e.isChord && m != null) {
      // Accordo: cancella solo la nota a fuoco.
      e.removeNote(m);
      if (e.midis.isEmpty) {
        sequence.removeAt(i);
        selected = null;
        focusMidi = null;
      } else {
        focusMidi = e.midis.last;
      }
    } else {
      // Nota singola / abbellimento a una nota: cancella l'intera voce.
      sequence.removeAt(i);
      selected = null;
      focusMidi = null;
    }
    _commit();
  }

  /// Sposta una voce (drag & drop nell'annotazione).
  void moveEntry(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= sequence.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, sequence.length - 1);
    final e = sequence.removeAt(oldIndex);
    sequence.insert(newIndex, e);
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

  /// Suona una voce: accordo insieme, abbellimento in rapida successione.
  Future<void> _playEntrySound(Entry e) async {
    if (!audioOn) return;
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
    selected = null;
    focusMidi = null;
    loadedName = null;
    _commit();
  }

  // --- Salva / Carica ------------------------------------------------------

  /// Salva la sequenza corrente con un nome (sovrascrive se il nome esiste).
  void saveCurrentAs(String name, {String? isoNow}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || sequence.isEmpty) return;
    final copy = sequence.map((e) => Entry.fromJson(e.toJson())).toList();
    final song = SavedSong(
      name: trimmed,
      entries: copy,
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
    selected = null;
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
    songs[idx] =
        SavedSong(name: trimmed, entries: old.entries, savedAt: old.savedAt);
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

  Future<void> playSequence() async {
    if (isPlaying || sequence.isEmpty) return;
    isPlaying = true;
    _playToken++;
    final token = _playToken;
    notifyListeners();
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
    if (token == _playToken) {
      isPlaying = false;
      playingIndex = null;
      notifyListeners();
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

  String get exportText => formatSequence(sequence, italian: italian);

  bool get isEmpty => sequence.isEmpty;

  // --- Helpers -------------------------------------------------------------

  void _playIfOn(int midi) {
    if (audioOn) _synth.play(midi);
  }

  void _commit() {
    _persist();
    notifyListeners();
  }
}
