import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'https://agri-app-backend-6kyx.onrender.com',
);

const double defaultPunjabLat = 31.1704;
const double defaultPunjabLon = 72.7097;

void main() {
  runApp(const AgriApp());
}

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Instructions - Punjab, Pakistan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
        ).copyWith(
          secondary: Colors.lightGreen,
          surface: const Color(0xFFF4FAF4),
        ),
        scaffoldBackgroundColor: const Color(0xFFEFF8EE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade100),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1B5E20),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loadingWeather = true;
  String? _weatherError;
  bool _analyzingField = false;
  String? _gisError;
  Map<String, dynamic>? _gisResult;
  double? _temperature;
  double? _windSpeed;
  List<String>? _forecastDates;
  List<double>? _forecastPrecip;
  List<double>? _forecastEt0;
  double? _referenceEt0Total;
  double? _estimatedCropWaterNeedTotal;
  double? _netWaterBalanceTotal;
  String? _irrigationAdvice;
  String _selectedCrop = 'Maize';
  String _selectedLanguage = 'English';
  List<LatLng> _fieldPolygon = [];

  final latController = TextEditingController(text: defaultPunjabLat.toString());
  final lonController = TextEditingController(text: defaultPunjabLon.toString());

  Uri _backendUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(backendBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path}$normalizedPath',
      queryParameters: queryParameters,
    );
  }

  LatLng _polygonCentroid(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(defaultPunjabLat, defaultPunjabLon);
    }
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lon = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lon);
  }

  double _cropCoefficient(String crop) {
    switch (crop) {
      case 'Rice':
        return 1.10;
      case 'Maize':
        return 1.00;
      case 'Wheat':
        return 0.90;
      case 'Potato':
        return 0.85;
      default:
        return 0.95;
    }
  }

  Future<void> _openMapPicker() async {
    final currentLat = double.tryParse(latController.text) ?? defaultPunjabLat;
    final currentLon = double.tryParse(lonController.text) ?? defaultPunjabLon;
    LatLng pickedPoint = LatLng(currentLat, currentLon);
    var drawBoundaryMode = false;
    var selectedLayer = 'osm';
    var eeTileUrl = '';
    var eeLoading = false;
    String? eeError;
    final boundaryPoints = List<LatLng>.from(_fieldPolygon);

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadEeTiles(String layer) async {
              setDialogState(() {
                eeLoading = true;
                eeError = null;
              });

              final uri = _backendUri('/ee-tiles', {
                'latitude': pickedPoint.latitude.toString(),
                'longitude': pickedPoint.longitude.toString(),
                'layer': layer,
              });

              try {
                final response = await http.get(uri);
                if (!context.mounted) {
                  return;
                }
                if (response.statusCode != 200) {
                  throw Exception('Layer fetch failed: ${response.statusCode}');
                }
                final data = jsonDecode(response.body) as Map<String, dynamic>;
                setDialogState(() {
                  eeTileUrl = data['url_template']?.toString() ?? '';
                  eeLoading = false;
                });
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  eeError = e.toString();
                  eeLoading = false;
                  eeTileUrl = '';
                });
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: SizedBox(
              height: 470,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t('tapMapToSelect'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                drawBoundaryMode = !drawBoundaryMode;
                              });
                            },
                            child: Text(drawBoundaryMode ? _t('pointMode') : _t('boundaryMode')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(_t('close')),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Row(
                        children: [
                          Text('${_t('layer')}:', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('OSM'),
                            selected: selectedLayer == 'osm',
                            onSelected: (_) {
                              setDialogState(() {
                                selectedLayer = 'osm';
                                eeError = null;
                                eeTileUrl = '';
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('True Color'),
                            selected: selectedLayer == 'true_color',
                            onSelected: (_) async {
                              setDialogState(() {
                                selectedLayer = 'true_color';
                              });
                              await loadEeTiles('true_color');
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('NDVI'),
                            selected: selectedLayer == 'ndvi',
                            onSelected: (_) async {
                              setDialogState(() {
                                selectedLayer = 'ndvi';
                              });
                              await loadEeTiles('ndvi');
                            },
                          ),
                        ],
                      ),
                    ),
                    if (eeLoading)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(_t('loadingEeTiles'), style: TextStyle(fontSize: 11)),
                      ),
                    if (eeError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          eeError!,
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (selectedLayer == 'ndvi')
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('ndviLegend'),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildLegendColor(const Color(0xFF8B0000), _t('low')),
                                const SizedBox(width: 6),
                                _buildLegendColor(const Color(0xFFF4D03F), _t('sparse')),
                                const SizedBox(width: 6),
                                _buildLegendColor(const Color(0xFF7FBF3F), _t('moderate')),
                                const SizedBox(width: 6),
                                _buildLegendColor(const Color(0xFF006400), _t('high')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: pickedPoint,
                          initialZoom: 9,
                          onTap: (tapPosition, point) {
                            setDialogState(() {
                              if (drawBoundaryMode) {
                                boundaryPoints.add(point);
                              } else {
                                pickedPoint = point;
                              }
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.agri_app',
                          ),
                          if (selectedLayer != 'osm' && eeTileUrl.isNotEmpty)
                            TileLayer(
                              urlTemplate: eeTileUrl,
                              userAgentPackageName: 'com.example.agri_app',
                              maxZoom: 18,
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pickedPoint,
                                width: 34,
                                height: 34,
                                child: const Icon(
                                  Icons.location_on,
                                  size: 34,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              ...boundaryPoints.map(
                                (p) => Marker(
                                  point: p,
                                  width: 18,
                                  height: 18,
                                  child: const Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (boundaryPoints.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    ...boundaryPoints,
                                    if (boundaryPoints.length >= 3) boundaryPoints.first,
                                  ],
                                  color: Colors.deepOrange,
                                  strokeWidth: 2,
                                ),
                              ],
                            ),
                          if (boundaryPoints.length >= 3)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: boundaryPoints,
                                  color: Colors.deepOrange.withValues(alpha: 0.2),
                                  borderColor: Colors.deepOrange,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              drawBoundaryMode
                                  ? '${_t('boundaryPoints')}: ${boundaryPoints.length}'
                                  : '${_t('latitude')} ${pickedPoint.latitude.toStringAsFixed(5)}, ${_t('longitude')} ${pickedPoint.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (drawBoundaryMode)
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  if (boundaryPoints.isNotEmpty) {
                                    boundaryPoints.removeLast();
                                  }
                                });
                              },
                              child: Text(_t('undo')),
                            ),
                          ElevatedButton(
                            onPressed: () {
                              if (drawBoundaryMode && boundaryPoints.length >= 3) {
                                Navigator.pop(context, {
                                  'point': _polygonCentroid(boundaryPoints),
                                  'polygon': boundaryPoints,
                                });
                                return;
                              }
                              Navigator.pop(context, {
                                'point': pickedPoint,
                                'polygon': <LatLng>[],
                              });
                            },
                            child: Text(
                              drawBoundaryMode ? _t('useBoundary') : _t('useThisPoint'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      final point = selected['point'] as LatLng;
      final polygon = (selected['polygon'] as List<LatLng>?) ?? <LatLng>[];
      setState(() {
        latController.text = point.latitude.toStringAsFixed(5);
        lonController.text = point.longitude.toStringAsFixed(5);
        _fieldPolygon = polygon;
      });
      _fetchWeather();
    }
  }

  final Map<String, Map<String, double>> _cropThresholds = {
    'Maize': {'low': 10, 'high': 30},
    'Wheat': {'low': 8, 'high': 25},
    'Rice': {'low': 20, 'high': 40},
    'Potato': {'low': 12, 'high': 28},
  };

  String _cropLabel(String cropKey) {
    return cropLabelsByLanguage[_selectedLanguage]?[cropKey] ?? cropKey;
  }

  String _cropInstructions(String cropKey) {
    return cropInstructionsByLanguage[_selectedLanguage]?[cropKey] ??
        cropInstructionsByLanguage['English']![cropKey]!;
  }

  String _t(String key) {
    return uiTextByLanguage[_selectedLanguage]?[key] ??
        uiTextByLanguage['English']![key] ??
        key;
  }

  String _cropInstructionsTitle(String cropKey) {
    return '${_cropLabel(cropKey)} ${_t('instructions')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
      _irrigationAdvice = null;
    });

    final latitude = double.tryParse(latController.text);
    final longitude = double.tryParse(lonController.text);

    if (latitude == null || longitude == null) {
      setState(() {
        _weatherError = _t('invalidLatLon');
        _loadingWeather = false;
      });
      return;
    }

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,et0_fao_evapotranspiration&current_weather=true&timezone=Asia%2FKarachi',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('${_t('unableToFetchWeather')} (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final currentWeather = data['current_weather'] as Map<String, dynamic>?;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (currentWeather == null || daily == null) {
        throw Exception(_t('weatherDataMissing'));
      }

      final dates = (daily['time'] as List<dynamic>).cast<String>();
      final precip = (daily['precipitation_sum'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final et0 = (daily['et0_fao_evapotranspiration'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          <double>[];

      final total7 = precip.take(7).fold<double>(0, (a, b) => a + b);
      final et0Total7 = et0.take(7).fold<double>(0, (a, b) => a + b);
      final estimatedCropWaterNeed = et0Total7 * _cropCoefficient(_selectedCrop);
      final netWaterBalance = total7 - estimatedCropWaterNeed;
      String advice;

      if (netWaterBalance > 12) {
        advice = '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('reduceIrrigationEtAdvice')}';
      } else if (netWaterBalance < -12) {
        advice = '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('increaseIrrigationEtAdvice')}';
      } else {
        advice = '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('balancedIrrigationEtAdvice')}';
      }

      setState(() {
        _temperature = (currentWeather['temperature'] as num).toDouble();
        _windSpeed = (currentWeather['windspeed'] as num).toDouble();
        _forecastDates = dates.take(7).toList();
        _forecastPrecip = precip.take(7).toList();
        _forecastEt0 = et0.take(7).toList();
        _referenceEt0Total = et0Total7;
        _estimatedCropWaterNeedTotal = estimatedCropWaterNeed;
        _netWaterBalanceTotal = netWaterBalance;
        _irrigationAdvice = advice;
        _loadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _weatherError = e.toString();
        _loadingWeather = false;
      });
    }
  }

  Widget _buildLegendColor(Color color, String label) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeField() async {
    final latitude = double.tryParse(latController.text);
    final longitude = double.tryParse(lonController.text);

    if (latitude == null || longitude == null) {
      setState(() {
        _gisError = _t('invalidLatLon');
      });
      return;
    }

    setState(() {
      _analyzingField = true;
      _gisError = null;
    });

    try {
      final response = await http.post(
        _backendUri('/analyze-field'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'selected_crop': _selectedCrop,
          'polygon': _fieldPolygon
              .map((p) => [p.latitude, p.longitude])
              .toList(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('${_t('backendError')}: ${response.statusCode}');
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _gisResult = result;
        _analyzingField = false;
      });
    } catch (e) {
      setState(() {
        _gisError = e.toString();
        _analyzingField = false;
      });
    }
  }

  Widget _buildWeatherBox() {
    if (_loadingWeather) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Text(_t('loadingWeather')),
        ),
      );
    }

    if (_weatherError != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('${_t('weatherDataError')}: $_weatherError'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('currentWeather'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            _buildSkyHeader(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_temperature != null) ...[
                  Column(
                    children: [
                      const Icon(Icons.thermostat, size: 24, color: Colors.red),
                      Text(
                        '${_temperature!.toStringAsFixed(1)}°C',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
                if (_windSpeed != null) ...[
                  Column(
                    children: [
                      const Icon(Icons.air, size: 24, color: Colors.blue),
                      Text(
                        '${_windSpeed!.toStringAsFixed(1)} km/h',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text('${_t('selectedCrop')}: $_selectedCrop'),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: _selectedCrop,
              isDense: true,
              items: _cropThresholds.keys
                  .map((crop) => DropdownMenuItem(
                        value: crop,
                        child: Text(crop),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCrop = value;
                    // Re-evaluate recommendations once crop changes
                    if (_forecastPrecip != null) {
                      _fetchWeather();
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 4),
            if (_cropThresholds[_selectedCrop] != null) ...[
              Text(
                  '${_t('irrigationThresholdsFor')} $_selectedCrop: ${_t('low')} ${_cropThresholds[_selectedCrop]!['low']} mm, ${_t('high')} ${_cropThresholds[_selectedCrop]!['high']} mm'),
              const SizedBox(height: 6),
            ],
            if (_referenceEt0Total != null) ...[
              Text('${_t('referenceEt0')}: ${_referenceEt0Total!.toStringAsFixed(1)} mm'),
            ],
            if (_estimatedCropWaterNeedTotal != null) ...[
              Text('${_t('cropWaterNeed')}: ${_estimatedCropWaterNeedTotal!.toStringAsFixed(1)} mm'),
            ],
            if (_netWaterBalanceTotal != null) ...[
              Text('${_t('waterBalance')}: ${_netWaterBalanceTotal!.toStringAsFixed(1)} mm'),
              const SizedBox(height: 6),
            ],
            if (_forecastDates != null && _forecastPrecip != null) ...[
              Text(
                _t('sevenDayForecast'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_forecastDates!.length, (i) {
                    final precip = _forecastPrecip![i];
                    final et0 = _forecastEt0 != null && i < _forecastEt0!.length
                      ? _forecastEt0![i]
                      : 0.0;
                    final date = _forecastDates![i];
                    Color bgColor;
                    IconData weatherIcon;
                    String condition;

                    if (precip > 10) {
                      bgColor = Colors.blue[200]!;
                      weatherIcon = Icons.cloudy_snowing;
                      condition = _t('rainy');
                    } else if (precip > 5) {
                      bgColor = Colors.grey[300]!;
                      weatherIcon = Icons.cloud;
                      condition = _t('cloudy');
                    } else {
                      bgColor = Colors.yellow[200]!;
                      weatherIcon = Icons.wb_sunny;
                      condition = _t('sunny');
                    }

                    return Container(
                      width: 58,
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            date.split('-')[2], // Day only
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Icon(weatherIcon, size: 17),
                          const SizedBox(height: 2),
                          Text(
                            '${precip.toStringAsFixed(1)} mm',
                            style: const TextStyle(fontSize: 8.5),
                          ),
                          Text(
                            'ET ${et0.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 8),
                          ),
                          Text(
                            condition,
                            style: const TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 5),
            ],
            if (_irrigationAdvice != null) ...[
              Text(
                _t('irrigationRecommendation'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(_irrigationAdvice!),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: _fetchWeather,
              child: Text(_t('refreshWeather')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkyHeader() {
    final dailyPrecip = _forecastPrecip ?? <double>[];
    final avgPrecip = dailyPrecip.isEmpty
        ? 0.0
        : dailyPrecip.take(7).reduce((a, b) => a + b) /
            dailyPrecip.take(7).length;

    List<Color> skyColors;
    IconData skyIcon;
    String skyLabel;

    if (avgPrecip >= 9) {
      skyColors = const [Color(0xFF4A6FA5), Color(0xFF89A7D8)];
      skyIcon = Icons.thunderstorm;
      skyLabel = _t('rainyWeekAhead');
    } else if (avgPrecip >= 4) {
      skyColors = const [Color(0xFF8FA4B8), Color(0xFFD7E0E8)];
      skyIcon = Icons.cloud;
      skyLabel = _t('cloudyConditions');
    } else {
      skyColors = const [Color(0xFF5EBCE6), Color(0xFFFEDB8A)];
      skyIcon = Icons.wb_sunny;
      skyLabel = _t('mostlyClearSkies');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skyColors,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Icon(
              skyIcon,
              key: ValueKey<String>(skyLabel),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              skyLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          if (_temperature != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_temperature!.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGisCard() {
    if (_analyzingField) {
      return Card(
        margin: EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(_t('analyzingWithGis')),
            ],
          ),
        ),
      );
    }

    if (_gisError != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('${_t('gisError')}: $_gisError'),
        ),
      );
    }

    if (_gisResult == null) {
      return const SizedBox.shrink();
    }

    final detectedCrop = _gisResult!['detected_crop'];
    final confidence = _gisResult!['confidence'];
    final ndvi = _gisResult!['ndvi'];
    final fieldCondition = _gisResult!['field_condition'];
    final recommendation = _gisResult!['recommendation'];
    final earthEngineReady = _gisResult!['earth_engine_ready'] == true;
    final diagnostic = _gisResult!['diagnostic'];
    final precipitation7day = _gisResult!['precipitation_7day_mm'];
    final referenceEt07day = _gisResult!['reference_et0_7day_mm'];
    final cropWaterNeed7day = _gisResult!['estimated_crop_water_need_7day_mm'];
    final waterBalance7day = _gisResult!['net_water_balance_7day_mm'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('gisFieldAnalysis'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  earthEngineReady ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: earthEngineReady ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    earthEngineReady
                        ? _t('earthEngineConnected')
                        : _t('earthEngineNotReady'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (diagnostic != null) ...[
              const SizedBox(height: 4),
              Text(
                diagnostic.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: earthEngineReady ? Colors.black87 : Colors.orange.shade900,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text('${_t('detectedCrop')}: $detectedCrop'),
            Text('${_t('confidence')}: ${(confidence as num).toStringAsFixed(2)}'),
            if (ndvi != null) Text('NDVI: ${(ndvi as num).toStringAsFixed(3)}'),
            if (precipitation7day != null)
              Text('7d Rainfall: ${(precipitation7day as num).toStringAsFixed(1)} mm'),
            if (referenceEt07day != null)
              Text('${_t('referenceEt0')}: ${(referenceEt07day as num).toStringAsFixed(1)} mm'),
            if (cropWaterNeed7day != null)
              Text('${_t('cropWaterNeed')}: ${(cropWaterNeed7day as num).toStringAsFixed(1)} mm'),
            if (waterBalance7day != null)
              Text('${_t('waterBalance')}: ${(waterBalance7day as num).toStringAsFixed(1)} mm'),
            Text('${_t('condition')}: $fieldCondition'),
            const SizedBox(height: 4),
            Text(recommendation.toString()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('cropInstructions')),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
            Text(
              _t('selectCropPrompt'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(_t('languageLabel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'Urdu', child: Text('اردو')),
                      DropdownMenuItem(value: 'Punjabi', child: Text('پنجابی')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLanguage = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: _t('latitude'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: lonController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: _t('longitude'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchWeather,
              child: Text(_t('loadWeatherForLocation')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map),
              label: Text(_t('pickLocationOnMap')),
            ),
            if (_fieldPolygon.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_t('boundarySelected')}: ${_fieldPolygon.length} ${_t('points')}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _analyzeField,
              icon: const Icon(Icons.satellite_alt),
              label: Text(_t('analyzeFieldGis')),
            ),
            _buildGisCard(),
            const SizedBox(height: 12),
            _buildWeatherBox(),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropInstructionsScreen(
                    cropName: _cropInstructionsTitle('Maize'),
                    instructions: _cropInstructions('Maize'),
                  ),
                ),
              ),
              child: Text(_cropLabel('Maize')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropInstructionsScreen(
                    cropName: _cropInstructionsTitle('Wheat'),
                    instructions: _cropInstructions('Wheat'),
                  ),
                ),
              ),
              child: Text(_cropLabel('Wheat')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropInstructionsScreen(
                    cropName: _cropInstructionsTitle('Rice'),
                    instructions: _cropInstructions('Rice'),
                  ),
                ),
              ),
              child: Text(_cropLabel('Rice')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropInstructionsScreen(
                    cropName: _cropInstructionsTitle('Potato'),
                    instructions: _cropInstructions('Potato'),
                  ),
                ),
              ),
              child: Text(_cropLabel('Potato')),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropInstructionsScreen extends StatelessWidget {
  const CropInstructionsScreen({
    super.key,
    required this.cropName,
    required this.instructions,
  });

  final String cropName;
  final String instructions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$cropName Instructions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          instructions,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

const Map<String, Map<String, String>> uiTextByLanguage = {
  'English': {
    'instructions': 'Instructions',
    'cropInstructions': 'Crop Instructions',
    'selectCropPrompt': 'Select a crop to view farming instructions for your region:',
    'languageLabel': 'Language:',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'loadWeatherForLocation': 'Load weather for location',
    'pickLocationOnMap': 'Pick location on map',
    'boundarySelected': 'Boundary selected',
    'points': 'points',
    'analyzeFieldGis': 'Analyze Field (GIS)',
    'tapMapToSelect': 'Tap map to select location/boundary',
    'pointMode': 'Point mode',
    'boundaryMode': 'Boundary mode',
    'close': 'Close',
    'layer': 'Layer',
    'loadingEeTiles': 'Loading Earth Engine tiles...',
    'ndviLegend': 'NDVI Legend',
    'low': 'Low',
    'sparse': 'Sparse',
    'moderate': 'Moderate',
    'high': 'High',
    'boundaryPoints': 'Boundary points',
    'undo': 'Undo',
    'useBoundary': 'Use boundary',
    'useThisPoint': 'Use this point',
    'invalidLatLon': 'Invalid latitude or longitude.',
    'unableToFetchWeather': 'Unable to fetch weather',
    'weatherDataMissing': 'Weather response missing required data',
    'highRainfallFor': 'High forecasted rainfall for',
    'lowRainfallFor': 'Low forecasted rainfall for',
    'moderateRainfallFor': 'Moderate rainfall for',
    'total': 'total',
    'reduceIrrigationAdvice': 'Reduce irrigation and check soil before watering.',
    'increaseIrrigationAdvice': 'Increase irrigation frequency and ensure sufficient moisture.',
    'standardIrrigationAdvice': 'Keep standard irrigation schedule and monitor soil moisture.',
    'backendError': 'Backend error',
    'loadingWeather': 'Loading weather...',
    'weatherDataError': 'Weather data error',
    'currentWeather': 'Current Weather',
    'selectedCrop': 'Selected crop',
    'irrigationThresholdsFor': 'Irrigation thresholds for',
    'sevenDayForecast': '7-day rainfall forecast:',
    'rainy': 'Rainy',
    'cloudy': 'Cloudy',
    'sunny': 'Sunny',
    'irrigationRecommendation': 'Irrigation recommendation:',
    'referenceEt0': 'Reference ET0 (7d)',
    'cropWaterNeed': 'Estimated crop water need (7d)',
    'waterBalance': 'Net water balance (7d)',
    'reduceIrrigationEtAdvice': 'Forecast rainfall is above estimated crop demand. Reduce irrigation and avoid waterlogging.',
    'increaseIrrigationEtAdvice': 'Forecast rainfall is below estimated crop demand. Increase irrigation in smaller, timely applications.',
    'balancedIrrigationEtAdvice': 'Forecast rainfall is close to estimated crop demand. Keep moderate irrigation and confirm soil moisture.',
    'refreshWeather': 'Refresh weather',
    'rainyWeekAhead': 'Rainy week ahead',
    'cloudyConditions': 'Cloudy conditions',
    'mostlyClearSkies': 'Mostly clear skies',
    'analyzingWithGis': 'Analyzing field with GIS...',
    'gisError': 'GIS error',
    'gisFieldAnalysis': 'GIS Field Analysis',
    'earthEngineConnected': 'Earth Engine connected',
    'earthEngineNotReady': 'Earth Engine not ready',
    'detectedCrop': 'Detected crop',
    'confidence': 'Confidence',
    'condition': 'Condition',
  },
  'Urdu': {
    'instructions': 'ہدایات',
    'cropInstructions': 'فصل کی ہدایات',
    'selectCropPrompt': 'اپنے علاقے کے لیے کاشتکاری ہدایات دیکھنے کے لیے فصل منتخب کریں:',
    'languageLabel': 'زبان:',
    'latitude': 'عرض بلد',
    'longitude': 'طول بلد',
    'loadWeatherForLocation': 'مقام کے لیے موسم لوڈ کریں',
    'pickLocationOnMap': 'نقشے سے مقام منتخب کریں',
    'boundarySelected': 'حد بندی منتخب',
    'points': 'نقاط',
    'analyzeFieldGis': 'کھیت کا تجزیہ (GIS)',
    'tapMapToSelect': 'مقام یا حد بندی منتخب کرنے کے لیے نقشے پر ٹیپ کریں',
    'pointMode': 'نقطہ موڈ',
    'boundaryMode': 'حد بندی موڈ',
    'close': 'بند کریں',
    'layer': 'لیئر',
    'loadingEeTiles': 'ارتھ انجن ٹائلز لوڈ ہو رہی ہیں...',
    'ndviLegend': 'این ڈی وی آئی لیجنڈ',
    'low': 'کم',
    'sparse': 'کمزور',
    'moderate': 'درمیانہ',
    'high': 'زیادہ',
    'boundaryPoints': 'حد بندی نقاط',
    'undo': 'واپس',
    'useBoundary': 'یہ حد بندی استعمال کریں',
    'useThisPoint': 'یہ نقطہ استعمال کریں',
    'invalidLatLon': 'عرض بلد یا طول بلد درست نہیں۔',
    'unableToFetchWeather': 'موسم حاصل نہیں ہو سکا',
    'weatherDataMissing': 'موسمی ڈیٹا نامکمل ہے',
    'highRainfallFor': 'زیادہ بارش کی پیشگوئی برائے',
    'lowRainfallFor': 'کم بارش کی پیشگوئی برائے',
    'moderateRainfallFor': 'درمیانی بارش برائے',
    'total': 'کل',
    'reduceIrrigationAdvice': 'آبپاشی کم کریں اور پانی دینے سے پہلے زمین چیک کریں۔',
    'increaseIrrigationAdvice': 'آبپاشی بڑھائیں اور مناسب نمی یقینی بنائیں۔',
    'standardIrrigationAdvice': 'معمول کی آبپاشی جاری رکھیں اور زمین کی نمی دیکھتے رہیں۔',
    'backendError': 'بیک اینڈ خرابی',
    'loadingWeather': 'موسم لوڈ ہو رہا ہے...',
    'weatherDataError': 'موسمی ڈیٹا خرابی',
    'currentWeather': 'موجودہ موسم',
    'selectedCrop': 'منتخب فصل',
    'irrigationThresholdsFor': 'آبپاشی حدیں برائے',
    'sevenDayForecast': '7 دن کی بارش کی پیشگوئی:',
    'rainy': 'بارش',
    'cloudy': 'ابر آلود',
    'sunny': 'دھوپ',
    'irrigationRecommendation': 'آبپاشی کی سفارش:',
    'referenceEt0': 'ریفرنس ای ٹی0 (7 دن)',
    'cropWaterNeed': 'اندازہ شدہ فصلی پانی کی ضرورت (7 دن)',
    'waterBalance': 'خالص پانی توازن (7 دن)',
    'reduceIrrigationEtAdvice': 'متوقع بارش فصل کی اندازہ شدہ ضرورت سے زیادہ ہے۔ آبپاشی کم کریں اور پانی کھڑا ہونے سے بچیں۔',
    'increaseIrrigationEtAdvice': 'متوقع بارش فصل کی اندازہ شدہ ضرورت سے کم ہے۔ آبپاشی چھوٹے مگر بروقت وقفوں میں بڑھائیں۔',
    'balancedIrrigationEtAdvice': 'متوقع بارش فصل کی اندازہ شدہ ضرورت کے قریب ہے۔ معتدل آبپاشی رکھیں اور مٹی کی نمی چیک کریں۔',
    'refreshWeather': 'موسم تازہ کریں',
    'rainyWeekAhead': 'آگے بارش والا ہفتہ',
    'cloudyConditions': 'ابر آلود حالات',
    'mostlyClearSkies': 'زیادہ تر صاف آسمان',
    'analyzingWithGis': 'GIS سے کھیت کا تجزیہ ہو رہا ہے...',
    'gisError': 'GIS خرابی',
    'gisFieldAnalysis': 'GIS کھیت تجزیہ',
    'earthEngineConnected': 'ارتھ انجن منسلک ہے',
    'earthEngineNotReady': 'ارتھ انجن تیار نہیں',
    'detectedCrop': 'شناخت شدہ فصل',
    'confidence': 'اعتماد',
    'condition': 'حالت',
  },
  'Punjabi': {
    'instructions': 'ہدایتاں',
    'cropInstructions': 'فصل دیاں ہدایتاں',
    'selectCropPrompt': 'اپنے علاقے لئی فصل دیاں ہدایتاں دیکھن لئی فصل چنو:',
    'languageLabel': 'زبان:',
    'latitude': 'عرض بلد',
    'longitude': 'طول بلد',
    'loadWeatherForLocation': 'مقام دا موسم لوڈ کرو',
    'pickLocationOnMap': 'نقشے توں مقام چنو',
    'boundarySelected': 'حد بندی منتخب',
    'points': 'نقطے',
    'analyzeFieldGis': 'کھیت دا تجزیہ (GIS)',
    'tapMapToSelect': 'مقام یا حد بندی چنّن لئی نقشے تے ٹیپ کرو',
    'pointMode': 'پوائنٹ موڈ',
    'boundaryMode': 'حد بندی موڈ',
    'close': 'بند کرو',
    'layer': 'لیئر',
    'loadingEeTiles': 'ارتھ انجن ٹائلز لوڈ ہو رہیاں نیں...',
    'ndviLegend': 'این ڈی وی آئی لیجنڈ',
    'low': 'گھٹ',
    'sparse': 'کمزور',
    'moderate': 'درمیانہ',
    'high': 'وَدھ',
    'boundaryPoints': 'حد بندی دے نقطے',
    'undo': 'واپس',
    'useBoundary': 'ایہہ حد بندی ورتو',
    'useThisPoint': 'ایہہ نقطہ ورتو',
    'invalidLatLon': 'عرض بلد یا طول بلد درست نہیں۔',
    'unableToFetchWeather': 'موسم حاصل نئیں ہو سکیا',
    'weatherDataMissing': 'موسمی ڈیٹا ادھورا اے',
    'highRainfallFor': 'زیادہ بارش دی پیشگوئی برائے',
    'lowRainfallFor': 'گھٹ بارش دی پیشگوئی برائے',
    'moderateRainfallFor': 'درمیانی بارش برائے',
    'total': 'کُل',
    'reduceIrrigationAdvice': 'آبپاشی گھٹاؤ تے پانی توں پہلاں زمین چیک کرو۔',
    'increaseIrrigationAdvice': 'آبپاشی ودھاؤ تے مناسب نمی یقینی بناؤ۔',
    'standardIrrigationAdvice': 'معمول مطابق آبپاشی رکھو تے نمی تے نظر رکھو۔',
    'backendError': 'بیک اینڈ خرابی',
    'loadingWeather': 'موسم لوڈ ہو رہیا اے...',
    'weatherDataError': 'موسمی ڈیٹا خرابی',
    'currentWeather': 'موجودہ موسم',
    'selectedCrop': 'منتخب فصل',
    'irrigationThresholdsFor': 'آبپاشی حدیں برائے',
    'sevenDayForecast': '7 دن دی بارش دی پیشگوئی:',
    'rainy': 'بارش',
    'cloudy': 'ابر آلود',
    'sunny': 'دھوپ',
    'irrigationRecommendation': 'آبپاشی دی سفارش:',
    'referenceEt0': 'ریفرنس ای ٹی0 (7 دن)',
    'cropWaterNeed': 'اندازہ شدہ فصلی پانی دی لوڑ (7 دن)',
    'waterBalance': 'نیٹ پانی توازن (7 دن)',
    'reduceIrrigationEtAdvice': 'متوقع بارش فصل دی اندازہ شدہ لوڑ توں ودھ اے۔ آبپاشی گھٹاؤ تے پانی کھلوتا نہ رہن دو۔',
    'increaseIrrigationEtAdvice': 'متوقع بارش فصل دی اندازہ شدہ لوڑ توں گھٹ اے۔ آبپاشی چھوٹے مگر بروقت وقفیاں وچ ودھاؤ۔',
    'balancedIrrigationEtAdvice': 'متوقع بارش فصل دی اندازہ شدہ لوڑ دے قریب اے۔ معتدل آبپاشی رکھو تے مٹی دی نمی چیک کرو۔',
    'refreshWeather': 'موسم تازہ کرو',
    'rainyWeekAhead': 'اگلا ہفتہ بارش والا',
    'cloudyConditions': 'ابر آلود حالات',
    'mostlyClearSkies': 'زیادہ تر صاف آسمان',
    'analyzingWithGis': 'GIS نال کھیت دا تجزیہ ہو رہیا اے...',
    'gisError': 'GIS خرابی',
    'gisFieldAnalysis': 'GIS کھیت تجزیہ',
    'earthEngineConnected': 'ارتھ انجن منسلک اے',
    'earthEngineNotReady': 'ارتھ انجن تیار نئیں',
    'detectedCrop': 'شناخت شدہ فصل',
    'confidence': 'اعتماد',
    'condition': 'حالت',
  },
};

const Map<String, Map<String, String>> cropLabelsByLanguage = {
  'English': {
    'Maize': 'Maize',
    'Wheat': 'Wheat',
    'Rice': 'Rice',
    'Potato': 'Potato',
  },
  'Urdu': {
    'Maize': 'مکئی',
    'Wheat': 'گندم',
    'Rice': 'چاول',
    'Potato': 'آلو',
  },
  'Punjabi': {
    'Maize': 'مکئی',
    'Wheat': 'کنک',
    'Rice': 'چاول',
    'Potato': 'آلو',
  },
};

const Map<String, Map<String, String>> cropInstructionsByLanguage = {
  'English': {
    'Maize': maizeInstructions,
    'Wheat': wheatInstructions,
    'Rice': riceInstructions,
    'Potato': potatoInstructions,
  },
  'Urdu': {
    'Maize': maizeInstructionsUrdu,
    'Wheat': wheatInstructionsUrdu,
    'Rice': riceInstructionsUrdu,
    'Potato': potatoInstructionsUrdu,
  },
  'Punjabi': {
    'Maize': maizeInstructionsPunjabi,
    'Wheat': wheatInstructionsPunjabi,
    'Rice': riceInstructionsPunjabi,
    'Potato': potatoInstructionsPunjabi,
  },
};

// Placeholder instructions - will be replaced with researched data
const String maizeInstructions = '''
Soil Preparation:
- Prepare well-drained loamy soil
- pH: 6.0-7.0
- Deep plowing and harrowing

Seed Selection and Sowing:
- Use certified hybrid seeds
- Sowing time: June-July
- Seed rate: 20-25 kg/ha
- Row spacing: 60-75 cm

Irrigation:
- First irrigation after sowing
- Subsequent irrigations every 7-10 days
- Total 4-6 irrigations

Fertilizer:
- NPK: 120-60-40 kg/ha
- Apply in splits

Pest Management:
- Monitor for stem borers, aphids
- Use integrated pest management

Harvesting:
- Harvest when grains are hard
- Yield: 4-6 tons/ha
''';

const String wheatInstructions = '''
Soil Preparation:
- Fine tilth soil
- pH: 6.5-7.5
- Ploughing and leveling

Seed Selection and Sowing:
- Use improved varieties
- Sowing time: November-December
- Seed rate: 100-125 kg/ha
- Row spacing: 20-25 cm

Irrigation:
- Pre-sowing irrigation
- Crown root initiation, tillering, jointing, grain filling
- Total 4-5 irrigations

Fertilizer:
- NPK: 120-60-40 kg/ha
- Apply urea in splits

Disease Management:
- Rust, smut diseases
- Use resistant varieties

Harvesting:
- Harvest when grains are hard
- Yield: 3-5 tons/ha
''';

const String riceInstructions = '''
Soil Preparation:
- Puddled soil
- pH: 6.0-7.0
- Bunds and leveling

Seed Selection and Sowing:
- Use high-yielding varieties
- Sowing time: June-July
- Seed rate: 40-50 kg/ha
- Transplanting after 25-30 days

Irrigation:
- Continuous flooding
- Keep 5-10 cm water

Fertilizer:
- NPK: 100-50-50 kg/ha
- Apply in splits

Pest Management:
- Stem borers, leafhoppers
- Use pesticides judiciously

Harvesting:
- Harvest when 80% grains are straw-colored
- Yield: 4-6 tons/ha
''';

const String potatoInstructions = '''
Soil Preparation:
- Loose, well-drained soil
- pH: 5.5-6.5
- Ridging

Seed Selection and Sowing:
- Use certified seed tubers
- Sowing time: October-November
- Seed rate: 2-3 tons/ha
- Spacing: 60x20 cm

Irrigation:
- Light and frequent
- Avoid waterlogging

Fertilizer:
- NPK: 150-100-100 kg/ha
- Apply at planting and earthing up

Disease Management:
- Late blight, bacterial wilt
- Use fungicides

Harvesting:
- Harvest 90-100 days after planting
- Yield: 20-30 tons/ha
''';

const String maizeInstructionsUrdu = '''
زمین کی تیاری:
- بھربھری اور نکاسی والی زمین رکھیں
- پی ایچ 6.0 تا 7.0 مناسب ہے

بوائی:
- معیاری بیج استعمال کریں
- وقت: جون تا جولائی

آبپاشی:
- پہلی آبپاشی بوائی کے فوراً بعد
- بعد میں 7 تا 10 دن کے وقفے سے

کھاد:
- این پی کے 120-60-40 کلوگرام فی ہیکٹر
''';

const String wheatInstructionsUrdu = '''
زمین کی تیاری:
- ہموار اور نرم زمین رکھیں
- پی ایچ 6.5 تا 7.5 بہتر ہے

بوائی:
- بہتر اقسام کا بیج لیں
- وقت: نومبر تا دسمبر

آبپاشی:
- اہم مراحل پر 4 تا 5 آبپاشیاں

کھاد:
- این پی کے 120-60-40 کلوگرام فی ہیکٹر
''';

const String riceInstructionsUrdu = '''
زمین کی تیاری:
- پانی روکنے والی ہموار زمین تیار کریں

بوائی/منتقلی:
- وقت: جون تا جولائی
- 25 تا 30 دن کی پنیری منتقل کریں

آبپاشی:
- کھیت میں 5 تا 10 سینٹی میٹر پانی برقرار رکھیں

کھاد:
- این پی کے 100-50-50 کلوگرام فی ہیکٹر
''';

const String potatoInstructionsUrdu = '''
زمین کی تیاری:
- نرم اور اچھی نکاسی والی زمین منتخب کریں

بوائی:
- معیاری بیج آلو استعمال کریں
- وقت: اکتوبر تا نومبر

آبپاشی:
- ہلکی مگر بار بار آبپاشی کریں

کھاد:
- این پی کے 150-100-100 کلوگرام فی ہیکٹر
''';

const String maizeInstructionsPunjabi = '''
زمین دی تیاری:
- نرم تے نکاسی والی زمین رکھو
- پی ایچ 6.0 توں 7.0 بہتر اے

بوائی:
- معیاری بیج ورتو
- وقت: جون توں جولائی

پانی:
- پہلی واری فوراً بعدِ بوائی
- پھر 7 توں 10 دن دے وقفے نال

کھاد:
- این پی کے 120-60-40 کلو فی ہیکٹر
''';

const String wheatInstructionsPunjabi = '''
زمین دی تیاری:
- نرم تے ہموار زمین بناؤ
- پی ایچ 6.5 توں 7.5 مناسب اے

بوائی:
- بہتر قسم دا بیج لو
- وقت: نومبر توں دسمبر

پانی:
- اہم مرحلاں تے 4 توں 5 وار

کھاد:
- این پی کے 120-60-40 کلو فی ہیکٹر
''';

const String riceInstructionsPunjabi = '''
زمین دی تیاری:
- پانی روک سکّن والی ہموار زمین رکھو

بوائی/روپائی:
- وقت: جون توں جولائی
- 25 توں 30 دن بعد پنیری لاؤ

پانی:
- کھیت وچ 5 توں 10 سینٹی پانی رکھو

کھاد:
- این پی کے 100-50-50 کلو فی ہیکٹر
''';

const String potatoInstructionsPunjabi = '''
زمین دی تیاری:
- نرم تے نکاسی والی زمین چنو

بوائی:
- معیاری بیج آلو ورتو
- وقت: اکتوبر توں نومبر

پانی:
- ہلکا پر وار وار پانی دیو

کھاد:
- این پی کے 150-100-100 کلو فی ہیکٹر
''';