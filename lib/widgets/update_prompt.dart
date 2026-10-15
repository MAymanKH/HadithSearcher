import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';

Future<void> checkForUpdates(
  BuildContext context, {
  bool automatic = false,
}) async {
  final service = context.read<UpdateService>();
  final update = await service.check(automatic: automatic);
  if (!context.mounted) return;
  if (update == null) {
    if (!automatic) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            service.failed
                ? 'تعذر التحقق من التحديثات. حاول مرة أخرى لاحقاً.'
                : 'أنت تستخدم أحدث إصدار متاح.',
          ),
        ),
      );
    }
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تحديث جديد متاح'),
      content: Text(
        update.version == null
            ? 'يتوفر تحديث جديد للتطبيق على Google Play.'
            : 'يتوفر الإصدار ${update.version}. هل تريد التحديث الآن؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('لاحقاً'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('تحديث الآن'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  try {
    if (await service.openUrl(update.url)) return;
  } catch (_) {
    // The device may have no application capable of opening the update page.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذر فتح صفحة التحديث. حاول مرة أخرى لاحقاً.'),
      ),
    );
  }
}

class UpdatePrompt extends StatefulWidget {
  final Widget child;

  const UpdatePrompt({super.key, required this.child});

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      await checkForUpdates(context, automatic: true);
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpdateCheckButton extends StatelessWidget {
  const UpdateCheckButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<UpdateService>();
    return TextButton.icon(
      icon: const Icon(Icons.system_update),
      label: Text(
        service.isChecking ? 'جارٍ التحقق…' : 'التحقق من التحديثات',
      ),
      onPressed: service.isChecking ? null : () => checkForUpdates(context),
    );
  }
}
