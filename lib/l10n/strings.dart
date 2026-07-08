import 'dart:ui' as ui;

/// Stringhe dell'interfaccia nelle lingue supportate (it, en, pt).
/// La lingua di default è quella di sistema; se non è supportata → inglese.
class Str {
  final String annotation;
  final String emptyHint;
  final String fullscreenView;
  final String listen;
  final String stop;
  final String copy;
  final String copied;
  final String clear;
  final String namesTooltip;
  final String audioOn;
  final String muted;
  final String menuSave;
  final String Function(String) menuSaveNamed;
  final String menuSaveAs;
  final String menuList;
  final String menuExportPdf;
  final String menuSettings;
  final String nothingToSave;
  final String nothingToExport;
  final String Function(String) savedToast;
  final String Function(String) overwrittenToast;
  final String songNameHint;
  final String cancel;
  final String save;
  final String pdfDialogTitle;
  final String pdfTitleHint;
  final String export;
  final String pdfExportFailed;
  final String Function(String) importedOne;
  final String Function(int) importedMany;
  final String importNothing;
  final String savedSongs;
  final String importFile;
  final String exportAll;
  final String Function(int) exportedAll;
  final String noSongs;
  final String Function(int) entriesCount;
  final String preview;
  final String exportJson;
  final String rename;
  final String delete;
  final String newNameHint;
  final String deleteQuestion;
  final String Function(String) deleteMessage;
  final String actions;
  final String chordMode;
  final String ornamentMode;
  final String addTextTooltip;
  final String practice;
  final String deleteEntry;
  final String lessDuration;
  final String moreDuration;
  final String Function(int) fingerN;
  final String ornamentSpeed;
  final String noNotes;
  final String close;
  final String smaller;
  final String larger;
  final String sectionTextTitle;
  final String sectionTextHint;
  final String add;
  final String editText;
  final String textEmptyDeletes;
  final String settingsTitle;
  final String language;
  final String systemLanguage;

  const Str({
    required this.annotation,
    required this.emptyHint,
    required this.fullscreenView,
    required this.listen,
    required this.stop,
    required this.copy,
    required this.copied,
    required this.clear,
    required this.namesTooltip,
    required this.audioOn,
    required this.muted,
    required this.menuSave,
    required this.menuSaveNamed,
    required this.menuSaveAs,
    required this.menuList,
    required this.menuExportPdf,
    required this.menuSettings,
    required this.nothingToSave,
    required this.nothingToExport,
    required this.savedToast,
    required this.overwrittenToast,
    required this.songNameHint,
    required this.cancel,
    required this.save,
    required this.pdfDialogTitle,
    required this.pdfTitleHint,
    required this.export,
    required this.pdfExportFailed,
    required this.importedOne,
    required this.importedMany,
    required this.importNothing,
    required this.savedSongs,
    required this.importFile,
    required this.exportAll,
    required this.exportedAll,
    required this.noSongs,
    required this.entriesCount,
    required this.preview,
    required this.exportJson,
    required this.rename,
    required this.delete,
    required this.newNameHint,
    required this.deleteQuestion,
    required this.deleteMessage,
    required this.actions,
    required this.chordMode,
    required this.ornamentMode,
    required this.addTextTooltip,
    required this.practice,
    required this.deleteEntry,
    required this.lessDuration,
    required this.moreDuration,
    required this.fingerN,
    required this.ornamentSpeed,
    required this.noNotes,
    required this.close,
    required this.smaller,
    required this.larger,
    required this.sectionTextTitle,
    required this.sectionTextHint,
    required this.add,
    required this.editText,
    required this.textEmptyDeletes,
    required this.settingsTitle,
    required this.language,
    required this.systemLanguage,
  });
}

String _sIt(String name) => 'Salva "$name"';
String _sEn(String name) => 'Save "$name"';
String _sPt(String name) => 'Salvar "$name"';

