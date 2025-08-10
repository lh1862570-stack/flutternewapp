class Validators {
  static final RegExp _emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
  static final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp _upperCase = RegExp(r'[A-Z]');
  static final RegExp _lowerCase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    final String email = value.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      return 'Por favor ingresa un correo válido';
    }
    return null;
  }

  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  static String? validateRegisterPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!_upperCase.hasMatch(value)) {
      return 'La contraseña debe incluir al menos una mayúscula';
    }
    if (!_lowerCase.hasMatch(value)) {
      return 'La contraseña debe incluir al menos una minúscula';
    }
    if (!_digit.hasMatch(value)) {
      return 'La contraseña debe incluir al menos un número';
    }
    if (!_symbol.hasMatch(value)) {
      return 'La contraseña debe incluir al menos un símbolo';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa tu nombre de usuario';
    }
    final String username = value.trim();
    if (username.length < 3) {
      return 'El nombre de usuario debe tener al menos 3 caracteres';
    }
    if (!_usernameRegex.hasMatch(username)) {
      return 'Solo se permiten letras, números y guion bajo (_).';
    }
    return null;
  }
}


