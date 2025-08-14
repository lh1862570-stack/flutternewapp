import 'package:flutter/foundation.dart';

enum BackendMode {
  localEmulator, // Android Emulator: http://10.0.2.2:8000
  localPhysical, // Dispositivo físico en la misma red: http://TU_IP_LOCAL_PC:8000
  remote,        // Backend público (https)
}

class BackendConfig {
  BackendConfig._();

  // Elige el modo según tu entorno actual
  static const BackendMode mode = BackendMode.localPhysical;

  // Configs locales
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000';
  // Sustituye por la IP local de tu PC (ipconfig) y mismo puerto que usa uvicorn/fastapi
  static const String physicalDeviceBaseUrl = 'http://10.0.0.55:8000';

  // Backend público (si ya lo tienes desplegado)
  static const String remoteBaseUrl = 'https://tu-servicio.onrender.com';

  static String get backendBaseUrl {
    switch (mode) {
      case BackendMode.localEmulator:
        // En web/escritorio usar localhost
        if (kIsWeb) return 'http://127.0.0.1:8000';
        return emulatorBaseUrl;
      case BackendMode.localPhysical:
        return physicalDeviceBaseUrl;
      case BackendMode.remote:
        return remoteBaseUrl;
    }
  }
}


