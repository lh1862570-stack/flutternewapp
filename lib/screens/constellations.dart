import 'package:flutter/material.dart';

class ConstellationsPage extends StatelessWidget {
  const ConstellationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/constellations.png',
              fit: BoxFit.cover,
            ),
            const Center(
              child: Text(
                'Constelaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}