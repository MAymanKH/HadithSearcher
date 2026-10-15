import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../viewmodels/settings_viewmodel.dart';

Future<void> showApiDetailsDialog<T extends Object>(
  BuildContext context, {
  required String title,
  required Future<ApiResult<T>> Function() load,
  required String Function(T) format,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ApiDetailsDialog(title: title, load: load, format: format),
);

class _ApiDetailsDialog<T extends Object> extends StatefulWidget {
  final String title;
  final Future<ApiResult<T>> Function() load;
  final String Function(T) format;

  const _ApiDetailsDialog({
    required this.title,
    required this.load,
    required this.format,
  });

  @override
  State<_ApiDetailsDialog<T>> createState() => _ApiDetailsDialogState<T>();
}

class _ApiDetailsDialogState<T extends Object>
    extends State<_ApiDetailsDialog<T>> {
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          title: Text(widget.title),
          content: SingleChildScrollView(
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : text.isNotEmpty
                ? SelectableText(text, style: settings.readingTextStyle)
                : Text(
                    result?.error == ApiError.notFound ||
                            result?.isSuccess == true
                        ? 'لا تتوفر معلومات إضافية من المصدر'
                        : 'تعذر تحميل المعلومات. ${result?.error?.arabicTitle ?? 'أعد المحاولة'}',
                  ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ),
                if (!loading &&
                    (result?.isError == true || snapshot.hasError) &&
                    result?.error != ApiError.notFound)
                  Flexible(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _result = widget.load();
                      }),
                      child: const Text('أعد المحاولة'),
                    ),
                  ),
                if (text.isNotEmpty)
                  Flexible(
                    child: TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: text)),
                      child: const Text('نسخ'),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
