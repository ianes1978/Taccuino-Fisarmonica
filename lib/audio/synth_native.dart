import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Sintetizzatore "musette": per ogni nota genera al volo un buffer WAV
/// (due onde triangolari leggermente scordate) e lo riproduce con SoLoud.
/// Nessun asset audio esterno; buffer in cache per MIDI.
class Synth {
  final SoLoud _soloud = SoLoud.instance;
  final Map<int, AudioSource> _cache = {};
  bool _ready = false;

  Future<void> init() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }
      _ready = _soloud.isInitialized;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> play(int midi) async {
    if (!_ready) return;
    try {
      var src = _cache[midi];
      if (src == null) {
        src = await _soloud.loadMem('note_$midi.wav', _wavForMidi(midi));
        _cache[midi] = src;
      }
      await _soloud.play(src);
    } catch (_) {
      // Silenziosamente ignora: l'audio non deve mai far crashare l'app.
    }
  }

  // --- Sintesi -------------------------------------------------------------

  static const int _sampleRate = 44100;
  static const double _duration = 0.7; // secondi
  static const double _attack = 0.02; // 20 ms
  static const double _tau = 0.22; // costante di decadimento (coda ~550 ms)
  static const double _detuneCents = 7.0;

  Uint8List _wavForMidi(int midi) {
    final n = (_sampleRate * _duration).round();
    final freq = 440.0 * math.pow(2, (midi - 69) / 12.0);
    final f1 = freq * math.pow(2, -_detuneCents / 1200.0);
    final f2 = freq * math.pow(2, _detuneCents / 1200.0);
    final attackSamples = _attack * _sampleRate;

    final samples = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final double env = i < attackSamples
          ? i / attackSamples
          : math.exp(-(i - attackSamples) / (_tau * _sampleRate));
      final s = (_triangle(t, f1) + _triangle(t, f2)) * 0.5;
      final v = (s * env * 0.32 * 32767).clamp(-32767.0, 32767.0);
      samples[i] = v.round();
    }
    return _pcm16ToWav(samples, _sampleRate);
  }

  double _triangle(double t, double freq) {
    final phase = (t * freq) % 1.0;
    return 4 * (phase < 0.5 ? phase : 1 - phase) - 1;
  }

  Uint8List _pcm16ToWav(Int16List pcm, int sampleRate) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length * 2;
    final buffer = ByteData(44 + dataSize);

    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // subchunk1 size
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    writeStr(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      buffer.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }
}
