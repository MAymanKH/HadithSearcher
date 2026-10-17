import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/localization.dart';
import '../services/api_service.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'app_loading_indicator.dart';
import 'details_sheet.dart';

Future<void> showApiDetailsSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required Future<ApiResult<T>> Function() load,
  required String Function(T) format,
  String? emptyMessage,
}) => showDetailsSheet(
  context,
  title: title,
  child: _ApiDetailsContent(
    load: load,
    format: format,
    emptyMessage: emptyMessage,
  ),
);

class _ApiDetailsContent<T extends Object> extends StatefulWidget {
  final String? emptyMessage;
  final Future<ApiResult<T>> Function() load;
  final String Function(T) format;

  const _ApiDetailsContent({
    this.emptyMessage,
    required this.load,
    required this.format,
  });

  @override
  State<_ApiDetailsContent<T>> createState() => _ApiDetailsContentState<T>();
}

class _ApiDetailsContentState<T extends Object>
    extends State<_ApiDetailsContent<T>> {
  late Future<ApiResult<T>> _result;

  @override
  void initState() {
    super.initState();
    _result = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    return FutureBuilder<ApiResult<T>>(
      future: _result,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final text = result?.isSuccess == true
            ? widget.format(result!.data!).trim()
            : '';
        final loading = snapshot.connectionState != ConnectionState.done;
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppLoadingSwitcher(
                loading: loading,
                child: text.isNotEmpty
                    ? SelectableText(
                        text,
                        style: settings.readingTextStyle,
                        textDirection: TextDirection.rtl,
                      )
                    : Text(
                        result?.error == ApiError.notFound ||
                                result?.isSuccess == true
                            ? widget.emptyMessage ??
                                  context.l10n.noAdditionalInfo
                            : context.l10n.infoLoadFailed(
                                result?.error?.title(context.l10n) ??
                                    context.l10n.retry,
                              ),
                      ),
              ),
              if (!loading &&
                  (result?.isError == true || snapshot.hasError) &&
                  result?.error != ApiError.notFound)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _result = widget.load();
                    }),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.l10n.retry),
                  ),
                ),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: text)),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(context.l10n.copy),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
