import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/synth.dart';
import '../models/entry.dart';
import '../models/notation.dart';

class AppState extends ChangeNotifier {
  final Synth _synth = Synth();

  final List<Entry> sequence = [];

  /// Indice della voce selezionata; null = "l'ultima".
  int? selected;

  bool chordMode = false;
  bool italian = true;
  bool audioOn = true;

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
    notifyListeners();
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

  // --- Interazioni tastiera ------------------------------------------------

  void onKeyTap(int midi) {
    _playIfOn(midi);
    if (chordMode) {
      _stackNote(midi);
    } else {
      _appendNote(midi);
    }
  }

  void _appendNote(int midi) {
    sequence.add(Entry.single(midi));
    selected = null; // la nuova voce (ultima) diventa corrente
    _commit();
  }

  void _stackNote(int midi) {
    final i = targetIndex;
    if (i == null) {
      // Sequenza vuota: crea comunque la prima voce.
      sequence.add(Entry.single(midi));
      selected = null;
      _commit();
      return;
    }
    final entry = sequence[i];
    if (entry.midis.contains(midi)) {
      final emptied = entry.removeNote(midi);
      if (emptied) {
        sequence.removeAt(i);
        selected = null;
      }
    } else {
      entry.addNote(midi);
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
    if (i != null) {
      sequence.removeAt(i);
      selected = null;
      _commit();
    }
  }

  void selectEntry(int index) {
    selected = index;
    notifyListeners();
  }

  void clearAll() {
    sequence.clear();
    selected = null;
    _commit();
  }

  // --- Toggle --------------------------------------------------------------

  void toggleChordMode() {
    chordMode = !chordMode;
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
