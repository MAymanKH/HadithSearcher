import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/search_option.dart';
import '../services/api_service.dart';

Future<SearchOption?> showSearchOptionPicker(
  BuildContext context, {
  required SearchFilter filter,
  required Future<ApiResult<List<SearchOption>>> Function() loadOptions,
  required SearchOption selected,
}) => showModalBottomSheet<SearchOption>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _SearchOptionPicker(
    filter: filter,
    loadOptions: loadOptions,
    selected: selected,
  ),
);

class _SearchOptionPicker extends StatefulWidget {
  final SearchFilter filter;
  final Future<ApiResult<List<SearchOption>>> Function() loadOptions;
  final SearchOption selected;
  const _SearchOptionPicker({
    required this.filter,
    required this.loadOptions,
    required this.selected,
  });

  @override
  State<_SearchOptionPicker> createState() => _SearchOptionPickerState();
}

class _SearchOptionPickerState extends State<_SearchOptionPicker> {
  static const _pageSize = 40;
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  int _page = 0;
  bool _loading = true;
  ApiError? _error;
  late List<_IndexedOption> _options;

  @override
  void initState() {
    super.initState();
    _options = _indexOptions(widget.filter.fallbackOptions);
    _includeSelection();
    _load();
  }

  void _includeSelection() {
    final selected = widget.selected;
    if (selected.apiCode != '0' &&
        !_options.any((entry) => entry.option.apiCode == selected.apiCode)) {
      _options.insert(0, _IndexedOption(selected));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loadOptions();
      if (!mounted) return;
      if (result.isSuccess) {
        final options = await compute(_indexOptions, result.data!);
        if (!mounted) return;
        setState(() {
          _options = options;
          _includeSelection();
          _loading = false;
        });
      } else {
        setState(() {
          _error = result.error;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.unknown;
        _loading = false;
      });
    }
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _query = _normalize(value.trim());
        _page = 0;
      });
      _scrollToTop();
    });
  }

  void _changePage(int page) {
    setState(() => _page = page);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _tile(SearchOption option) => ListTile(
    title: Text(option.arabicName),
    trailing: option.apiCode == widget.selected.apiCode
        ? const Icon(Icons.check)
        : null,
    onTap: () => Navigator.pop(context, option),
  );

  @override
  Widget build(BuildContext context) {
    final page = _options
        .where((entry) => entry.searchName.contains(_query))
        .skip(_page * _pageSize)
        .take(_pageSize + 1)
        .toList();
    final hasNext = page.length > _pageSize;
    final visibleCount = hasNext ? _pageSize : page.length;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * (keyboardHeight > 0 ? 1 : .8),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.filter.arabicName,
                  hintText: 'ابحث بالاسم...',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _search,
              ),
            ),
            _tile(widget.filter.all),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (_loading)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'تعذر تحميل جميع الخيارات. ${_error!.arabicTitle}',
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('أعد المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (page.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _loading
                              ? 'جارٍ تحميل الخيارات...'
                              : 'لا توجد خيارات مطابقة',
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: visibleCount,
                      itemBuilder: (context, index) =>
                          _tile(page[index].option),
                    ),
                ],
              ),
            ),
            if (_page > 0 || hasNext)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: _page > 0 ? () => _changePage(_page - 1) : null,
                    child: const Text('السابق'),
                  ),
                  Text('صفحة ${_page + 1}'),
                  TextButton(
                    onPressed: hasNext ? () => _changePage(_page + 1) : null,
                    child: const Text('التالي'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _normalize(String text) => text
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .toLowerCase();

class _IndexedOption {
  final SearchOption option;
  final String searchName;
  _IndexedOption(this.option) : searchName = _normalize(option.arabicName);
}

List<_IndexedOption> _indexOptions(List<SearchOption> options) => options
    .where((option) => option.apiCode != '0')
    .map(_IndexedOption.new)
    .toList();
