import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../services/sky_api.dart';
import '../config/backend_config.dart';
import 'constellation_assets.dart';

class SkyARPage extends StatefulWidget {
  const SkyARPage({super.key});

  @override
  State<SkyARPage> createState() => _SkyARPageState();
}

class _SkyARPageState extends State<SkyARPage> {
  // dynamic _arSessionManager;
  // dynamic _arObjectManager;

  final SkyApiClient _api = SkyApiClient(baseUrl: BackendConfig.backendBaseUrl);
  Position? _position;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<CompassEvent>? _compassSub;

  double _yaw = 0;
  double _pitch = 0;
  double _roll = 0;
  double _headingDeg = 0;
  // Reservado para futuros filtros (Kalman/Complementario)
  // double _accelX = 0;
  // double _accelY = 0;
  // double _accelZ = 0;

  static const double _horizontalFovDeg = 85.0; // Ajuste inicial recomendado
  static const double _verticalFovDeg = 65.0;   // Ajuste inicial recomendado
  static const double _pitchToAltScale = 30.0;

  List<Map<String, dynamic>> _visibleStars = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _visibleBodies = <Map<String, dynamic>>[];
  bool _showConstellationLines = true;
  bool _showConstellationImages = true;
  bool _showMilkyWay = true;
  bool _fetching = false;

  // Estado de backend AR (IAU)
  Timer? _pollTimer;
  Size? _lastLayoutSize;
  String? _activeConstellationName; // de /iau-in-fov
  List<Map<String, dynamic>> _constellationsScreen = <Map<String, dynamic>>[]; // de /constellations-screen
  Set<String> _availableAssets = <String>{};

