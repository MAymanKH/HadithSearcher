import 'package:flutter/material.dart';
import 'package:hadithsearcher/core/theme/app_theme.dart';
import 'package:hadithsearcher/l10n/localization.dart';
import 'package:hadithsearcher/models/settings.dart';
import 'package:hadithsearcher/widgets/app_dropdown.dart';
import 'package:hadithsearcher/widgets/app_input_button.dart';
import 'package:hadithsearcher/widgets/app_selection_tile.dart';
import 'package:hadithsearcher/widgets/selection_sheet.dart';

void main() => runApp(const DropdownLab());

enum PickerStyle { current, outlined, soft, compact }

class DropdownLab extends StatefulWidget {
  const DropdownLab({super.key});

  @override
  State<DropdownLab> createState() => _DropdownLabState();
}

class _DropdownLabState extends State<DropdownLab> {
  PickerStyle style = PickerStyle.outlined;
  bool dark = false;
  bool arabic = true;
  ColorSchemePreference palette = ColorSchemePreference.classic;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(palette, dark ? Brightness.dark : Brightness.light),
    locale: Locale(arabic ? 'ar' : 'en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Dropdown lab'),
        actions: [
          IconButton(
            tooltip: 'Switch language',
            onPressed: () => setState(() => arabic = !arabic),
            icon: const Icon(Icons.translate_rounded),
          ),
          IconButton(
            tooltip: 'Switch brightness',
            onPressed: () => setState(() => dark = !dark),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final option in PickerStyle.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(option.name),
                      selected: style == option,
                      onSelected: (_) => setState(() => style = option),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final option in [
                  ColorSchemePreference.classic,
                  ColorSchemePreference.forest,
                  ColorSchemePreference.sepia,
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(option.name),
                      selected: palette == option,
                      onSelected: (_) => setState(() => palette = option),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PickerScene(
              key: ValueKey(style),
              style: style,
              arabic: arabic,
            ),
          ),
        ],
      ),
    ),
  );
}

class PickerScene extends StatefulWidget {
  final PickerStyle style;
  final bool arabic;

  const PickerScene({super.key, required this.style, required this.arabic});

  @override
  State<PickerScene> createState() => _PickerSceneState();
}

class _PickerSceneState extends State<PickerScene> {
  int mode = 0;
  Set<int> books = {0, 1};
  String t(String ar, String en) => widget.arabic ? ar : en;
  List<String> get modes => [
    t('كل الكلمات', 'All words'),
    t('أي كلمة', 'Any word'),
    t('عبارة مطابقة', 'Exact phrase'),
  ];
  List<String> get titles => [
    t('صحيح البخاري', 'Sahih al-Bukhari'),
    t('صحيح مسلم', 'Sahih Muslim'),
    t('سنن أبي داود', 'Sunan Abi Dawud'),
    t('جامع الترمذي', 'Jami al-Tirmidhi'),
    t('سنن النسائي', 'Sunan al-Nasai'),
    t('سنن ابن ماجه', 'Sunan Ibn Majah'),
  ];

