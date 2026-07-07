import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/synth.dart';
import '../models/entry.dart';
import '../models/notation.dart';
import '../models/saved_song.dart';

class AppState extends ChangeNotifier {
  final Synth _synth = Synth();

  final List<Entry> sequence = [];

  /// Musiche salvate con nome.
  final List<SavedSong> songs = [];

  /// Indice della voce selezionata; null = "l'ultima".
  int? selected;

  /// Nota (midi) messa a fuoco dentro la voce bersaglio, per la diteggiatura.
  int? focusMidi;

  bool chordMode = false;
  bool italian = true;
  bool audioOn = true;

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
  }

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
    if (chordMode) {
      _stackNote(midi);
    } else {
      _appendNote(midi);
    }
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
    if (e != null && e.len < kMaxLen) {
      e.len++;
      _commit();
    }
  }

  void decLen() {
    final e = targetEntry;
    if (e != null && e.len > 0) {
      e.len--;
      _commit();
    }
  }

  void deleteTarget() {
    final i = targetIndex;
    if (i == null) return;
    final e = sequence[i];
    final m = effectiveFocusMidi;
    if (e.midis.length > 1 && m != null) {
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
      // Nota singola (o nessun fuoco): cancella l'intera voce.
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
    notifyListeners();
  }

  /// Seleziona una nota specifica dentro un accordo (per la diteggiatura).
  void focusNoteInEntry(int index, int midi) {
    selected = index;
    focusMidi = midi;
    notifyListeners();
  }

  void clearAll() {
    stopPlayback();
    sequence.clear();
    selected = null;
    focusMidi = null;
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
    _commit();
  }

  void deleteSong(String name) {
    songs.removeWhere((s) => s.name == name);
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

  int? get currentFinger {
    final e = targetEntry;
    final m = effectiveFocusMidi;
    if (e == null || m == null) return null;
    return e.fingerOf(m);
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
      for (final m in e.midis) {
        _synth.play(m);
      }
      final ms = 280 + e.len * 170; // durata in base ai trattini
      await Future.delayed(Duration(milliseconds: ms));
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