  List<_ConstellationConfig> get _defaultConstellations => const <_ConstellationConfig>[
        _ConstellationConfig(name: 'Cassiopeia', keyStarNames: <String>['Caph', 'Schedar', 'Cih'], assetPath: 'assets/constellations/cassiopeia.png'),
        _ConstellationConfig(name: 'Cepheus', keyStarNames: <String>['Alderamin'], assetPath: 'assets/constellations/cepheus.png'),
        _ConstellationConfig(name: 'Draco', keyStarNames: <String>['Eltanin'], assetPath: 'assets/constellations/draco.png'),
        _ConstellationConfig(name: 'Ursa Major', keyStarNames: <String>['Dubhe', 'Merak'], assetPath: 'assets/constellations/ursamajor.png'),
        _ConstellationConfig(name: 'Ursa Minor', keyStarNames: <String>['Polaris'], assetPath: 'assets/constellations/ursaminor.png'),
      ];

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
      final List<Map<String, dynamic>> matches = stars.where((Map<String, dynamic> s) {
        final String? name = (s['name'] as String?);
        if (name == null) return false;
        return cfg.keyStarNames.any((String k) => name.toLowerCase().contains(k.toLowerCase()));
      }).toList();
      if (matches.isEmpty) continue;
      // Centro simple por promedio de azimut/altitud de estrellas clave encontradas
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
        pixelSize: 160,
      ));
    }
    return placements;
  }

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
    _initSensors();
    // Precargar listado dinámico por si agregas más imágenes en assets/constellations
    _loadDynamicConstellations().then((List<_ConstellationConfig> dynamicList) {
      if (!mounted) return;
      setState(() {
        // Fusionar respetando los 5 por defecto primero
        final Set<String> known = _defaultConstellations.map((e) => e.assetPath).toSet();
        final List<_ConstellationConfig> merged = <_ConstellationConfig>[..._defaultConstellations];
        for (final _ConstellationConfig c in dynamicList) {
          if (!known.contains(c.assetPath)) {
            merged.add(c);
          }
        }
        _dynamicConstellations = merged;
        _availableAssets = dynamicList.map((e) => e.assetPath).toSet();
      });
    });

    _startPollingBackendAr();
  }

  List<_ConstellationConfig>? _dynamicConstellations;

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _compassSub?.cancel();
    _pollTimer?.cancel();
    // _arSessionManager?.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndFetch() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _position = pos);
      await _fetchStars();
    } catch (_) {}
  }

  void _initSensors() {
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent e) {
      setState(() {
        _pitch = e.x;
        _roll = e.y;
        // _accelX = e.x;
        // _accelY = e.y;
        // _accelZ = e.z;
      });
    });
    _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent e) {
      setState(() {
        _yaw = (_yaw + e.z * 0.02) % (2 * math.pi);
      });
    });
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        setState(() => _headingDeg = event.heading!);
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
      final List<Map<String, dynamic>> bodies = await _api.fetchVisibleBodies(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        limit: 20,
      );
      setState(() {
        _visibleStars = stars;
        _visibleBodies = bodies;
      });
    } finally {
      setState(() => _fetching = false);
    }
  }

  void _startPollingBackendAr() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_position == null || _lastLayoutSize == null) return;
      final double yawDeg = _normalizeDegrees(_headingDeg);
      final double pitchDeg = _estimateCenterAltitudeDeg();
      final Size size = _lastLayoutSize!;
      try {
        // Constellación activa (en FOV)
        final Map<String, dynamic> active = await _api.fetchIauInFov(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          yawDeg: yawDeg,
          pitchDeg: pitchDeg,
          fovHDeg: _horizontalFovDeg,
          fovVDeg: _verticalFovDeg,
        );
        // Mapa de pantalla para superponer imágenes
        final List<Map<String, dynamic>> screen = await _api.fetchConstellationsScreen(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          yawDeg: yawDeg,
          pitchDeg: pitchDeg,
          fovHDeg: _horizontalFovDeg,
          fovVDeg: _verticalFovDeg,
          widthPx: size.width.toInt(),
          heightPx: size.height.toInt(),
          clipEdgesToFov: true,
        );
        if (!mounted) return;
        setState(() {
          _activeConstellationName = (active['name'] as String?) ?? (active['constellation'] as String?);
          _constellationsScreen = screen;
        });
      } catch (_) {
        // Silenciar errores intermitentes de red para no saturar UI
      }
    });
  }

  Offset _projectToScreen(double azimuthDeg, double altitudeDeg, Size size) {
    final double centerAzDeg = _normalizeDegrees(_headingDeg);
    final double centerAltDeg = _estimateCenterAltitudeDeg();

    final double deltaAz = _wrapDegrees(azimuthDeg - centerAzDeg);
    final double deltaAlt = altitudeDeg - centerAltDeg;

    final double halfHFov = _horizontalFovDeg / 2.0;
    final double halfVFov = _verticalFovDeg / 2.0;

    if (deltaAz.abs() > halfHFov || deltaAlt.abs() > halfVFov) {
      // Fuera del FOV; devolvemos un punto fuera de pantalla para omitir
      return const Offset(-1000, -1000);
    }

    double xNorm = 0.5 + (deltaAz / _horizontalFovDeg);
    double yNorm = 0.5 - (deltaAlt / _verticalFovDeg);

    xNorm += 0.02 * math.atan(_roll / 9.8);

    xNorm = xNorm.clamp(0.0, 1.0);
    yNorm = yNorm.clamp(0.0, 1.0);

    return Offset(xNorm * size.width, yNorm * size.height);
  }

  double _estimateCenterAltitudeDeg() {
    final double pitchRad = math.atan(_pitch / 9.8);
    final double pitchDeg = pitchRad * 180.0 / math.pi;
    return (pitchDeg * (_pitchToAltScale / 45.0)).clamp(-45.0, 90.0);
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
          // ARView deshabilitado temporalmente (plugin no activo). Usamos fondo transparente.
          Container(color: Colors.transparent),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = Size(constraints.maxWidth, constraints.maxHeight);
              _lastLayoutSize = size;
              final List<_ConstellationConfig> configs = _dynamicConstellations ?? _defaultConstellations;
              final List<_ConstellationPlacement> placements = _computeConstellationPlacements(
                stars: _visibleStars,
                configs: configs,
              );
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    size: size,
                    painter: _SkyOverlayPainter(
                      stars: _visibleStars,
                      bodies: _visibleBodies,
                      project: (double az, double alt) => _projectToScreen(az, alt, size),
                      showConstellationLines: _showConstellationLines,
                      showMilkyWay: _showMilkyWay,
                    ),
                  ),
                  if (_showConstellationImages)
                    ..._buildConstellationImageWidgets(size, placements),
                ],
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              children: <Widget>[
                FloatingActionButton.small(
                  heroTag: 'refresh-ar',
                  onPressed: _fetchStars,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle-lines-ar',
                  onPressed: () => setState(() => _showConstellationLines = !_showConstellationLines),
                  child: Icon(_showConstellationLines ? Icons.grid_off : Icons.grid_on),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle-images-ar',
                  onPressed: () => setState(() => _showConstellationImages = !_showConstellationImages),
                  child: Icon(_showConstellationImages ? Icons.image_not_supported : Icons.image),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'toggle-milkyway-ar',
                  onPressed: () => setState(() => _showMilkyWay = !_showMilkyWay),
                  child: Icon(_showMilkyWay ? Icons.blur_off : Icons.blur_on),
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
    required this.bodies,
    required this.project,
    required this.showConstellationLines,
    required this.showMilkyWay,
  });

  final List<Map<String, dynamic>> stars;
  final List<Map<String, dynamic>> bodies;
  final Offset Function(double azimuthDeg, double altitudeDeg) project;
  final bool showConstellationLines;
  final bool showMilkyWay;

  @override
  void paint(Canvas canvas, Size size) {
    if (showMilkyWay) {
      final Paint milky = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.indigo.withOpacity(0.12),
            Colors.deepPurple.withOpacity(0.08),
            Colors.black.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), milky);
    }

    final Paint starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final Map<String, dynamic> star in stars) {
      final double az = (star['azimuth_deg'] as num?)?.toDouble() ?? 0;
      final double alt = (star['altitude_deg'] as num?)?.toDouble() ?? -90;
      final double mag = (star['magnitude'] as num?)?.toDouble() ?? 6;
      if (alt < 0) continue;
      final Offset p = project(az, alt);
      final double radius = math.max(1.0, 4.0 - (mag - 0.5));
      canvas.drawCircle(p, radius, starPaint);
    }

    if (showConstellationLines) {
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

    // Cuerpos (planetas, Sol, Luna, etc.) con etiquetas
    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    final Paint bodyPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;
    for (final Map<String, dynamic> body in bodies) {
      final double az = (body['azimuth_deg'] as num?)?.toDouble() ?? 0;
      final double alt = (body['altitude_deg'] as num?)?.toDouble() ?? -90;
      if (alt < 0) continue;
      final Offset p = project(az, alt);
      canvas.drawCircle(p, 5.0, bodyPaint);
      final String label = (body['name'] as String?) ?? 'Body';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600),
      );
      textPainter.layout(minWidth: 0, maxWidth: 200);
      textPainter.paint(canvas, p + const Offset(6, -6));
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

