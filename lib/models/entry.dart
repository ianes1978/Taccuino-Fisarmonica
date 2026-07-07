/// Una voce della sequenza: un accordo di 1+ note con una durata condivisa.
class Entry {
  /// MIDI notes, ordinati crescente (dal grave all'acuto).
  List<int> midis;

  /// Numero di trattini di durata (0..8).
  int len;

  Entry({required this.midis, this.len = 0}) {
    midis.sort();
  }

  Entry.single(int midi, {int len = 0})
      : midis = [midi],
        len = len;

  void addNote(int midi) {
    if (!midis.contains(midi)) {
      midis.add(midi);
      midis.sort();
    }
  }

  /// Rimuove una nota; ritorna true se la voce è rimasta senza note.
  bool removeNote(int midi) {
    midis.remove(midi);
    return midis.isEmpty;
  }

  bool get isChord => midis.length > 1;

  Map<String, dynamic> toJson() => {'m': midis, 'l': len};

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        midis: (j['m'] as List).map((e) => e as int).toList(),
        len: j['l'] as int,
      );
}
