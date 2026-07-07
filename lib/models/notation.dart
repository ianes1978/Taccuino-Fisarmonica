import 'entry.dart';

/// Range della tastiera: Do4 (C4, MIDI 60) .. Mi6 (E6, MIDI 88).
const int kLowMidi = 60;
const int kHighMidi = 88;

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

/// Formatta una voce nel formato di notazione.
///  - singola: `La4--`
///  - accordo: `[Do4 Mi4 Sol4]--`
String formatEntry(Entry e, {required bool italian}) {
  final tail = _dashes(e.len);
  if (e.midis.length == 1) {
    return '${noteLabel(e.midis.first, italian: italian)}$tail';
  }
  final inside =
      e.midis.map((m) => noteLabel(m, italian: italian)).join(' ');
  return '[$inside]$tail';
}

/// Riga completa: voci separate da spazio.
String formatSequence(List<Entry> seq, {required bool italian}) =>
    seq.map((e) => formatEntry(e, italian: italian)).join(' ');