// Helpers de mapeo IAU -> asset PNG (español)
String? assetForIauName(String iauName, List<_ConstellationConfig>? dynamicConfigs) {
  final String key = _normalizeKey(iauName);
  const Map<String, String> direct = <String, String>{
    'aquila': 'assets/constellations/aguila.png',
    'andromeda': 'assets/constellations/andromeda.png',
    'bootes': 'assets/constellations/bootes.png',
    'canismajor': 'assets/constellations/canmayor.png',
    'cassiopeia': 'assets/constellations/casiopea.png',
    'cepheus': 'assets/constellations/cepheus.png',
    'cetus': 'assets/constellations/cetus.png',
    'cygnus': 'assets/constellations/cygnus.png',
    'draco': 'assets/constellations/draco.png',
    'eridanus': 'assets/constellations/eridanus.png',
    'scorpius': 'assets/constellations/escorpio.png',
    'scorpio': 'assets/constellations/escorpio.png',
    'gemini': 'assets/constellations/geminis.png',
    'leo': 'assets/constellations/leo.png',
    'lyra': 'assets/constellations/lyra.png',
    'orion': 'assets/constellations/orion.png',
    'pegasus': 'assets/constellations/pegaso.png',
    'sagittarius': 'assets/constellations/sagitario.png',
    'taurus': 'assets/constellations/tauro.png',
    'ursamajor': 'assets/constellations/ursamajor.png',
    'ursaminor': 'assets/constellations/ursaminor.png',
    'virgo': 'assets/constellations/virgo.png',
  };
  if (direct.containsKey(key)) return direct[key];
  // Intento con dinámicos (por si agregas más PNGs)
  if (dynamicConfigs != null) {
    for (final _ConstellationConfig c in dynamicConfigs) {
      if (_normalizeKey(c.name) == key) return c.assetPath;
    }
  }
  return null;
}

