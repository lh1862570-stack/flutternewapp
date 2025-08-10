// lib/config/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tecoapp2025/login/registrate.dart';
import 'package:tecoapp2025/screens/home.dart';
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
      GoRoute(
        path: home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomePage();
        },
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
