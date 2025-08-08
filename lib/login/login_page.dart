import 'package:flutter/material.dart';
import '../widgets/telescope_lottie.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
                 children: [
           // Imagen de fondo
           Image.asset(
             'assets/images/start.png',
             fit: BoxFit.cover,
           ),
                                          // Botón de retroceso
                     Positioned(
                       top: 50,
                       left: 20,
                       child: Container(
                         decoration: BoxDecoration(
                           color: Colors.black.withValues(alpha: 0.3),
                           borderRadius: BorderRadius.circular(25),
                         ),
                         child: IconButton(
                           onPressed: () {
                             Navigator.pop(context);
                           },
                           icon: const Icon(
                             Icons.arrow_back_ios,
                             color: Colors.white,
                             size: 28,
                           ),
                         ),
                       ),
                     ),
           // Contenido principal
           SafeArea(
             child: SingleChildScrollView(
               padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                                         const SizedBox(height: 40),
                     // Lottie del telescopio
                     const Center(
                       child: TelescopeLottie(),
                     ),
                     const SizedBox(height: 30),
                     // Título
                     const Text(
                       'Bienvenido',
                       style: TextStyle(
                         color: Colors.white,
                         fontSize: 32,
                         fontWeight: FontWeight.bold,
                         letterSpacing: 1.2,
                       ),
                       textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       'Inicia sesión para continuar',
                       style: TextStyle(
                         color: Colors.white70,
                         fontSize: 16,
                         letterSpacing: 0.5,
                       ),
                       textAlign: TextAlign.center,
                     ),
                                          const SizedBox(height: 40),
                     // Campo de email
                     Container(
                       decoration: BoxDecoration(
                         color: const Color(0xFF2A2A2A),
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 2),
                           ),
                         ],
                       ),
                       child: TextFormField(
                         controller: _emailController,
                         style: const TextStyle(color: Colors.white),
                         keyboardType: TextInputType.emailAddress,
                         decoration: const InputDecoration(
                           hintText: 'Correo electrónico',
                           hintStyle: TextStyle(color: Colors.white),
                           border: InputBorder.none,
                           contentPadding: EdgeInsets.symmetric(
                             horizontal: 16,
                             vertical: 16,
                           ),
                         ),
                         validator: (value) {
                           if (value == null || value.isEmpty) {
                             return 'Por favor ingresa tu correo electrónico';
                           }
                           if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                               .hasMatch(value)) {
                             return 'Por favor ingresa un correo válido';
                           }
                           return null;
                         },
                       ),
                     ),
                     const SizedBox(height: 20),
                     // Campo de nombre de usuario
                     Container(
                       decoration: BoxDecoration(
                         color: const Color(0xFF2A2A2A),
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 2),
                           ),
                         ],
                       ),
                       child: TextFormField(
                         controller: _usernameController,
                         style: const TextStyle(color: Colors.white),
                         decoration: const InputDecoration(
                           hintText: 'Nombre de usuario',
                           hintStyle: TextStyle(color: Colors.white),
                           border: InputBorder.none,
                           contentPadding: EdgeInsets.symmetric(
                             horizontal: 16,
                             vertical: 16,
                           ),
                         ),
                         validator: (value) {
                           if (value == null || value.isEmpty) {
                             return 'Por favor ingresa tu nombre de usuario';
                           }
                           return null;
                         },
                       ),
                     ),
                     const SizedBox(height: 20),
                     // Campo de contraseña
                     Container(
                       decoration: BoxDecoration(
                         color: const Color(0xFF2A2A2A),
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 2),
                           ),
                         ],
                       ),
                       child: TextFormField(
                         controller: _passwordController,
                         style: const TextStyle(color: Colors.white),
                         obscureText: !_isPasswordVisible,
                         decoration: InputDecoration(
                           hintText: 'Contraseña',
                           hintStyle: const TextStyle(color: Colors.white),
                           suffixIcon: IconButton(
                             icon: Icon(
                               _isPasswordVisible
                                   ? Icons.visibility_off
                                   : Icons.visibility,
                               color: Colors.white60,
                             ),
                             onPressed: () {
                               setState(() {
                                 _isPasswordVisible = !_isPasswordVisible;
                               });
                             },
                           ),
                           border: InputBorder.none,
                           contentPadding: const EdgeInsets.symmetric(
                             horizontal: 16,
                             vertical: 16,
                           ),
                         ),
                         validator: (value) {
                           if (value == null || value.isEmpty) {
                             return 'Por favor ingresa tu contraseña';
                           }
                           if (value.length < 6) {
                             return 'La contraseña debe tener al menos 6 caracteres';
                           }
                           return null;
                         },
                       ),
                     ),
                    const SizedBox(height: 30),
                                         // Botón de inicio de sesión
                     Container(
                       decoration: BoxDecoration(
                         color: const Color(0xFF2A2A2A),
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.3),
                             blurRadius: 8,
                             offset: const Offset(0, 2),
                           ),
                         ],
                       ),
                       child: ElevatedButton(
                         onPressed: () {
                           if (_formKey.currentState!.validate()) {
                             // Aquí iría la lógica de autenticación
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                 content: Text('Iniciando sesión...'),
                                 backgroundColor: Colors.green,
                               ),
                             );
                           }
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.transparent,
                           foregroundColor: const Color(0xFF33FFE6),
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(12),
                           ),
                           elevation: 0,
                         ),
                         child: const Text(
                           'Iniciar sesión',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             letterSpacing: 1.0,
                           ),
                         ),
                       ),
                     ),
                                         const SizedBox(height: 20),
                     // Enlace para recuperar contraseña
                     Center(
                       child: TextButton(
                         onPressed: () {
                           // Aquí iría la navegación a recuperar contraseña
                         },
                         child: const Text(
                           '¿Olvidaste tu contraseña?',
                           style: TextStyle(
                             color: Colors.white60,
                             fontSize: 14,
                           ),
                         ),
                       ),
                     ),
                     const SizedBox(height: 40),
                     // Enlace para registrarse
                     Center(
                       child: TextButton(
                         onPressed: () {
                           // Aquí iría la navegación a la página de registro
                         },
                         child: const Text(
                           'Regístrate',
                           style: TextStyle(
                             color: Colors.yellow,
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
