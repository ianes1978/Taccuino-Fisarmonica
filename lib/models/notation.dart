import 'entry.dart';

/// Range della tastiera: Si3 (B3, MIDI 59) .. Do6 (C6, MIDI 84).
/// Vista fisarmonica: la più grave (B3) è in cima, la più acuta (C6) in fondo.
const int kLowMidi = 59;
const int kHighMidi = 84;

/// Massimo numero di trattini di durata.
const int kMaxLen = 8;

const List<String> _italian = [
  'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'
];
const List<String> _english = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

/// Ottava scientific pitch: Do4 = Do centrale (MIDI 60).
int octaveOf(int midi) => (midi ~/ 12) - 1;

int pitchClass(int midi) => midi % 12;

bool isBlackKey(int midi) {
  const black = {1, 3, 6, 8, 10};
  return black.contains(pitchClass(midi));
}

/// Solo il nome della nota (senza ottava).
String noteName(int midi, {required bool italian}) =>
    (italian ? _italian : _english)[pitchClass(midi)];

/// Nome + ottava, es. "La4", "Sol#5".
String noteLabel(int midi, {required bool italian}) =>
    '${noteName(midi, italian: italian)}${octaveOf(midi)}';

String _dashes(int len) => '-' * len;

/// Nota con eventuale diteggiatura, es. `La4` oppure `La4(3)`.
String _noteWithFinger(Entry e, int midi, {required bool italian}) {
  final base = noteLabel(midi, italian: italian);
  final f = e.fingerOf(midi);
  return f == null ? base : '$base($f)';
}

/// Formatta una voce nel formato di notazione.
///  - singola: `La4(3)--`
///  - accordo: `[Do4(1) Mi4(3) Sol4(5)]--`
String formatEntry(Entry e, {required bool italian}) {
  final tail = _dashes(e.len);
  if (e.midis.length == 1) {
    return '${_noteWithFinger(e, e.midis.first, italian: italian)}$tail';
  }
  final inside = e.midis
      .map((m) => _noteWithFinger(e, m, italian: italian))
      .join(' ');
  return '[$inside]$tail';
}

/// Riga completa: voci separate da spazio.
String formatSequence(List<Entry> seq, {required bool italian}) =>
    seq.map((e) => formatEntry(e, italian: italian)).join(' ');
