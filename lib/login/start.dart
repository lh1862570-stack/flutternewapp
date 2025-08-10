// lib/login/start.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/telescope_lottie.dart';
import '../config/app_router.dart';
import '../services/auth_service.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirección automática si hay sesión activa
    if (AuthService.instance.isLoggedIn) {
      // Usar microtask para evitar navegación durante build sin montar
      Future.microtask(() {
        if (context.mounted) context.go(AppRouter.home);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/start.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: const Center(
              child: TelescopeLottie(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.pushToLogin();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      child: const Text(
                        'Comenzar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Explora el universo desde la palma de tus manos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