  Future<void> open(bool multiple) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: widget.style == PickerStyle.compact
          ? Colors.transparent
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.style == PickerStyle.outlined ? 16 : 28),
        ),
      ),
      showDragHandle: widget.style == PickerStyle.current,
      builder: (_) => _ChoiceSheet(
        style: widget.style,
        title: multiple ? t('الكتب', 'Books') : t('طريقة البحث', 'Search mode'),
        options: multiple ? titles : modes,
        selected: multiple ? books : {mode},
        multiple: multiple,
        arabic: widget.arabic,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (multiple) {
        books = result;
      } else {
        mode = result.single;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('البحث', 'Search')),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
            label: Text(t('بحث متقدم', 'Advanced')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: AppTheme.searchInputDecoration(context).copyWith(
              hintText: t('ابحث في الأحاديث', 'Search hadith'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('خيارات البحث', 'Search options'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (widget.style == PickerStyle.current)
            AppDropdown<int>(
              key: const Key('mode-field'),
              title: t('طريقة البحث', 'Search mode'),
              value: mode,
              decoration: InputDecoration(
                labelText: t('طريقة البحث', 'Search mode'),
              ),
              items: [
                for (var i = 0; i < modes.length; i++)
                  DropdownMenuItem(value: i, child: Text(modes[i])),
              ],
              onChanged: (value) => setState(() => mode = value!),
            )
          else
            _Field(
              key: const Key('mode-field'),
              style: widget.style,
              label: t('طريقة البحث', 'Search mode'),
              value: modes[mode],
              icon: Icons.manage_search_rounded,
              onTap: () => open(false),
            ),
          const SizedBox(height: 12),
          if (widget.style == PickerStyle.current)
            AppInputButton(
              key: const Key('books-field'),
              decoration: InputDecoration(
                labelText: t('الكتب', 'Books'),
                suffixIcon: const Icon(Icons.expand_more_rounded),
              ),
              onTap: () => open(true),
              child: Text(
                t(
                  '${books.length} كتب محددة',
                  '${books.length} books selected',
                ),
              ),
            )
          else
            _Field(
              key: const Key('books-field'),
              style: widget.style,
              label: t('الكتب', 'Books'),
              value: books.isEmpty
                  ? t('لا توجد كتب محددة', 'No books selected')
                  : books.map((i) => titles[i]).join('، '),
              icon: Icons.menu_book_rounded,
              onTap: () => open(true),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
            label: Text(t('بحث', 'Search')),
          ),
          const SizedBox(height: 32),
          Center(
            child: Icon(
              Icons.menu_book_outlined,
              size: 36,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'ابحث بكلمة أو عبارة من الحديث',
              'Search with a word or phrase from a hadith',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            label: t('البحث', 'Search'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border_rounded),
            label: t('المفضلة', 'Favourites'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: t('الإعدادات', 'Settings'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final PickerStyle style;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _Field({
    super.key,
    required this.style,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = style == PickerStyle.compact;
    final outlined = style == PickerStyle.outlined;
    final radius = BorderRadius.circular(outlined ? 12 : 20);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: outlined || compact
            ? colors.surface
            : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: outlined
              ? BorderSide(color: colors.outlineVariant)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 16,
              vertical: 12,
            ),
            decoration: compact
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.outlineVariant),
                    ),
                  )
                : null,
            child: Row(
              children: [
                if (!outlined) ...[
                  Icon(icon, size: 22, color: colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  compact
                      ? Icons.unfold_more_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceSheet extends StatefulWidget {
  final PickerStyle style;
  final String title;
  final List<String> options;
  final Set<int> selected;
  final bool multiple;
  final bool arabic;

  const _ChoiceSheet({
    required this.style,
    required this.title,
    required this.options,
    required this.selected,
    required this.multiple,
    required this.arabic,
  });

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  late final selected = {...widget.selected};
  String query = '';
  String t(String ar, String en) => widget.arabic ? ar : en;

  void toggle(int i) {
    if (!widget.multiple) {
      Navigator.pop(context, {i});
      return;
    }
    setState(() => selected.contains(i) ? selected.remove(i) : selected.add(i));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final soft = widget.style == PickerStyle.soft;
    final compact = widget.style == PickerStyle.compact;
    final current = widget.style == PickerStyle.current;
    final visible = [
      for (var i = 0; i < widget.options.length; i++)
        if (widget.options[i].toLowerCase().contains(query.toLowerCase())) i,
    ];
    final search = widget.multiple
        ? TextField(
            key: const Key('sheet-search'),
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: t('ابحث باسم الكتاب', 'Search by book name'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: !compact,
              border: compact ? const UnderlineInputBorder() : null,
              enabledBorder: compact
                  ? UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.outlineVariant),
                    )
                  : null,
            ),
          )
        : null;
    final list = ListView(
      shrinkWrap: true,
      padding: EdgeInsets.all(soft ? 8 : 0),
      children: [
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t('لا توجد نتائج', 'No books found'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final i in visible)
          if (current)
            AppSelectionTile(
              title: Text(widget.options[i]),
              selected: selected.contains(i),
              multiple: widget.multiple,
              onTap: () => toggle(i),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: soft ? 6 : 0),
              child: Material(
                color: soft && selected.contains(i)
                    ? colors.primaryContainer
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: soft && selected.contains(i)
                      ? BorderSide(color: colors.primary)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => toggle(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Semantics(
                    selected: selected.contains(i),
                    button: true,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 58),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: !soft && i != visible.last
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: colors.outlineVariant.withValues(
                                    alpha: .4,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      child: Row(
                        children: [
                          if (compact) ...[
                            _Indicator(
                              selected: selected.contains(i),
                              multiple: widget.multiple,
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Text(
                              widget.options[i],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: selected.contains(i)
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 12),
                            soft || widget.multiple
                                ? _Indicator(
                                    selected: selected.contains(i),
                                    multiple: widget.multiple,
                                  )
                                : SizedBox(
                                    width: 24,
                                    child: selected.contains(i)
                                        ? const Icon(Icons.check_rounded)
                                        : null,
                                  ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
    if (current) {
      return SelectionSheet(title: widget.title, search: search, child: list);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 0,
        0,
        compact ? 12 : 0,
        MediaQuery.viewInsetsOf(context).bottom + (compact ? 12 : 0),
      ),
      child: Material(
        color: soft ? colors.surfaceContainerHigh : colors.surface,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(28),
          bottom: Radius.circular(compact ? 28 : 0),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom) *
                  .82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: t('إغلاق', 'Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (search != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: search,
                  ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: soft ? 12 : 4),
                    child: Material(
                      color: soft ? colors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: list,
                    ),
                  ),
                ),
                if (widget.multiple)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t(
                              '${selected.length} محددة',
                              '${selected.length} selected',
                            ),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child: Text(t('تطبيق', 'Apply')),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final bool selected;
  final bool multiple;
  const _Indicator({required this.selected, required this.multiple});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? colors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? colors.primary : colors.outline,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(multiple ? 6 : 11),
      ),
      child: selected
          ? Icon(
              multiple ? Icons.check_rounded : Icons.circle,
              size: multiple ? 16 : 8,
              color: colors.onPrimary,
            )
          : null,
    );
  }
}
