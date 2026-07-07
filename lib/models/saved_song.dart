import 'entry.dart';

/// Una musica salvata con nome.
class SavedSong {
  final String name;
  final List<Entry> entries;
  final String savedAt; // ISO 8601

  SavedSong({
    required this.name,
    required this.entries,
    required this.savedAt,
  });

  int get noteCount => entries.length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': savedAt,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory SavedSong.fromJson(Map<String, dynamic> j) => SavedSong(
        name: j['name'] as String,
        savedAt: (j['savedAt'] as String?) ?? '',
        entries: (j['entries'] as List)
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Copia profonda delle voci (per non condividere riferimenti con la
  /// sequenza di lavoro).
  List<Entry> cloneEntries() =>
      entries.map((e) => Entry.fromJson(e.toJson())).toList();
}
