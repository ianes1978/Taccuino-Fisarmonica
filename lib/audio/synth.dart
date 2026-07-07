/// Sintetizzatore "musette" con backend condizionale:
///  - nativo (Android): flutter_soloud + buffer WAV in memoria;
///  - web (GitHub Pages): Web Audio API (nessun header speciale richiesto).
export 'synth_native.dart' if (dart.library.js_interop) 'synth_web.dart';
