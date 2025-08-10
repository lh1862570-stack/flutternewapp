// lib/config/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tecoapp2025/login/registrate.dart';
import 'package:tecoapp2025/screens/home.dart';
import 'package:tecoapp2025/screens/constellations.dart';
import 'package:tecoapp2025/screens/search.dart';
import 'package:tecoapp2025/screens/settings.dart';
import 'package:tecoapp2025/screens/main_shell.dart';
import '../login/start.dart';
import '../login/login_page.dart';

class AppRouter {
  static const String start = '/';
  static const String login = '/login';
  static const String home = '/home';

  static final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: start,
        name: 'start',
        builder: (BuildContext context, GoRouterState state) {
          return const StartPage();
        },
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return MainShell(child: child, currentPath: state.uri.toString());
        },
        routes: [
          GoRoute(
            path: home,
            name: 'home',
            builder: (BuildContext context, GoRouterState state) {
              return const HomePage();
            },
          ),
          GoRoute(
            path: '/constellations',
            name: 'constellations',
            builder: (BuildContext context, GoRouterState state) {
              return const ConstellationsPage();
            },
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (BuildContext context, GoRouterState state) {
              return const SearchPage();
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (BuildContext context, GoRouterState state) {
              return const SettingsPage();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/registrate',
        builder: (context, state) => const RegistratePage(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(
        child: Text(
          'Página no encontrada',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
      backgroundColor: Colors.black,
    ),
    initialLocation: start,
  );
}

extension AppRouterExtension on BuildContext {
  void goToStart() => go(AppRouter.start);
  void goToLogin() => go(AppRouter.login);
  void goToHome() => go(AppRouter.home);
  void pushToLogin() => push(AppRouter.login);
}
