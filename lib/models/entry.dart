/// Una voce della sequenza: un accordo di 1+ note con una durata condivisa.
class Entry {
  /// MIDI notes, ordinati crescente (dal grave all'acuto).
  List<int> midis;

  /// Numero di trattini di durata (0..8).
  int len;

  /// Diteggiatura per nota: midi -> dito (1..5). Assente = nessun dito.
  Map<int, int> fingers;

  Entry({required this.midis, this.len = 0, Map<int, int>? fingers})
      : fingers = fingers ?? {} {
    midis.sort();
  }

  Entry.single(int midi, {int len = 0})
      : midis = [midi],
        len = len,
        fingers = {};

  void addNote(int midi) {
    if (!midis.contains(midi)) {
      midis.add(midi);
      midis.sort();
    }
  }

  /// Rimuove una nota (e il suo dito); ritorna true se la voce è rimasta vuota.
  bool removeNote(int midi) {
    midis.remove(midi);
    fingers.remove(midi);
    return midis.isEmpty;
  }

  void setFinger(int midi, int finger) {
    if (midis.contains(midi)) fingers[midi] = finger;
  }

  void clearFinger(int midi) => fingers.remove(midi);

  int? fingerOf(int midi) => fingers[midi];

  bool get isChord => midis.length > 1;

  Map<String, dynamic> toJson() => {
        'm': midis,
        'l': len,
        'f': fingers.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        midis: (j['m'] as List).map((e) => e as int).toList(),
        len: j['l'] as int,
        fingers: (j['f'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), v as int),
            ) ??
            {},
      );
}
