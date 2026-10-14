import 'package:flutter/material.dart';
import '../models/search_option.dart';

Future<SearchOption?> showSearchOptionPicker(
  BuildContext context, {
  required String title,
  required List<SearchOption> options,
  required SearchOption selected,
}) => showModalBottomSheet<SearchOption>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _SearchOptionPicker(title: title, options: options, selected: selected),
);

class _SearchOptionPicker extends StatefulWidget {
  final String title;
  final List<SearchOption> options;
  final SearchOption selected;
  const _SearchOptionPicker({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  State<_SearchOptionPicker> createState() => _SearchOptionPickerState();
}

class _SearchOptionPickerState extends State<_SearchOptionPicker> {
  String _query = '';
  String _normalize(String text) => text
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .toLowerCase();

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_query.trim());
    final options = widget.options
        .where((option) => _normalize(option.arabicName).contains(query))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.title,
                  hintText: 'ابحث بالاسم...',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: Text('لا توجد خيارات مطابقة'))
                  : ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        return ListTile(
                          title: Text(option.arabicName),
                          trailing: option.apiCode == widget.selected.apiCode
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