final Str strIt = Str(
  annotation: 'Annotazione',
  emptyHint: 'Tocca un tasto per iniziare.\nLe note appaiono qui.',
  fullscreenView: 'Visualizza a schermo intero',
  listen: 'Ascolta',
  stop: 'Ferma',
  copy: 'Copia',
  copied: 'Copiato negli appunti',
  clear: 'Svuota',
  namesTooltip: 'Sistema nomi',
  audioOn: 'Audio attivo',
  muted: 'Muto',
  menuSave: 'Salva',
  menuSaveNamed: _sIt,
  menuSaveAs: 'Salva con nome',
  menuList: 'Lista',
  menuExportPdf: 'Esporta PDF',
  menuSettings: 'Impostazioni',
  nothingToSave: 'Niente da salvare',
  nothingToExport: 'Niente da esportare',
  savedToast: (n) => 'Salvato "$n"',
  overwrittenToast: (n) => 'Sovrascritto "$n"',
  songNameHint: 'Nome della musica',
  cancel: 'Annulla',
  save: 'Salva',
  pdfDialogTitle: 'Esporta PDF',
  pdfTitleHint: 'Titolo del PDF',
  export: 'Esporta',
  pdfExportFailed: 'Export PDF non riuscito',
  importedOne: (n) => 'Importato "$n"',
  importedMany: (n) => 'Importate $n musiche',
  importNothing: 'Nessun file importato',
  savedSongs: 'Musiche salvate',
  importFile: 'Importa file',
  exportAll: 'Esporta tutte',
  exportedAll: (n) => 'Esportate $n musiche',
  noSongs: 'Nessuna musica salvata.',
  entriesCount: (n) => '$n voci',
  preview: 'Anteprima',
  exportJson: 'Esporta JSON',
  rename: 'Rinomina',
  delete: 'Elimina',
  newNameHint: 'Nuovo nome',
  deleteQuestion: 'Eliminare?',
  deleteMessage: (n) => 'Rimuovo "$n" dalle musiche salvate.',
  actions: 'Azioni',
  chordMode: 'Modalità accordo',
  ornamentMode: 'Modalità abbellimento',
  addTextTooltip: 'Aggiungi testo (sottotitolo di sezione)',
  practice: 'prova',
  deleteEntry: 'Cancella voce',
  lessDuration: 'Meno durata',
  moreDuration: 'Più durata',
  fingerN: (n) => 'Dito $n',
  ornamentSpeed: 'Velocità abbellimenti (1..5)',
  noNotes: 'Nessuna nota.',
  close: 'Chiudi',
  smaller: 'Riduci',
  larger: 'Ingrandisci',
  sectionTextTitle: 'Testo di sezione',
  sectionTextHint: 'Es. Ritornello, 2ª volta…',
  add: 'Aggiungi',
  editText: 'Modifica testo',
  textEmptyDeletes: 'Testo (vuoto = elimina)',
  settingsTitle: 'Impostazioni',
  language: 'Lingua',
  systemLanguage: 'Sistema',
);

final Str strEn = Str(
  annotation: 'Annotation',
  emptyHint: 'Tap a key to start.\nNotes appear here.',
  fullscreenView: 'Full-screen view',
  listen: 'Play',
  stop: 'Stop',
  copy: 'Copy',
  copied: 'Copied to clipboard',
  clear: 'Clear',
  namesTooltip: 'Note naming',
  audioOn: 'Audio on',
  muted: 'Muted',
  menuSave: 'Save',
  menuSaveNamed: _sEn,
  menuSaveAs: 'Save as',
  menuList: 'List',
  menuExportPdf: 'Export PDF',
  menuSettings: 'Settings',
  nothingToSave: 'Nothing to save',
  nothingToExport: 'Nothing to export',
  savedToast: (n) => 'Saved "$n"',
  overwrittenToast: (n) => 'Overwrote "$n"',
  songNameHint: 'Song name',
  cancel: 'Cancel',
  save: 'Save',
  pdfDialogTitle: 'Export PDF',
  pdfTitleHint: 'PDF title',
  export: 'Export',
  pdfExportFailed: 'PDF export failed',
  importedOne: (n) => 'Imported "$n"',
  importedMany: (n) => 'Imported $n songs',
  importNothing: 'No file imported',
  savedSongs: 'Saved songs',
  importFile: 'Import file',
  exportAll: 'Export all',
  exportedAll: (n) => 'Exported $n songs',
  noSongs: 'No saved songs.',
  entriesCount: (n) => '$n entries',
  preview: 'Preview',
  exportJson: 'Export JSON',
  rename: 'Rename',
  delete: 'Delete',
  newNameHint: 'New name',
  deleteQuestion: 'Delete?',
  deleteMessage: (n) => 'This removes "$n" from saved songs.',
  actions: 'Actions',
  chordMode: 'Chord mode',
  ornamentMode: 'Ornament mode',
  addTextTooltip: 'Add text (section subtitle)',
  practice: 'practice',
  deleteEntry: 'Delete entry',
  lessDuration: 'Less duration',
  moreDuration: 'More duration',
  fingerN: (n) => 'Finger $n',
  ornamentSpeed: 'Ornament speed (1..5)',
  noNotes: 'No notes.',
  close: 'Close',
  smaller: 'Smaller',
  larger: 'Larger',
  sectionTextTitle: 'Section text',
  sectionTextHint: 'E.g. Chorus, 2nd time…',
  add: 'Add',
  editText: 'Edit text',
  textEmptyDeletes: 'Text (empty = delete)',
  settingsTitle: 'Settings',
  language: 'Language',
  systemLanguage: 'System',
);

