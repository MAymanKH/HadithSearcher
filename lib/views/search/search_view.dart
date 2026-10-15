import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../l10n/localization.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../models/search_params.dart';
import '../../models/search_option.dart';
import '../../widgets/search_option_picker.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../../widgets/back_to_top_button.dart';
import '../../widgets/hadith_card.dart';

class SearchView extends StatefulWidget {
  final String? sharedText;
  final int shareRevision;
  const SearchView({super.key, this.sharedText, this.shareRevision = 0});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> with ScrollToTopMixin {
  static const _filterGap = 10.0;
  final _textController = TextEditingController();
  final _excludedWordsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initScrollController();
    scrollController.addListener(_loadNearEnd);

    // Initialize ViewModel and sync text controllers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<SearchViewModel>();
      await vm.init();
      if (!mounted) return;
      if (mounted) {
        if (widget.sharedText != null) {
          vm.prepareSharedSearch(widget.sharedText!, widget.shareRevision);
        }
        _textController.text = vm.searchQuery;
        _excludedWordsController.text = vm.excludedWords;
      }
    });
  }

  @override
  void didUpdateWidget(SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shareRevision != oldWidget.shareRevision &&
        widget.sharedText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final vm = context.read<SearchViewModel>();
        vm.prepareSharedSearch(widget.sharedText!, widget.shareRevision);
        _textController.text = vm.searchQuery;
      });
    }
  }

  void _loadNearEnd() {
    if (scrollController.hasClients &&
        scrollController.position.extentAfter < 500) {
      context.read<SearchViewModel>().loadMore();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _excludedWordsController.dispose();
    scrollController.removeListener(_loadNearEnd);
    disposeScrollController();
    super.dispose();
  }

  Future<void> _onSearch() async {
    FocusScope.of(context).unfocus();
    final vm = context.read<SearchViewModel>();
    hideBackToTopButton();
    vm.closeAdvancedSearch();
    vm.setSearchQuery(_textController.text);
    await vm.saveAdvancedPrefs();
    await vm.search(_textController.text);

    if (vm.errorMessage == 'emptySearch' && mounted) {
      showAppSnackBar(
        context,
        SnackBar(
          content: Text(context.l10n.emptySearch),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      vm.clearError();
    }
    // Network/timeout errors are handled in _buildResults as inline messages
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.search,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        actionsPadding: const EdgeInsetsDirectional.only(end: 10),
        actions: [
          if (vm.activeFilters.isNotEmpty)
            IconButton(
              tooltip: vm.showActiveFilters
                  ? context.l10n.hideActiveFilters
                  : context.l10n.showActiveFilters,
              onPressed: () => vm.setShowActiveFilters(!vm.showActiveFilters),
              icon: Badge(
                label: Text('${vm.activeFilters.length}'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                textColor: Theme.of(context).colorScheme.onSurface,
                child: Icon(
                  vm.showActiveFilters ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () async {
              final vm = context.read<SearchViewModel>();
              if (vm.isAdvancedSearchOpen) {
                // Closing the panel - check if settings changed
                final hasChanged = vm.hasSettingsChanged();
                await vm.saveAdvancedPrefs();
                vm.toggleAdvancedSearch();

                // If settings changed and there's a search query, re-search
                if (hasChanged && _textController.text.trim().isNotEmpty) {
                  await _onSearch();
                }
              } else {
                // Opening the panel
                vm.toggleAdvancedSearch();
              }
            },
            icon: const Icon(Icons.tune, size: 22),
            label: Text(context.l10n.filters, style: TextStyle(fontSize: 14)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 48),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            _buildSearchBar(screenWidth),
            const SizedBox(height: _filterGap),
            AnimatedSwitcher(
              key: const ValueKey('active-filters-transition'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: vm.activeFilters.isNotEmpty && vm.showActiveFilters
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: _filterGap),
                      child: _buildActiveFilters(vm),
                    )
                  : const SizedBox.shrink(),
            ),
            if (vm.isAdvancedSearchOpen)
              _buildAdvancedSearch(vm)
            else if (vm.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              _buildResults(vm),
          ],
        ),
      ),
      floatingActionButton: buildBackToTopButton(),
    );
  }

  Widget _buildSearchBar(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              autofocus: false,
              textInputAction: TextInputAction.search,
              controller: _textController,
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
                constraints: BoxConstraints(minHeight: 60),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: context.read<SearchViewModel>().setSearchQuery,
              onSubmitted: (_) => _onSearch(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 30),
            label: Text(context.l10n.searchAction),
            onPressed: _onSearch,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearch(SearchViewModel vm) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 15),
            Text(
              context.l10n.advancedSearch,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildFilterSwitch(
              title: context.l10n.rememberFilters,
              subtitle: context.l10n.rememberFiltersHelp,
              value: vm.saveAdvancedSettings,
              onChanged: vm.setSaveAdvancedSettings,
            ),
            _buildFilterSwitch(
              title: context.l10n.specialistSearch,
              subtitle: context.l10n.specialistSearchHelp,
              value: vm.specialist,
              onChanged: vm.setSpecialist,
            ),
            _buildDropdownRow(
              context.l10n.searchMethod,
              vm.searchWay,
              SearchWay.values,
              (value) {
                if (value != null) vm.setSearchWay(value);
              },
              itemLabel: (value) => value.label(context.l10n),
              isDefault: vm.searchWay == SearchWay.anyWord,
            ),
            _buildCatalogField(SearchFilter.grade, vm),
            _buildDropdownRow(
              context.l10n.searchRange,
              vm.searchRange,
              SearchRange.values,
              (value) {
                if (value != null) vm.setSearchRange(value);
              },
              itemLabel: (value) => value.label(context.l10n),
              isDefault: vm.searchRange == SearchRange.all,
            ),
            for (final filter in SearchFilter.values)
              if (filter != SearchFilter.grade) _buildCatalogField(filter, vm),
            _buildExcludedWordsField(vm),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).animate().fade(duration: 200.ms);
  }

  Future<void> _clearFilters(SearchViewModel vm) async {
    vm.resetFilters();
    _excludedWordsController.clear();
    await vm.saveAdvancedPrefs();
    if (mounted && _textController.text.trim().isNotEmpty) await _onSearch();
  }

  Widget _buildActiveFilters(SearchViewModel vm) => SizedBox(
    key: const ValueKey('active-filters-row'),
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        TextButton(
          onPressed: () => _clearFilters(vm),
          child: Text(context.l10n.clearFilters),
        ),
        ...vm
            .localizedActiveFilters(context.l10n)
            .map(
              (label) => Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Chip(label: Text(label)),
              ),
            ),
      ],
    ),
  );

  TextStyle? _filterLabelStyle(bool active) =>
      active ? TextStyle(color: Theme.of(context).colorScheme.primary) : null;

  Widget _buildCatalogField(SearchFilter filter, SearchViewModel vm) => Padding(
    padding: const EdgeInsets.all(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () async {
        FocusScope.of(context).unfocus();
        await showSearchOptionPicker(
          context,
          filter: filter,
          loadOptions: () => vm.loadFilterOptions(filter),
          selected: vm.selectedOptions(filter),
          excluded: vm.excludedOptions(filter),
          onChanged: (value, excluded) {
            vm.setSelectedOptions(filter, value, excluded: excluded);
            unawaited(vm.saveAdvancedPrefs());
          },
        );
        if (!mounted) return;
        // Prevent focus restoration to the search bar when the sheet pops.
        FocusScope.of(context).unfocus();
        await vm.saveAdvancedPrefs();
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: filter.label(context.l10n),
          labelStyle: _filterLabelStyle(
            vm.excludedOptions(filter).isNotEmpty ||
                vm
                    .selectedOptions(filter)
                    .any((option) => option.apiCode != '0'),
          ),
          floatingLabelStyle: _filterLabelStyle(
            vm.excludedOptions(filter).isNotEmpty ||
                vm
                    .selectedOptions(filter)
                    .any((option) => option.apiCode != '0'),
          ),
          suffixIcon: Icon(
            filter == SearchFilter.grade
                ? Icons.expand_more_rounded
                : Icons.search,
          ),
        ),
        child: Text(
          vm.selectionLabel(filter, context.l10n),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  Widget _buildDropdownRow<T>(
    String label,
    T value,
    List<T> items,
    void Function(T?) onChanged, {
    required String Function(T) itemLabel,
    required bool isDefault,
  }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: AppDropdown<T>(
        title: label,
        key: ValueKey('$label:$value'),
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: _filterLabelStyle(!isDefault),
          floatingLabelStyle: _filterLabelStyle(!isDefault),
        ),
        onChanged: onChanged,
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildExcludedWordsField(SearchViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _excludedWordsController,
        decoration: InputDecoration(hintText: context.l10n.excludeWordsHint),
        onChanged: vm.setExcludedWords,
      ),
    );
  }

  Widget _buildFilterSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: colors.onSurface.withValues(alpha: 0.28)),
          ),
          tileColor: colors.primaryContainer.withValues(alpha: 0.45),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          activeTrackColor: colors.onSurface,
          activeThumbColor: colors.surface,
          inactiveTrackColor: colors.surface,
          inactiveThumbColor: colors.onSurface.withValues(alpha: 0.65),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (states) => colors.onSurface.withValues(
              alpha: states.contains(WidgetState.selected) ? 1 : 0.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(SearchViewModel vm) {
    // Show error states inline
    if (vm.errorMessage != null && vm.errorMessage != 'emptySearch') {
      IconData icon;
      String title;
      String description;

      if (vm.errorMessage == 'noResults') {
        icon = Icons.search_off;
        title = context.l10n.noResults;
        description = context.l10n.searchNoResultsHelp;
      } else if (vm.errorMessage!.contains('خطأ بالإتصال')) {
        icon = Icons.wifi_off;
        title = context.l10n.connectionError;
        description = context.l10n.connectionHelp;
      } else if (vm.errorMessage!.contains('نفذ الوقت')) {
        icon = Icons.timer_off;
        title = context.l10n.timeout;
        description = context.l10n.timeoutHelp;
      } else {
        icon = Icons.error_outline;
        title = localizedError(vm.errorMessage!, context.l10n);
        description = context.l10n.tryAgain;
      }

      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 100, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _onSearch(),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (vm.isEmpty) {
      return Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: const ValueKey('search-placeholder-fade'),
                      tween: Tween(
                        begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
                        end: 1,
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: const Icon(
                        Icons.search,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      context.l10n.searchEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: PageStorageKey<String>(
                'search-results-${vm.resultRevision}',
              ),
              controller: scrollController,
              itemCount: vm.results.length + (vm.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == vm.results.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final hadith = vm.results[index];
                return HadithCard(
                  key: PageStorageKey<String>('search-hadith-${hadith.id}'),
                  hadith: hadith,
                  margin:
                      index == 0 &&
                          vm.activeFilters.isNotEmpty &&
                          vm.showActiveFilters
                      ? const EdgeInsets.fromLTRB(10, 0, 10, 10)
                      : const EdgeInsets.all(10),
                  isFavourite: vm.isFavourite(hadith.id),
                  onFavouriteToggle: () async {
                    final error = await vm.toggleFavourite(hadith);
                    if (error != null && context.mounted) {
                      showAppSnackBar(
                        context,
                        SnackBar(
                          content: Text(localizedError(error, context.l10n)),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            ).animate().fade(duration: 200.ms),
          ),
        ],
      ),
    );
  }
}
