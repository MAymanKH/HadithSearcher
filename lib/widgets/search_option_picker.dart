import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/search_option.dart';
import 'app_selection_tile.dart';
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
  static const _batchSize = 40;
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  final _visibleOptions = <_IndexedOption>[];
  late Iterator<_IndexedOption> _matches;
  bool _hasMoreOptions = false;
  bool _loading = true;
  ApiError? _error;
  late List<_IndexedOption> _options;

  @override
  void initState() {
    super.initState();
    _options = _indexOptions(widget.filter.fallbackOptions);
    _includeSelection();
    _resetVisibleOptions();
    _scrollController.addListener(_loadMoreOptions);
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
          _resetVisibleOptions();
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
        _resetVisibleOptions();
      });
      _scrollToTop();
    });
  }

  void _resetVisibleOptions() {
    _matches = _options
        .where((entry) => entry.searchName.contains(_query))
        .iterator;
    _visibleOptions.clear();
    _hasMoreOptions = true;
    _appendBatch();
  }

  void _appendBatch() {
    for (var i = 0; i < _batchSize; i++) {
      if (!_matches.moveNext()) {
        _hasMoreOptions = false;
        break;
      }
      _visibleOptions.add(_matches.current);
    }
  }

  void _loadMoreOptions() {
    if (_hasMoreOptions && _scrollController.position.extentAfter < 300) {
      setState(_appendBatch);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_loadMoreOptions);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _tile(SearchOption option) => AppSelectionTile(
    title: Text(option.arabicName),
    selected: option.apiCode == widget.selected.apiCode,
    onTap: () => Navigator.pop(context, option),
  );

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final labelStyle = _query.isNotEmpty
        ? TextStyle(color: Theme.of(context).colorScheme.primary)
        : null;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: widget.filter.arabicName,
                  labelStyle: labelStyle,
                  floatingLabelStyle: labelStyle,
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
                  if (_visibleOptions.isEmpty)
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
                      itemCount: _visibleOptions.length,
                      itemBuilder: (context, index) =>
                          _tile(_visibleOptions[index].option),
                    ),
                ],
              ),
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
