import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class TelescopeLottie extends StatelessWidget {
  const TelescopeLottie({super.key});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/lottie/telescope.json',
      width: 250,
      height: 250,
      fit: BoxFit.contain,
      repeat: true,
      animate: true,
    );
  }
}