final Str strPt = Str(
  annotation: 'Anotação',
  emptyHint: 'Toque uma tecla para começar.\nAs notas aparecem aqui.',
  fullscreenView: 'Ver em tela cheia',
  listen: 'Tocar',
  stop: 'Parar',
  copy: 'Copiar',
  copied: 'Copiado para a área de transferência',
  clear: 'Limpar',
  namesTooltip: 'Sistema de nomes',
  audioOn: 'Áudio ativo',
  muted: 'Mudo',
  menuSave: 'Salvar',
  menuSaveNamed: _sPt,
  menuSaveAs: 'Salvar como',
  menuList: 'Lista',
  menuExportPdf: 'Exportar PDF',
  menuSettings: 'Configurações',
  nothingToSave: 'Nada para salvar',
  nothingToExport: 'Nada para exportar',
  savedToast: (n) => 'Salvo "$n"',
  overwrittenToast: (n) => 'Sobrescrito "$n"',
  songNameHint: 'Nome da música',
  cancel: 'Cancelar',
  save: 'Salvar',
  pdfDialogTitle: 'Exportar PDF',
  pdfTitleHint: 'Título do PDF',
  export: 'Exportar',
  pdfExportFailed: 'Falha ao exportar o PDF',
  importedOne: (n) => 'Importado "$n"',
  importedMany: (n) => '$n músicas importadas',
  importNothing: 'Nenhum arquivo importado',
  savedSongs: 'Músicas salvas',
  importFile: 'Importar arquivo',
  exportAll: 'Exportar todas',
  exportedAll: (n) => '$n músicas exportadas',
  noSongs: 'Nenhuma música salva.',
  entriesCount: (n) => '$n vozes',
  preview: 'Prévia',
  exportJson: 'Exportar JSON',
  rename: 'Renomear',
  delete: 'Excluir',
  newNameHint: 'Novo nome',
  deleteQuestion: 'Excluir?',
  deleteMessage: (n) => 'Remove "$n" das músicas salvas.',
  actions: 'Ações',
  chordMode: 'Modo acorde',
  ornamentMode: 'Modo ornamento',
  addTextTooltip: 'Adicionar texto (subtítulo de seção)',
  practice: 'ensaio',
  deleteEntry: 'Excluir voz',
  lessDuration: 'Menos duração',
  moreDuration: 'Mais duração',
  fingerN: (n) => 'Dedo $n',
  ornamentSpeed: 'Velocidade dos ornamentos (1..5)',
  noNotes: 'Sem notas.',
  close: 'Fechar',
  smaller: 'Reduzir',
  larger: 'Ampliar',
  sectionTextTitle: 'Texto de seção',
  sectionTextHint: 'Ex. Refrão, 2ª vez…',
  add: 'Adicionar',
  editText: 'Editar texto',
  textEmptyDeletes: 'Texto (vazio = excluir)',
  settingsTitle: 'Configurações',
  language: 'Idioma',
  systemLanguage: 'Sistema',
);

/// Risolve la lingua: 'system' usa la lingua del dispositivo; it/en/pt
/// esplicite; qualunque altra lingua di sistema → inglese.
Str resolveStrings(String pref) {
  final code = pref == 'system'
      ? ui.PlatformDispatcher.instance.locale.languageCode
      : pref;
  switch (code) {
    case 'it':
      return strIt;
    case 'pt':
      return strPt;
    default:
      return strEn;
  }
}
