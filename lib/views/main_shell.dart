import 'package:flutter/material.dart';
import '../l10n/localization.dart';
import '../services/telemetry/telemetry_service.dart';
import '../services/shared_text_service.dart';
import 'about/about_view.dart';
import 'favourites/favourites_view.dart';
import 'search/search_view.dart';
import 'settings/settings_view.dart';

/// Main shell widget with bottom navigation bar.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  String? _sharedText;
  int _shareRevision = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _trackScreen(_currentIndex);
    SharedTextService.instance.addListener(_acceptSharedText);
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptSharedText());
  }

  void _acceptSharedText() {
    if (!mounted) return;
    final text = SharedTextService.instance.takePendingText();
    if (text == null) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _sharedText = text;
      _shareRevision = SharedTextService.instance.revision;
      _currentIndex = 0;
    });
    _trackScreen(0);
  }

  @override
  void dispose() {
    SharedTextService.instance.removeListener(_acceptSharedText);
    super.dispose();
  }

  void _trackScreen(int index) {
    TelemetryService.event('screen_viewed', {
      'screen': ['search', 'favourites', 'settings', 'about'][index],
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SearchView(sharedText: _sharedText, shareRevision: _shareRevision),
      const FavouritesView(),
      const SettingsView(),
      const AboutView(),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == _currentIndex) return;
          _trackScreen(index);
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: context.l10n.search,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: context.l10n.favourites,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: context.l10n.settings,
          ),
          NavigationDestination(
            tooltip: '',
            icon: const Icon(Icons.info_outline),
            selectedIcon: const Icon(Icons.info),
            label: context.l10n.about,
          ),
        ],
      ),
    );
  }
}
