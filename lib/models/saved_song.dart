import 'entry.dart';

/// Una musica salvata con nome.
class SavedSong {
  final String name;
  final List<Entry> entries;

  /// Traccia dei bassi (riga parallela).
  final List<Entry> bassEntries;
  final String savedAt; // ISO 8601

  SavedSong({
    required this.name,
    required this.entries,
    required this.savedAt,
    List<Entry>? bassEntries,
  }) : bassEntries = bassEntries ?? [];

  int get noteCount => entries.length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': savedAt,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (bassEntries.isNotEmpty)
          'bass': bassEntries.map((e) => e.toJson()).toList(),
      };

  factory SavedSong.fromJson(Map<String, dynamic> j) => SavedSong(
        name: j['name'] as String,
        savedAt: (j['savedAt'] as String?) ?? '',
        entries: (j['entries'] as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
        bassEntries: ((j['bass'] as List?) ?? const [])
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Copia profonda delle voci (per non condividere riferimenti con la
  /// sequenza di lavoro).
  List<Entry> cloneEntries() =>
      entries.map((e) => Entry.fromJson(e.toJson())).toList();

  List<Entry> cloneBassEntries() =>
      bassEntries.map((e) => Entry.fromJson(e.toJson())).toList();
}
