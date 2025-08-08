import 'package:flutter/material.dart';
import '../widgets/telescope_lottie.dart'; // Importa el widget

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/start.png',
            fit: BoxFit.cover,
          ),
          // Lottie en la parte superior
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: const Center(
              child: TelescopeLottie(),
            ),
          ),
          // Botón y texto centrados en la pantalla
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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