import 'package:flutter_tts/flutter_tts.dart';

class Speaker {
  final FlutterTts _tts = FlutterTts();

  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastText;

  // tune
  final Duration cooldown = const Duration(milliseconds: 1200);
  final Duration repeatAfter = const Duration(seconds: 3);

  Future<void> init() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  bool _isUrgent(String text) {
    final t = text.toLowerCase();
    return t.contains("very close") || t.contains("stop") || t.contains("danger");
  }

  Future<void> say(String text) async {
    final now = DateTime.now();

    // Drop empty
    if (text.trim().isEmpty) return;

    // Dedupe
    if (_lastText == text && now.difference(_lastSpokenAt) < repeatAfter && !_isUrgent(text)) {
      return;
    }

    // Cooldown
    if (now.difference(_lastSpokenAt) < cooldown && !_isUrgent(text)) {
      return;
    }

    // Urgent interrupt
    if (_isUrgent(text)) {
      await _tts.stop();
    }

    await _tts.speak(text);
    _lastText = text;
    _lastSpokenAt = now;
  }
}