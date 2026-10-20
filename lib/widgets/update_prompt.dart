import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/localization.dart';
import 'app_snack_bar.dart';
import '../services/update_service.dart';

Future<void> checkForUpdates(
  BuildContext context, {
  bool automatic = false,
}) async {
  final service = context.read<UpdateService>();
  final updates = await service.check(automatic: automatic);
  if (!context.mounted) return;
  if (updates.isEmpty) {
    if (!automatic) {
      showAppSnackBar(
        context,
        SnackBar(
          content: Text(
            service.failed
                ? context.l10n.updateCheckFailed
                : context.l10n.upToDate,
          ),
        ),
      );
    }
    return;
  }
  final selected = await showDialog<Uri>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.outlineVariant),
        ),
        title: Text(context.l10n.updateAvailable),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < updates.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, updates[index].url),
                    icon: const Icon(Icons.system_update_rounded),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.updateFrom(updates[index].source.label),
                          textAlign: TextAlign.center,
                        ),
                        if (updates[index].version != null)
                          Text(
                            updates[index].version!,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.onPrimary),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.later),
          ),
        ],
      );
    },
  );
  if (selected == null || !context.mounted) return;
  try {
    if (await service.openUrl(selected)) return;
  } catch (_) {
    // The device may have no application capable of opening the update page.
  }
  if (context.mounted) {
    showAppSnackBar(
      context,
      SnackBar(content: Text(context.l10n.updateOpenFailed)),
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
      icon: const Icon(Icons.system_update_rounded),
      label: Text(
        service.isChecking
            ? context.l10n.checkingUpdates
            : context.l10n.checkUpdates,
      ),
      onPressed: service.isChecking ? null : () => checkForUpdates(context),
    );
  }
}
