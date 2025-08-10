import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  static const List<String> _paths = <String>[
    '/home',
    '/constellations',
    '/search',
    '/settings',
  ];

  int _pathToIndex(String path) {
    final int matchIndex = _paths.indexWhere((String p) => path.startsWith(p));
    return matchIndex >= 0 ? matchIndex : 0;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _pathToIndex(currentPath);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: child,
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        height: 60,
        color: const Color(0xFF1E1E1E),
        buttonBackgroundColor: const Color(0xFF33FFE6),
        backgroundColor: Colors.transparent,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.home, color: Colors.white),
          Icon(Icons.auto_awesome, color: Colors.white),
          Icon(Icons.search, color: Colors.white),
          Icon(Icons.settings, color: Colors.white),
        ],
        onTap: (int index) {
          context.go(_paths[index]);
        },
      ),
    );
  }
}

