import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
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
                textDirection: useReadingSettings ? TextDirection.rtl : null,
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
                child: Text(context.l10n.close),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                },
                child: Text(context.l10n.copy),
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
