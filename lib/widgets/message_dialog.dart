import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/settings_viewmodel.dart';

/// Shows a dialog with a message.
Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String content,
  bool useReadingSettings = false,
}) {
  return showDialog(
    context: context,
    builder: (context) {
      final settings = useReadingSettings
          ? context.watch<SettingsViewModel>()
          : null;
      return AlertDialog(
        contentPadding: settings?.padding,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              SelectableText(
                content,
                style:
                    settings?.readingTextStyle ?? const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                },
                child: const Text('نسخ'),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Shows an error dialog based on error type.
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String content,
}) {
  return showMessageDialog(context, title: title, content: content);
}
