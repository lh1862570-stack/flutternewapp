import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/sky_api.dart';
import '../config/backend_config.dart';

class SkyCameraPage extends StatefulWidget {
  const SkyCameraPage({super.key});

  @override
  State<SkyCameraPage> createState() => _SkyCameraPageState();
}

class _SkyCameraPageState extends State<SkyCameraPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  final SkyApiClient _api = SkyApiClient(baseUrl: BackendConfig.backendBaseUrl);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  Position? _position;
  double _yaw = 0; // rotación alrededor del eje Z
  double _pitch = 0; // X
  double _roll = 0; // Y

  List<Map<String, dynamic>> _visibleStars = <Map<String, dynamic>>[];
  bool _showConstellationLines = true;
  bool _fetching = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
    _initLocationAndFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Asegura liberar y limpiar referencias
    final CameraController? controller = _cameraController;
    _cameraController = null;
    _initializeControllerFuture = null;
    controller?.dispose();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Liberar cámara y limpiar futuros para evitar buildPreview sobre un controller disposed
      final CameraController? controller = _cameraController;
      _cameraController = null;
      _initializeControllerFuture = null;
      controller?.dispose();
      setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (!mounted) return;
      final CameraDescription back = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      setState(() {
        _cameraController = controller;
        _initializeControllerFuture = controller.initialize();
      });
      await _initializeControllerFuture;
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _initLocationAndFetch() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _position = pos);
      await _fetchStars();
    } catch (_) {}
  }

  void _initSensors() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      setState(() {
        _pitch = e.x; // aproximado para demo
        _roll = e.y;
      });
    });
    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent e) {
      setState(() {
        _yaw += e.z * 0.02; // integración simple (demo)
      });
    });
    _magSub = magnetometerEvents.listen((MagnetometerEvent e) {
      // En una implementación completa, usar fusión de sensores (AHRS/kalman)
    });
  }

  Future<void> _fetchStars() async {
    if (_position == null || _fetching) return;
    setState(() => _fetching = true);
    try {
      final List<Map<String, dynamic>> stars = await _api.fetchVisibleStars(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        limit: 100,
        maxMag: 6.0,
      );
      setState(() {
        _visibleStars = stars;
        _lastError = null;
      });
    } catch (e) {
      setState(() => _lastError = e.toString());
    } finally {
      setState(() => _fetching = false);
    }
  }

  Offset _projectToScreen(double azimuthDeg, double altitudeDeg, Size size) {
    // Proyección simplificada para demo: mapear azimut ~ yaw y altitud ~ pitch/roll
    double normalizedAz = ((azimuthDeg / 360.0) + 0.5 * math.sin(_yaw)) % 1.0;
    // Ajuste leve por roll (g ~ 9.8)
    normalizedAz = (normalizedAz + 0.02 * math.atan(_roll / 9.8)) % 1.0;

    double normalizedAlt = (altitudeDeg + 90) / 180.0; // -90..+90 -> 0..1
    // Ajuste leve por pitch
    normalizedAlt = (normalizedAlt - 0.05 * math.atan(_pitch / 9.8)).clamp(0.0, 1.0);

    final double x = normalizedAz * size.width;
    final double y = (1 - normalizedAlt) * size.height;
    return Offset(x, y);
    // Nota: Esto es un placeholder. Luego sustituiremos por proyección real usando matrices y FOV.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_cameraController != null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                if (_cameraController != null && _cameraController!.value.isInitialized) {
                  return CameraPreview(_cameraController!);
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const SizedBox.shrink();
              },
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Overlay de estrellas
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = Size(constraints.maxWidth, constraints.maxHeight);
              return CustomPaint(
                size: size,
                painter: _SkyOverlayPainter(
                  stars: _visibleStars,
                  project: (double az, double alt) => _projectToScreen(az, alt, size),
                  showConstellationLines: _showConstellationLines,
                ),
              );
            },
          ),

          // HUD de depuración
          Positioned(
            left: 12,
            top: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('lat: ${_position?.latitude.toStringAsFixed(5) ?? '-'}'),
                    Text('lon: ${_position?.longitude.toStringAsFixed(5) ?? '-'}'),
                    Text('estrellas: ${_visibleStars.length}${_fetching ? ' (cargando...)' : ''}'),
                    if (_lastError != null)
                      Text('err: ${_lastError!.length > 40 ? _lastError!.substring(0, 40) + '…' : _lastError!}',
                          style: const TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ),
          ),

          // Botonera
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              children: <Widget>[
                FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _fetchStars,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle-lines',
                  onPressed: () => setState(() => _showConstellationLines = !_showConstellationLines),
                  child: Icon(_showConstellationLines ? Icons.grid_off : Icons.grid_on),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyOverlayPainter extends CustomPainter {
  _SkyOverlayPainter({
    required this.stars,
    required this.project,
    required this.showConstellationLines,
  });

  final List<Map<String, dynamic>> stars;
  final Offset Function(double azimuthDeg, double altitudeDeg) project;
  final bool showConstellationLines;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final Map<String, dynamic> star in stars) {
      final double az = (star['azimuth_deg'] as num?)?.toDouble() ?? 0;
      final double alt = (star['altitude_deg'] as num?)?.toDouble() ?? -90;
      final double mag = (star['magnitude'] as num?)?.toDouble() ?? 6;

      if (alt < 0) continue; // solo sobre el horizonte, por ahora

      final Offset p = project(az, alt);
      final double radius = math.max(1.0, 4.0 - (mag - 0.5));
      canvas.drawCircle(p, radius, starPaint);
    }

    if (showConstellationLines) {
      // Placeholder: líneas simples. Luego se sustituye por grafos reales por constelación
      final Paint linePaint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.35)
        ..strokeWidth = 1.0;
      for (int i = 1; i < stars.length; i++) {
        final Map<String, dynamic> a = stars[i - 1];
        final Map<String, dynamic> b = stars[i];
        final double azA = (a['azimuth_deg'] as num?)?.toDouble() ?? 0;
        final double altA = (a['altitude_deg'] as num?)?.toDouble() ?? -90;
        final double azB = (b['azimuth_deg'] as num?)?.toDouble() ?? 0;
        final double altB = (b['altitude_deg'] as num?)?.toDouble() ?? -90;
        if (altA < 0 || altB < 0) continue;
        final Offset p1 = project(azA, altA);
        final Offset p2 = project(azB, altB);
        canvas.drawLine(p1, p2, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkyOverlayPainter oldDelegate) {
    return oldDelegate.stars != stars ||
        oldDelegate.showConstellationLines != showConstellationLines;
  }
}


