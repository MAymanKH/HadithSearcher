import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
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
      unawaited(vm.refreshFilterCatalogs());
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
    final vm = context.read<SearchViewModel>();
    hideBackToTopButton();
    vm.closeAdvancedSearch();
    vm.setSearchQuery(_textController.text);
    await vm.saveAdvancedPrefs();
    await vm.search(_textController.text);

    if (vm.errorMessage == 'emptySearch' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك ترك خانة البحث فارغة'),
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
        title: const Text(
          'البحث',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
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
            icon: const Icon(Icons.filter_alt, size: 30),
            tooltip: 'البحث المتقدم',
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            _buildSearchBar(screenWidth),
            const SizedBox(height: 10),
            if (vm.activeFilters.isNotEmpty) _buildActiveFilters(vm),
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
              textInputAction: TextInputAction.search,
              controller: _textController,
              decoration: const InputDecoration(hintText: 'تحقق من حديث...'),
              style: const TextStyle(fontSize: 16),
              onChanged: context.read<SearchViewModel>().setSearchQuery,
              onSubmitted: (_) => _onSearch(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 30),
            label: const Text('بحث'),
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
            const Text(
              'البحث المتقدم',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildDropdownRow(
              'طريقة البحث',
              vm.searchWay.arabicName,
              SearchWay.values.map((e) => e.arabicName).toList(),
              (value) => vm.setSearchWay(SearchWay.fromArabic(value!)),
            ),
            _buildDropdownRow(
              'نطاق البحث',
              vm.searchRange.arabicName,
              SearchRange.values.map((e) => e.arabicName).toList(),
              (value) => vm.setSearchRange(SearchRange.fromArabic(value!)),
            ),
            _buildDropdownRow(
              'درجة الحديث',
              vm.searchGrade.arabicName,
              SearchGrade.values.map((e) => e.arabicName).toList(),
              (value) => vm.setSearchGrade(SearchGrade.fromArabic(value!)),
            ),
            _buildCatalogField(
              'المحدث',
              vm.searchMohdith,
              vm.scholars,
              vm.setSearchMohdith,
            ),
            _buildCatalogField(
              'الكتاب',
              vm.searchBook,
              vm.books,
              vm.setSearchBook,
            ),
            _buildExcludedWordsField(vm),
            _buildSaveCheckbox(vm),
            TextButton(
              onPressed: () => _clearFilters(vm),
              child: const Text('مسح الفلاتر'),
            ),
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
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        TextButton(
          onPressed: () => _clearFilters(vm),
          child: const Text('مسح الفلاتر'),
        ),
        ...vm.activeFilters.map(
          (label) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Chip(label: Text(label)),
          ),
        ),
      ],
    ),
  );

  Widget _buildCatalogField(
    String label,
    SearchOption selected,
    List<SearchOption> options,
    void Function(SearchOption) onChanged,
  ) => Padding(
    padding: const EdgeInsets.all(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () async {
        final value = await showSearchOptionPicker(
          context,
          title: label,
          options: options,
          selected: selected,
        );
        if (mounted && value != null) onChanged(value);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(
          selected.arabicName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );

  Widget _buildDropdownRow(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
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
        decoration: const InputDecoration(
          labelText: 'كلمات مستثناة',
          hintText: 'كلمات أو جملة تريد استبعادها',
        ),
        onChanged: vm.setExcludedWords,
      ),
    );
  }

  Widget _buildSaveCheckbox(SearchViewModel vm) {
    return CheckboxListTile(
      value: vm.saveAdvancedSettings,
      title: const Text('حفظ إعدادات البحث المتقدم'),
      onChanged: (value) => vm.setSaveAdvancedSettings(value ?? true),
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
        title = 'لا توجد نتائج';
        description = 'جرب استخدام كلمات أو إعدادات أخرى';
      } else if (vm.errorMessage!.contains('خطأ بالإتصال')) {
        icon = Icons.wifi_off;
        title = 'خطأ بالإتصال بالإنترنت';
        description = 'تأكد من إتصالك بالإنترنت وأعد المحاولة';
      } else if (vm.errorMessage!.contains('نفذ الوقت')) {
        icon = Icons.timer_off;
        title = 'نفذ الوقت';
        description = 'تأكد من إتصالك بإنترنت مستقر وأعد المحاولة';
      } else {
        icon = Icons.error_outline;
        title = vm.errorMessage!;
        description = 'حاول مرة أخرى';
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
                  label: const Text('أعد المحاولة'),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.search, size: 100, color: Colors.grey),
            const Text(
              'ابحث عن حديث',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            if (vm.recentSearches.isNotEmpty) ...[
              const SizedBox(height: 30),
              Row(
                children: [
                  const Expanded(child: Text('عمليات البحث الأخيرة')),
                  TextButton(
                    onPressed: vm.clearRecentSearches,
                    child: const Text('مسح السجل'),
                  ),
                ],
              ),
              ...vm.recentSearches.map(
                (query) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    query,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    _textController.text = query;
                    _onSearch();
                  },
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                  hadith: hadith,
                  isFavourite: vm.isFavourite(hadith.id),
                  onFavouriteToggle: () async {
                    final error = await vm.toggleFavourite(hadith);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
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
