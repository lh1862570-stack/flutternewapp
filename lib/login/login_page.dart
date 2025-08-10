// lib/login/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/telescope_lottie.dart';
import '../utils/validators.dart';
import '../services/auth_service.dart';

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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06, // 6% del ancho
                vertical: screenHeight * 0.02,  // 2% de la altura
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                                        
                     Center(
                       child: SizedBox(
                         width: screenWidth * 0.6,  // 60% del ancho de pantalla
                         height: screenWidth * 0.6, // Mantener proporción cuadrada
                         child: const TelescopeLottie(),
                       ),
                     ),

                     _buildTextField(
                       controller: _emailController,
                       hintText: 'Correo electrónico',
                       keyboardType: TextInputType.emailAddress,
                       validator: Validators.validateEmail,
                     ),
                     SizedBox(height: screenHeight * 0.025),
                     _buildTextField(
                       controller: _usernameController,
                       hintText: 'Nombre de usuario',
                       validator: (value) {
                         return null; // opcional en login
                       },
                     ),
                     SizedBox(height: screenHeight * 0.025),
                     _buildTextField(
                       controller: _passwordController,
                       hintText: 'Contraseña',
                       obscureText: !_isPasswordVisible,
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
                       validator: Validators.validateLoginPassword,
                     ),
                     SizedBox(height: screenHeight * 0.01),
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
                           onPressed: () async {
                             if (_formKey.currentState!.validate()) {
                               try {
                                 await AuthService.instance.login(
                                   emailRaw: _emailController.text,
                                   password: _passwordController.text,
                                 );
                                 if (!context.mounted) return;
                                 context.go('/home');
                               } on AuthException catch (e) {
                                 if (!context.mounted) return;
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text(e.message)),
                                 );
                               }
                             }
                           },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.transparent,
                           foregroundColor: const Color(0xFF33FFE6),
                           padding: EdgeInsets.symmetric(
                             vertical: screenHeight * 0.02, // 2% de la altura
                           ),
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(12),
                           ),
                           elevation: 0,
                         ),
                         child: Text(
                           'Iniciar sesión',
                           style: TextStyle(
                             fontSize: screenWidth * 0.045, // 4.5% del ancho
                             fontWeight: FontWeight.bold,
                             letterSpacing: 1.0,
                           ),
                         ),
                       ),
                     ),
                     SizedBox(height: screenHeight * 0.005),
                                         Center(
                       child: TextButton(
                         onPressed: () {},
                         child: Text(
                           '¿Olvidaste tu contraseña?',
                           style: TextStyle(
                             color: Colors.white60,
                             fontSize: screenWidth * 0.035, // 3.5% del ancho
                           ),
                         ),
                       ),
                     ),
                     SizedBox(height: screenHeight * 0.005),
                     Center(
                       child: TextButton(
                         onPressed: () {
                           context.push('/registrate'); // Ajusta la ruta según tu configuración
                         },
                         child: Text(
                           'Regístrate',
                           style: TextStyle(
                             color: Colors.yellow,
                             fontSize: screenWidth * 0.070, // 7% del ancho
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                     ),
                     SizedBox(height: screenHeight * 0.01),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

     Widget _buildTextField({
     required TextEditingController controller,
     required String hintText,
     TextInputType? keyboardType,
     bool obscureText = false,
     Widget? suffixIcon,
     String? Function(String?)? validator,
   }) {
     final screenWidth = MediaQuery.of(context).size.width;
     final screenHeight = MediaQuery.of(context).size.height;
     
     return Container(
       decoration: BoxDecoration(
         color: Colors.white.withValues(alpha: 0.15),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: Colors.white.withValues(alpha: 0.2),
           width: 1,
         ),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.2),
             blurRadius: 8,
             offset: const Offset(0, 2),
           ),
         ],
       ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          color: Colors.white,
          fontSize: screenWidth * 0.04, // 4% del ancho de pantalla
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.04, // 4% del ancho de pantalla
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,  // 4% del ancho
            vertical: screenHeight * 0.02,   // 2% de la altura
          ),
        ),
        validator: validator,
      ),
    );
  }
}
