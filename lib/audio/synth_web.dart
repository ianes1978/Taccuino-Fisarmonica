import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Backend web: sintesi "musette" con la Web Audio API.
/// Due oscillatori triangolari leggermente scordati (±7 cent) + inviluppo.
/// Funziona su GitHub Pages senza header COOP/COEP.
class Synth {
  web.AudioContext? _ctx;

  Future<void> init() async {
    try {
      _ctx = web.AudioContext();
    } catch (_) {
      _ctx = null;
    }
  }

  Future<void> play(int midi) async {
    final ctx = _ctx;
    if (ctx == null) return;
    try {
      // Le policy di autoplay tengono il contesto sospeso finché non c'è
      // un'interazione: qui siamo dentro un tocco, quindi possiamo riprendere.
      ctx.resume();

      final now = ctx.currentTime;
      final freq = 440.0 * math.pow(2, (midi - 69) / 12.0);

      final gain = ctx.createGain();
      gain.connect(ctx.destination);
      gain.gain.setValueAtTime(0.0001, now);
      gain.gain.linearRampToValueAtTime(0.28, now + 0.02); // attacco ~20 ms
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.7); // coda

      for (final cents in const [-7.0, 7.0]) {
        final osc = ctx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.value = (freq * math.pow(2, cents / 1200.0)).toDouble();
        osc.connect(gain);
        osc.start(now);
        osc.stop(now + 0.72);
      }
    } catch (_) {
      // Non far mai crashare l'app per l'audio.
    }
  }
}
