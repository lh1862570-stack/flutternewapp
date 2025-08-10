import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  final Map<String, _UserRecord> _emailToUser = <String, _UserRecord>{};
  final Map<String, String> _usernameToEmail = <String, String>{};
  String? _currentEmail;

  static const String _kUsersKey = 'auth_users_v1';
  static const String _kCurrentKey = 'auth_current_v1';

  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawUsers = prefs.getString(_kUsersKey);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      final Map<String, dynamic> decoded = jsonDecode(rawUsers) as Map<String, dynamic>;
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        final _UserRecord user = _UserRecord.fromJson(entry.value as Map<String, dynamic>);
        _emailToUser[entry.key] = user;
        _usernameToEmail[user.username.toLowerCase()] = entry.key;
      }
    }
    _currentEmail = prefs.getString(_kCurrentKey);
  }

  bool isEmailRegistered(String emailRaw) {
    final String email = _normalizeEmail(emailRaw);
    return _emailToUser.containsKey(email);
  }

  bool isUsernameTaken(String usernameRaw) {
    final String username = usernameRaw.trim();
    return _usernameToEmail.containsKey(username.toLowerCase());
  }

  Future<void> register({
    required String emailRaw,
    required String usernameRaw,
    required String password,
  }) async {
    final String email = _normalizeEmail(emailRaw);
    final String username = usernameRaw.trim();

    if (isEmailRegistered(email)) {
      throw AuthException('El correo ya está registrado');
    }
    if (isUsernameTaken(username)) {
      throw AuthException('El nombre de usuario ya está en uso');
    }

    _emailToUser[email] = _UserRecord(
      email: email,
      username: username,
      password: password,
    );
    _usernameToEmail[username.toLowerCase()] = email;
    await _persistUsers();
    _currentEmail = email;
    await _persistCurrent();
  }

  Future<void> login({
    required String emailRaw,
    required String password,
  }) async {
    final String email = _normalizeEmail(emailRaw);
    final _UserRecord? user = _emailToUser[email];
    if (user == null) {
      throw AuthException('Correo o contraseña inválidos');
    }
    if (user.password != password) {
      throw AuthException('Correo o contraseña inválidos');
    }
    _currentEmail = email;
    await _persistCurrent();
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> logout() async {
    _currentEmail = null;
    await _persistCurrent();
  }

  bool get isLoggedIn => _currentEmail != null;

  String? get currentUsername =>
      _currentEmail != null ? _emailToUser[_currentEmail!]!.username : null;

  Future<void> _persistUsers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = <String, dynamic>{
      for (final MapEntry<String, _UserRecord> e in _emailToUser.entries)
        e.key: e.value.toJson(),
    };
    await prefs.setString(_kUsersKey, jsonEncode(jsonMap));
  }

  Future<void> _persistCurrent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_currentEmail == null) {
      await prefs.remove(_kCurrentKey);
    } else {
      await prefs.setString(_kCurrentKey, _currentEmail!);
    }
  }
}

class _UserRecord {
  _UserRecord({
    required this.email,
    required this.username,
    required this.password,
  });

  final String email;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'username': username,
        'password': password,
      };

  factory _UserRecord.fromJson(Map<String, dynamic> json) => _UserRecord(
        email: json['email'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      );
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}


