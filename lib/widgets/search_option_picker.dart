import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import '../models/search_option.dart';
import 'source_details_sheet.dart';
import 'app_loading_indicator.dart';
import 'details_sheet.dart';
import 'selection_sheet.dart';
import 'app_selection_tile.dart';
import '../services/api_service.dart';
import 'app_bottom_sheet.dart';

Future<void> showSearchOptionPicker(
  BuildContext context, {
  required SearchFilter filter,
  required Future<ApiResult<List<SearchOption>>> Function() loadOptions,
  required List<SearchOption> selected,
  List<SearchOption> excluded = const [],
  required void Function(
    List<SearchOption> selected,
    List<SearchOption> excluded,
  )
  onChanged,
}) => showAppBottomSheet<void>(
  context: context,
  shape: SelectionSheet.shape,
  builder: (_, scrollController) => _SearchOptionPicker(
    scrollController: scrollController,
    filter: filter,
    loadOptions: loadOptions,
    selected: selected,
    excluded: excluded,
    onChanged: onChanged,
  ),
);

class _SearchOptionPicker extends StatefulWidget {
  final ScrollController scrollController;
  final SearchFilter filter;
  final Future<ApiResult<List<SearchOption>>> Function() loadOptions;
  final List<SearchOption> selected;
  final List<SearchOption> excluded;
  final void Function(List<SearchOption> selected, List<SearchOption> excluded)
  onChanged;
  const _SearchOptionPicker({
    required this.scrollController,
    required this.filter,
    required this.loadOptions,
    required this.selected,
    required this.excluded,
    required this.onChanged,
  });

  @override
  State<_SearchOptionPicker> createState() => _SearchOptionPickerState();
}

class _SearchOptionPickerState extends State<_SearchOptionPicker> {
  static const _batchSize = 40;
  ScrollController get _scrollController => widget.scrollController;
  Timer? _debounce;
  String _query = '';
  final _visibleOptions = <_IndexedOption>[];
  late Iterator<_IndexedOption> _matches;
  bool _hasMoreOptions = false;
  bool _loading = true;
  ApiError? _error;
  late List<_IndexedOption> _options;
  late final Map<String, SearchOption> _selected;
  late bool _excluding;

  @override
  void initState() {
    super.initState();
    _excluding =
        widget.excluded.isNotEmpty ||
        widget.selected.isEmpty ||
        widget.selected.any((option) => option.apiCode == '0');
    _selected = {
      for (final option
          in widget.excluded.isNotEmpty ? widget.excluded : widget.selected)
        if (option.apiCode != '0') option.apiCode: option,
    };
    _options = <_IndexedOption>[];
    _includeSelection();
    _resetVisibleOptions();
    _scrollController.addListener(_loadMoreOptions);
    _load();
  }

  void _includeSelection() {
    final codes = _options.map((entry) => entry.option.apiCode).toSet();
    final missing = <_IndexedOption>[];
    for (final selected in _selected.values) {
      if (codes.add(selected.apiCode)) {
        missing.add(_IndexedOption(selected));
      }
    }
    _options.insertAll(0, missing.reversed);
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
        var compacted = false;
        setState(() {
          _options = options;
          _includeSelection();
          compacted = _compactSelection();
          _resetVisibleOptions();
          _loading = false;
        });
        if (compacted) _emitSelection();
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
        .where((entry) => entry.searchName.startsWith(_query))
        .followedBy(
          _options.where(
            (entry) =>
                entry.searchName.contains(_query) &&
                !entry.searchName.startsWith(_query),
          ),
        )
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
    super.dispose();
  }

  int get _selectionCount =>
      _excluding ? _options.length - _selected.length : _selected.length;

  bool get _everythingSelected => _excluding && _selected.isEmpty;

  bool _compactSelection() {
    if (_options.isNotEmpty &&
        (_selected.length > _options.length / 2 ||
            (_excluding && _selected.length == _options.length / 2))) {
      final complement = {
        for (final entry in _options)
          if (!_selected.containsKey(entry.option.apiCode))
            entry.option.apiCode: entry.option,
      };
      _selected
        ..clear()
        ..addAll(complement);
      _excluding = !_excluding;
      return true;
    }
    return false;
  }

  void _emitSelection() {
    if (_excluding &&
        _selected.isNotEmpty &&
        widget.filter == SearchFilter.grade) {
      widget.onChanged(
        _options
            .where((entry) => !_selected.containsKey(entry.option.apiCode))
            .map((entry) => entry.option)
            .toList(),
        [],
      );
    } else {
      widget.onChanged(
        _excluding ? [widget.filter.all] : _selected.values.toList(),
        _excluding ? _selected.values.toList() : [],
      );
    }
  }

  void _toggle(SearchOption option) {
    setState(() {
      if (option.apiCode == '0') {
        _excluding = !_everythingSelected;
        _selected.clear();
      } else {
        if (_selected.containsKey(option.apiCode)) {
          _selected.remove(option.apiCode);
        } else {
          _selected[option.apiCode] = option;
        }
        _compactSelection();
      }
    });
    _emitSelection();
  }

  Future<void> _showInfo(SearchOption option) => showDetailsSheet(
    context,
    title: widget.filter.label(context.l10n),
    child: widget.filter == SearchFilter.book
        ? BookSourceDetails(name: option.arabicName, id: option.apiCode)
        : ScholarSourceDetails(name: option.arabicName, id: option.apiCode),
  );

  Widget _tile(SearchOption option) {
    final all = option.apiCode == '0';
    final supportsInfo =
        !all &&
        (widget.filter == SearchFilter.book ||
            widget.filter == SearchFilter.scholar);
    return AppSelectionTile(
      title: Text(widget.filter.optionLabel(option, context.l10n)),
      multiple: true,
      selected: all
          ? _everythingSelected
                ? true
                : _selectionCount == 0
                ? false
                : null
          : _excluding != _selected.containsKey(option.apiCode),
      leading: supportsInfo
          ? IconButton(
              tooltip: context.l10n.infoAbout(option.arabicName),
              icon: const Icon(Icons.error_outline_rounded),
              onPressed: () => _showInfo(option),
            )
          : null,
      onTap: () => _toggle(option),
    );
  }

  @override
  Widget build(BuildContext context) => SelectionSheet(
    title: widget.filter.label(context.l10n),
    trailing: Text(context.l10n.selectedCount(_selectionCount)),
    search: widget.filter == SearchFilter.grade
        ? null
        : TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: context.l10n.searchByName,
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: _search,
          ),
    child: CustomScrollView(
      shrinkWrap: widget.filter == SearchFilter.grade,
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(child: _tile(widget.filter.all)),
        SliverToBoxAdapter(
          child: Divider(
            height: 16,
            indent: 24,
            endIndent: 24,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        if (_loading) const SliverToBoxAdapter(child: AppLoadingIndicator()),
        if (_error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.optionsLoadFailed(
                        _error!.title(context.l10n),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _load, child: Text(context.l10n.retry)),
                ],
              ),
            ),
          ),
        if (_visibleOptions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _loading
                      ? context.l10n.loadingOptions
                      : context.l10n.noMatchingOptions,
                ),
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
  );
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
