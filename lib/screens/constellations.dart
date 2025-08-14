import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// Usamos la página con overlay completo (incluye imágenes) sobre la cámara
import '../ar/sky_camera_page.dart';

class ConstellationsPage extends StatefulWidget {
  const ConstellationsPage({super.key});

  @override
  State<ConstellationsPage> createState() => _ConstellationsPageState();
}

class _ConstellationsPageState extends State<ConstellationsPage> {
  bool _permissionsGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();
    final bool granted = statuses.values.every((PermissionStatus s) => s.isGranted);
    setState(() {
      _permissionsGranted = granted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_permissionsGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(Icons.lock, color: Colors.white70, size: 48),
              SizedBox(height: 12),
              Text(
                'Se requieren permisos de Cámara y Ubicación',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }
    return const SkyCameraPage();
  }
}