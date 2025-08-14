import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../services/sky_api.dart';
import '../config/backend_config.dart';
import 'constellation_assets.dart';

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
  StreamSubscription<CompassEvent>? _compassSub;

  Position? _position;
  double _yaw = 0; // rotación alrededor del eje Z
  double _pitch = 0; // inclinación vertical (m/s^2 sin normalizar)
  double _roll = 0; // rotación lateral (m/s^2 sin normalizar)
  double _headingDeg = 0; // brújula
  double _headingSmoothedDeg = 0; // brújula suavizada
  double _headingZeroDeg = 0; // calibración de norte relativo
  // Componentes crudos del acelerómetro (incluye gravedad)
  double _ax = 0, _ay = 0, _az = 0;
  // Ángulos calculados desde acelerómetro en grados
  double _pitchDeg = 0, _rollDeg = 0;
  double _pitchSmoothedDeg = 0;
  // Calibración del horizonte (en grados)
  double _pitchZeroDeg = 0;
  // Ajustes manuales
  double _pitchScale = 1.0;
  bool _invertPitch = false;

  List<Map<String, dynamic>> _visibleStars = <Map<String, dynamic>>[];
  bool _showConstellationLines = true;
  bool _showConstellationImages = true;
  bool _fetching = false;
  String? _lastError;

  // Catálogo de constelaciones
  List<_ConstellationConfig>? _dynamicConstellations;
  List<_ConstellationConfig> get _defaultConstellations => const <_ConstellationConfig>[
        _ConstellationConfig(
          name: 'Cassiopeia',
          keyStarNames: <String>[
            'schedar', 'caph', 'ruchbah', 'segin', 'achird', 'gamma cassiopeiae', 'cih', 'navi'
          ],
          assetPath: 'assets/constellations/cassiopeia.png',
        ),
        _ConstellationConfig(
          name: 'Cepheus',
          keyStarNames: <String>['alderamin', 'alfirk', 'alrai', 'errai', 'kurhah'],
          assetPath: 'assets/constellations/cepheus.png',
        ),
        _ConstellationConfig(
          name: 'Draco',
          keyStarNames: <String>['eltanin', 'rastaban', 'altais', 'thuban', 'edasich', 'dziban', 'kuma'],
          assetPath: 'assets/constellations/draco.png',
        ),
        _ConstellationConfig(
          name: 'Ursa Major',
          keyStarNames: <String>['dubhe', 'merak', 'phecda', 'megrez', 'alioth', 'mizar', 'alkaid'],
          assetPath: 'assets/constellations/ursamajor.png',
        ),
        _ConstellationConfig(
          name: 'Ursa Minor',
          keyStarNames: <String>['polaris', 'kochab', 'pherkad'],
          assetPath: 'assets/constellations/ursaminor.png',
        ),
      ];

  // Aproximación del campo de visión de la cámara del dispositivo
  static const double _horizontalFovDeg = 85.0;
  static const double _verticalFovDeg = 65.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSensors();
    _initLocationAndFetch();
    // Cargar constelaciones dinámicas
    _loadDynamicConstellations().then((List<_ConstellationConfig> list) {
      if (!mounted) return;
      final Set<String> known = _defaultConstellations.map((e) => e.assetPath).toSet();
      final List<_ConstellationConfig> merged = <_ConstellationConfig>[..._defaultConstellations];
      for (final _ConstellationConfig c in list) {
        if (!known.contains(c.assetPath)) merged.add(c);
      }
      setState(() => _dynamicConstellations = merged);
    });
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
    _compassSub?.cancel();
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
      // Guardar crudos
      _ax = e.x;
      _ay = e.y;
      _az = e.z;

      // Calcular pitch/roll en radianes (asumiendo orientación vertical/portrait)
      final double pitchRad = math.atan2(-_ax, math.sqrt(_ay * _ay + _az * _az));
      final double rollRad = math.atan2(_ay, _az);
      final double pitchDeg = pitchRad * 180.0 / math.pi;
      final double rollDeg = rollRad * 180.0 / math.pi;

      setState(() {
        _pitchDeg = pitchDeg;
        _rollDeg = rollDeg;
        // Suavizado simple para estabilidad visual
        _pitchSmoothedDeg = 0.9 * _pitchSmoothedDeg + 0.1 * _pitchDeg;
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
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        final double h = event.heading!;
        // Suavizado circular (mantener continuidad 0..360)
        double prev = _headingSmoothedDeg;
        if ((h - prev).abs() > 180) {
          prev += (h > prev) ? 360 : -360;
        }
        final double smoothed = 0.85 * prev + 0.15 * h;
        setState(() {
          _headingDeg = h;
          _headingSmoothedDeg = (smoothed % 360 + 360) % 360;
        });
      }
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

  Future<List<_ConstellationConfig>> _loadDynamicConstellations() async {
    final List<String> paths = await loadConstellationAssetPaths();
    return paths.map((String p) {
      final String fileName = p.split('/').last;
      final String name = fileName.replaceAll('.png', '');
      return _ConstellationConfig(name: name, keyStarNames: <String>[name], assetPath: p);
    }).toList();
  }

  List<_ConstellationPlacement> _computeConstellationPlacements({
    required List<Map<String, dynamic>> stars,
    required List<_ConstellationConfig> configs,
  }) {
    final List<_ConstellationPlacement> placements = <_ConstellationPlacement>[];
    for (final _ConstellationConfig cfg in configs) {
      // Prioridad: anclar centro con frame del backend (si disponible)
      if (_position != null) {
        try {
          // Nota: Para no bloquear UI, podríamos cachear frames; aquí usamos una heurística simple:
          // si ya tenemos matches locales usamos eso; sino, caemos al backend.
          final Map<String, dynamic> frame = <String, dynamic>{};
          // Marcador de lugar: en una versión siguiente lo cachearemos asincrónico
          // y evitaremos llamadas múltiples. Por ahora mantenemos la lógica local.
        } catch (_) {}
      }

      // Fallback: usar estrellas locales visibles que macheen claves
      final List<Map<String, dynamic>> matches = stars.where((Map<String, dynamic> s) {
        final String nameNorm = _normalizeName((s['name'] ?? '') as String);
        final List<dynamic> aliases = (s['aliases'] as List?) ?? const <dynamic>[];
        final String aliasNorm = aliases.map((dynamic a) => _normalizeName(a.toString())).join(' ');
        return cfg.keyStarNames.any((String k) {
          final String key = _normalizeName(k);
          return nameNorm.contains(key) || aliasNorm.contains(key);
        });
      }).toList();

      if (matches.isEmpty) {
        continue;
      }

      double azSum = 0;
      double altSum = 0;
      for (final Map<String, dynamic> m in matches) {
        azSum += ((m['azimuth_deg'] as num?)?.toDouble() ?? 0);
        altSum += ((m['altitude_deg'] as num?)?.toDouble() ?? -90);
      }
      final double centerAz = azSum / matches.length;
      final double centerAlt = altSum / matches.length;
      placements.add(_ConstellationPlacement(
        name: cfg.name,
        assetPath: cfg.assetPath,
        centerAzimuthDeg: centerAz,
        centerAltitudeDeg: centerAlt,
        pixelSize: 180,
      ));
    }
    return placements;
  }

  String _normalizeName(String input) {
    final String lower = input.toLowerCase();
    final String replaced = lower
        .replaceAll('ursa major', 'uma')
        .replaceAll('ursae majoris', 'uma')
        .replaceAll('ursa minor', 'umi')
        .replaceAll('ursae minoris', 'umi')
        .replaceAll('cassiopeiae', 'cas')
        .replaceAll('cephei', 'cep')
        .replaceAll('draconis', 'dra');
    final String collapsed = replaced.replaceAll(RegExp(r"[^a-z0-9]"), '');
    return collapsed;
  }

  Offset _projectToScreen(double azimuthDeg, double altitudeDeg, Size size) {
    final double centerAzDeg = _normalizeDegrees(_headingSmoothedDeg - _headingZeroDeg);
    final double centerAltDeg = _estimateCenterAltitudeDeg();

    final double deltaAz = _wrapDegrees(azimuthDeg - centerAzDeg);
    final double deltaAlt = altitudeDeg - centerAltDeg;

    final double halfHFov = _horizontalFovDeg / 2.0;
    final double halfVFov = _verticalFovDeg / 2.0;
    if (deltaAz.abs() > halfHFov || deltaAlt.abs() > halfVFov) {
      return const Offset(-1000, -1000);
    }

    double xNorm = 0.5 + (deltaAz / _horizontalFovDeg);
    double yNorm = 0.5 - (deltaAlt / _verticalFovDeg);

    // Pequeña corrección por roll usando grados
    xNorm += 0.02 * math.tan(_rollDeg * math.pi / 180.0);

    xNorm = xNorm.clamp(0.0, 1.0);
    yNorm = yNorm.clamp(0.0, 1.0);
    return Offset(xNorm * size.width, yNorm * size.height);
  }

  double _estimateCenterAltitudeDeg() {
    // Usar pitch desde acelerómetro en grados, con calibración
    final double sign = _invertPitch ? -1.0 : 1.0;
    final double deg = sign * (_pitchSmoothedDeg - _pitchZeroDeg) * _pitchScale;
    return deg.clamp(-80.0, 80.0);
  }

  double _normalizeDegrees(double deg) {
    double d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  double _wrapDegrees(double deg) {
    double d = deg % 360.0;
    if (d > 180.0) d -= 360.0;
    if (d < -180.0) d += 360.0;
    return d;
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
              final List<_ConstellationConfig> configs = _dynamicConstellations ?? _defaultConstellations;
              final List<_ConstellationPlacement> placements = _computeConstellationPlacements(
                stars: _visibleStars,
                configs: configs,
              );
              // Depuración: si falta alguna constelación, mostramos su nombre en HUD
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    size: size,
                    painter: _SkyOverlayPainter(
                      stars: _visibleStars,
                      project: (double az, double alt) => _projectToScreen(az, alt, size),
                      showConstellationLines: _showConstellationLines,
                    ),
                  ),
                  if (_showConstellationImages)
                    ...placements.map((p) {
                      final Offset screen = _projectToScreen(p.centerAzimuthDeg, p.centerAltitudeDeg, size);
                      // Si cae fuera del FOV, no dibujar
                      if (screen.dx < 0 || screen.dy < 0 || screen.dx > size.width || screen.dy > size.height) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        left: screen.dx - p.pixelSize / 2,
                        top: screen.dy - p.pixelSize / 2,
                        width: p.pixelSize,
                        height: p.pixelSize,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: p.centerAltitudeDeg >= 0 ? 0.9 : 0.35,
                            child: Image.asset(p.assetPath, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    }),
                ],
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
                    if (_dynamicConstellations != null)
                      Text(
                        'detectadas: '
                        '${_computeConstellationPlacements(stars: _visibleStars, configs: _dynamicConstellations!).map((e) => e.name).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle-images',
                  onPressed: () => setState(() => _showConstellationImages = !_showConstellationImages),
                  child: Icon(_showConstellationImages ? Icons.image_not_supported : Icons.image),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'calibrate-horizon',
                  onPressed: () => setState(() => _pitchZeroDeg = _pitchSmoothedDeg),
                  tooltip: 'Calibrar horizonte',
                  child: const Icon(Icons.tune),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'calibrate-north',
                  onPressed: () => setState(() => _headingZeroDeg = _headingSmoothedDeg),
                  tooltip: 'Calibrar norte',
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'invert-pitch',
                  onPressed: () => setState(() => _invertPitch = !_invertPitch),
                  tooltip: 'Invertir vertical',
                  child: Icon(_invertPitch ? Icons.swap_vert : Icons.swap_vert_circle_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'pitch-scale',
                  onPressed: () => setState(() => _pitchScale = (_pitchScale >= 1.8) ? 0.7 : (_pitchScale + 0.3)),
                  tooltip: 'Sensibilidad vertical',
                  child: const Icon(Icons.stacked_line_chart),
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

class _ConstellationConfig {
  const _ConstellationConfig({
    required this.name,
    required this.keyStarNames,
    required this.assetPath,
  });

  final String name;
  final List<String> keyStarNames;
  final String assetPath;
}

class _ConstellationPlacement {
  const _ConstellationPlacement({
    required this.name,
    required this.assetPath,
    required this.centerAzimuthDeg,
    required this.centerAltitudeDeg,
    required this.pixelSize,
  });

  final String name;
  final String assetPath;
  final double centerAzimuthDeg;
  final double centerAltitudeDeg;
  final double pixelSize;
}


