import 'package:flutter/material.dart';
import '../services/telemetry/telemetry_service.dart';
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

  final List<Widget> _pages = const [
    SearchView(),
    FavouritesView(),
    SettingsView(),
    AboutView(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _trackScreen(_currentIndex);
  }

  void _trackScreen(int index) {
    TelemetryService.event('screen_viewed', {
      'screen': ['search', 'favourites', 'settings', 'about'][index],
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
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
            icon: const Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: activeColor),
            label: 'البحث',
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star, color: activeColor),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: activeColor),
            label: 'الإعدادات',
          ),
          NavigationDestination(
            icon: const Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info, color: activeColor),
            label: 'حول',
          ),
        ],
      ),
    );
  }
}
