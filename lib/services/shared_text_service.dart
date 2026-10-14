import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedTextService extends ChangeNotifier {
  static final instance = SharedTextService._();
  SharedTextService._();
  static const channel = MethodChannel('hadithsearcher/shared_text');
  String? _pending;
  int _revision = 0;
  int get revision => _revision;

  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') _receive(call.arguments as String?);
    });
    try {
      final revision = _revision;
      final initialText = await channel.invokeMethod<String>(
        'consumeSharedText',
      );
      if (revision == _revision) _receive(initialText);
    } on MissingPluginException {
      // Incoming Android shares are unavailable on other platforms.
    }
  }

  void _receive(String? text) {
    if (text == null || text.trim().isEmpty) return;
    _pending = text.trim();
    _revision++;
    notifyListeners();
  }

  String? takePendingText() {
    final text = _pending;
    _pending = null;
    return text;
  }
}
