/// Una voce della sequenza. Tipi:
///  - nota singola / accordo: note simultanee, ordinate dal grave all'acuto,
///    senza duplicati (`run` = false);
///  - abbellimento: note in sequenza rapida, NELL'ORDINE suonato, duplicati
///    ammessi (per i trilli) (`run` = true);
///  - testo: sottotitolo di sezione (`label`);
///  - appunto di bassi: bottoni Stradella ancorati a un intervallo di voci
///    della melodia (`basses` + `anchorStart`/`anchorSpan`). È un promemoria:
///    non viene riprodotto dal Play.
class Entry {
  /// MIDI notes. Accordo: ordinati crescente. Abbellimento: ordine di
  /// esecuzione (non ordinati, duplicati ammessi).
  List<int> midis;

  /// Numero di trattini di durata (0..8).
  int len;

  /// Diteggiatura per nota: midi -> dito (1..5).
  Map<int, int> fingers;

  /// Dito di sostituzione per nota (es. 3-1): midi -> secondo dito (1..5).
  Map<int, int> fingers2;

  /// true = abbellimento (passaggio veloce orizzontale).
  bool run;

  /// Etichetta di testo (voce senza note): sottotitolo di sezione.
  String? label;

  /// Giro di bassi: bottoni Stradella in sequenza. Ogni codice è
  /// tipo*12 + nota (tipo: 0=contrabbasso, 1=basso, 2=Magg, 3=min, 4=7ª,
  /// 5=dim).
  List<int> basses;

  /// Ancora dell'appunto di bassi: indice della prima voce della melodia
  /// coperta e numero di voci coperte (>= 1).
  int anchorStart;
  int anchorSpan;

  Entry({
    required this.midis,
    this.len = 0,
    Map<int, int>? fingers,
    Map<int, int>? fingers2,
    this.run = false,
    this.label,
    List<int>? basses,
    this.anchorStart = 0,
    this.anchorSpan = 1,
  })  : fingers = fingers ?? {},
        fingers2 = fingers2 ?? {},
        basses = basses ?? [] {
    if (!run) midis.sort();
  }

  Entry.single(int midi, {int len = 0})
      : midis = [midi],
        len = len,
        fingers = {},
        fingers2 = {},
        run = false,
        label = null,
        basses = [],
        anchorStart = 0,
        anchorSpan = 1;

  Entry.run(List<int> midis, {int len = 0})
      : midis = List.of(midis),
        len = len,
        fingers = {},
        fingers2 = {},
        run = true,
        label = null,
        basses = [],
        anchorStart = 0,
        anchorSpan = 1;

  Entry.text(String text)
      : midis = [],
        len = 0,
        fingers = {},
        fingers2 = {},
        run = false,
        label = text,
        basses = [],
        anchorStart = 0,
        anchorSpan = 1;

  Entry.bass(List<int> codes, {this.anchorStart = 0, this.anchorSpan = 1})
      : midis = [],
        len = 0,
        fingers = {},
        fingers2 = {},
        run = false,
        label = null,
        basses = List.of(codes);

  bool get isText => label != null;

  bool get isBass => basses.isNotEmpty;

  /// Ultimo indice (esclusivo) della melodia coperto dall'appunto di bassi.
  int get anchorEnd => anchorStart + anchorSpan;

  void addBass(int code) => basses.add(code);

  /// Rimuove l'ultimo bottone del giro; true se il giro è rimasto vuoto.
  bool removeLastBass() {
    if (basses.isNotEmpty) basses.removeLast();
    return basses.isEmpty;
  }

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
    if (!midis.contains(midi)) {
      fingers.remove(midi);
      fingers2.remove(midi);
    }
    return midis.isEmpty;
  }

  /// Rimuove l'ultima nota (utile per gli abbellimenti); true se vuota.
  bool removeLast() {
    if (midis.isNotEmpty) {
      final m = midis.removeLast();
      if (!midis.contains(m)) {
        fingers.remove(m);
        fingers2.remove(m);
      }
    }
    return midis.isEmpty;
  }

  void setFinger(int midi, int finger) {
    if (midis.contains(midi)) fingers[midi] = finger;
  }

  void clearFinger(int midi) {
    fingers.remove(midi);
    fingers2.remove(midi);
  }

  int? fingerOf(int midi) => fingers[midi];

  /// Dito di sostituzione (valido solo se c'è il principale).
  void setFinger2(int midi, int finger) {
    if (midis.contains(midi) && fingers.containsKey(midi)) {
      fingers2[midi] = finger;
    }
  }

  void clearFinger2(int midi) => fingers2.remove(midi);

  int? finger2Of(int midi) => fingers2[midi];

  bool get isChord => midis.length > 1 && !run;

  /// Converte in accordo: note ordinate dal grave all'acuto, senza duplicati.
  void toChord() {
    if (!run) return;
    run = false;
    final unique = midis.toSet().toList()..sort();
    midis
      ..clear()
      ..addAll(unique);
  }

  /// Converte in abbellimento (l'ordine attuale diventa l'ordine di esecuzione).
  void toRun() {
    run = true;
  }

  Map<String, dynamic> toJson() => {
        'm': midis,
        'l': len,
        'f': fingers.map((k, v) => MapEntry(k.toString(), v)),
        if (fingers2.isNotEmpty)
          'f2': fingers2.map((k, v) => MapEntry(k.toString(), v)),
        if (run) 'r': true,
        if (label != null) 't': label,
        if (basses.isNotEmpty) ...{
          'b': basses,
          'as': anchorStart,
          'sp': anchorSpan,
        },
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        midis: ((j['m'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(),
        len: (j['l'] as int?) ?? 0,
        run: j['r'] == true,
        label: j['t'] as String?,
        basses:
            ((j['b'] as List?) ?? const []).map((e) => e as int).toList(),
        anchorStart: (j['as'] as int?) ?? 0,
        anchorSpan: (j['sp'] as int?) ?? 1,
        fingers: (j['f'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), v as int),
            ) ??
            {},
        fingers2: (j['f2'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), v as int),
            ) ??
            {},
      );
}
