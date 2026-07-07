/// Una voce della sequenza. Tre tipi:
///  - nota singola / accordo: note simultanee, ordinate dal grave all'acuto,
///    senza duplicati (`run` = false);
///  - abbellimento: note in sequenza rapida, NELL'ORDINE suonato, duplicati
///    ammessi (per i trilli) (`run` = true).
class Entry {
  /// MIDI notes. Accordo: ordinati crescente. Abbellimento: ordine di
  /// esecuzione (non ordinati, duplicati ammessi).
  List<int> midis;

  /// Numero di trattini di durata (0..8).
  int len;

  /// Diteggiatura per nota: midi -> dito (1..5).
  Map<int, int> fingers;

  /// true = abbellimento (passaggio veloce orizzontale).
  bool run;

  Entry({
    required this.midis,
    this.len = 0,
    Map<int, int>? fingers,
    this.run = false,
  }) : fingers = fingers ?? {} {
    if (!run) midis.sort();
  }

  Entry.single(int midi, {int len = 0})
      : midis = [midi],
        len = len,
        fingers = {},
        run = false;

  Entry.run(List<int> midis, {int len = 0})
      : midis = List.of(midis),
        len = len,
        fingers = {},
        run = true;

  void addNote(int midi) {
    if (run) {
      // Abbellimento: accoda in ordine, duplicati ammessi.
      midis.add(midi);
    } else if (!midis.contains(midi)) {
      midis.add(midi);
      midis.sort();
    }
  }

  /// Rimuove una nota (prima occorrenza); ritorna true se la voce è vuota.
  bool removeNote(int midi) {
    midis.remove(midi);
    if (!midis.contains(midi)) fingers.remove(midi);
    return midis.isEmpty;
  }

  /// Rimuove l'ultima nota (utile per gli abbellimenti); true se vuota.
  bool removeLast() {
    if (midis.isNotEmpty) {
      final m = midis.removeLast();
      if (!midis.contains(m)) fingers.remove(m);
    }
    return midis.isEmpty;
  }

  void setFinger(int midi, int finger) {
    if (midis.contains(midi)) fingers[midi] = finger;
  }

  void clearFinger(int midi) => fingers.remove(midi);

  int? fingerOf(int midi) => fingers[midi];

  bool get isChord => midis.length > 1 && !run;

  Map<String, dynamic> toJson() => {
        'm': midis,
        'l': len,
        'f': fingers.map((k, v) => MapEntry(k.toString(), v)),
        if (run) 'r': true,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        midis: (j['m'] as List).map((e) => e as int).toList(),
        len: j['l'] as int,
        run: j['r'] == true,
        fingers: (j['f'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), v as int),
            ) ??
            {},
      );
}