String _normalizeKey(String input) {
  final String noSpaces = input.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final String noDiacritics = noSpaces
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ï', 'i')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
  return noDiacritics.replaceAll(RegExp(r'[^a-z]'), '');
}

extension on _SkyARPageState {
  List<Widget> _buildConstellationImageWidgets(Size size, List<_ConstellationPlacement> localPlacements) {
    final List<Widget> widgets = <Widget>[];
    if (_constellationsScreen.isNotEmpty) {
      // Mostrar solo UNA constelación: la "activa" del backend si existe; si no, la primera.
      final String? activeKey = _activeConstellationName == null
          ? null
          : _normalizeKey(_activeConstellationName!);
      final Iterable<Map<String, dynamic>> filtered = activeKey == null
          ? _constellationsScreen.take(1)
          : _constellationsScreen.where((Map<String, dynamic> item) {
              final String? n = (item['name'] as String?) ?? (item['constellation'] as String?);
              return n != null && _normalizeKey(n) == activeKey;
            });

      for (final Map<String, dynamic> item in filtered) {
        final String? name = (item['name'] as String?) ?? (item['constellation'] as String?);
        if (name == null) continue;
        final String? assetPathMaybe = assetForIauName(name, _dynamicConstellations);
        if (assetPathMaybe == null) continue;
        if (!_availableAssets.contains(assetPathMaybe)) continue;
        final double x = ((item['x_px'] as num?)?.toDouble() ?? (size.width / 2));
        final double y = ((item['y_px'] as num?)?.toDouble() ?? (size.height / 2));
        final double px = ((item['pixel_size'] as num?)?.toDouble() ?? 160);
        widgets.add(Positioned(
          left: x - px / 2,
          top: y - px / 2,
          width: px,
          height: px,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1.0,
              child: Image.asset(assetPathMaybe, fit: BoxFit.contain),
            ),
          ),
        ));
      }
      return widgets;
    }
    // Fallback local (aproximado) si backend aún no responde
    // Solo una también en fallback: priorizar la activa si se conoce
    final String? activeKey = _activeConstellationName == null
        ? null
        : _normalizeKey(_activeConstellationName!);
    final Iterable<_ConstellationPlacement> toDraw = activeKey == null
        ? localPlacements.take(1)
        : localPlacements.where((p) => _normalizeKey(p.name) == activeKey).take(1);
    for (final _ConstellationPlacement p in toDraw) {
      final Offset screen = _projectToScreen(p.centerAzimuthDeg, p.centerAltitudeDeg, size);
      final String assetPathCandidate = assetForIauName(p.name, _dynamicConstellations) ?? p.assetPath;
      if (!_availableAssets.contains(assetPathCandidate)) continue;
      final double px = p.pixelSize.toDouble();
      widgets.add(Positioned(
        left: screen.dx - px / 2,
        top: screen.dy - px / 2,
        width: px,
        height: px,
        child: IgnorePointer(
          child: Opacity(
            opacity: 1.0,
            child: Image.asset(assetPathCandidate, fit: BoxFit.contain),
          ),
        ),
      ));
    }
    return widgets;
  }
}


