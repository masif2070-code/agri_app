import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'https://agri-app-backend-6kyx.onrender.com',
);

const double defaultPakistanLat = 30.3753;
const double defaultPakistanLon = 69.3451;
const List<String> deficiencyImageExtensions = <String>['jpg', 'jpeg', 'png'];

void main() {
  runApp(const AgriApp());
}

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Instructions - Pakistan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
            .copyWith(
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
        ),
      ),
      home: const LanguageSelectionScreen(),
    );
  }
}

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Language / زبان منتخب کریں')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please choose your language\nبراہ کرم اپنی زبان منتخب کریں',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SectionChooserScreen(
                                  selectedLanguage: 'English',
                                ),
                              ),
                            );
                          },
                          child: const Text('English'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SectionChooserScreen(
                                  selectedLanguage: 'Urdu',
                                ),
                              ),
                            );
                          },
                          child: const Text('اردو'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionChooserScreen extends StatefulWidget {
  const SectionChooserScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<SectionChooserScreen> createState() => _SectionChooserScreenState();
}

class _SectionChooserScreenState extends State<SectionChooserScreen> {
  bool _loadingWeather = true;
  String? _weatherError;
  double? _temperature;
  double? _windSpeed;
  double _weatherLat = defaultPakistanLat;
  double _weatherLon = defaultPakistanLon;
  String _weatherLocationLabel = 'Pakistan';
  final List<int> _forecastCodes = [];
  final List<double> _forecastMax = [];
  final List<double> _forecastMin = [];
  static const List<Map<String, String>> _fallbackPlantHeadlines = [
    {
      'titleEn':
          'Punjab trials report better wheat stand with late-autumn seed treatment protocol.',
      'titleUr': 'پنجاب ٹرائلز: خزاں کے آخر میں بیج ٹریٹمنٹ سے گندم کا اگاؤ بہتر رپورٹ ہوا۔',
      'source': 'PARC / NARC Updates',
      'url': 'https://parc.gov.pk/',
    },
    {
      'titleEn':
          'Recent rice studies highlight alternate wetting and drying to save water without major yield loss.',
      'titleUr':
          'حالیہ دھان تحقیق: وقفے وقفے سے آبپاشی سے پانی کی بچت، پیداوار میں نمایاں کمی کے بغیر۔',
      'source': 'IRRI Research',
      'url': 'https://www.irri.org/news-and-events',
    },
    {
      'titleEn':
          'Integrated pest monitoring advisories stress field scouting before pesticide application.',
      'titleUr':
          'مربوط پیسٹ مانیٹرنگ ہدایات: اسپرے سے پہلے کھیت کی باقاعدہ اسکاوٹنگ پر زور۔',
      'source': 'FAO Crop News',
      'url': 'https://www.fao.org/newsroom/en/',
    },
  ];
  static const List<Map<String, String>> _fallbackAnimalHeadlines = [
    {
      'titleEn':
          'New dairy nutrition findings emphasize balanced mineral mix during heat stress periods.',
      'titleUr':
          'ڈیری غذائیت کی نئی تحقیق: گرمی کے دباؤ میں متوازن منرل مکس کی اہمیت نمایاں۔',
      'source': 'ILRI News',
      'url': 'https://www.ilri.org/news',
    },
    {
      'titleEn':
          'Field reports show timely deworming and vaccination improve young stock survival.',
      'titleUr':
          'فیلڈ رپورٹس: بروقت ڈی ورمنگ اور ویکسینیشن سے کم عمر جانوروں کی بقا بہتر۔',
      'source': 'FAO Livestock',
      'url': 'https://www.fao.org/livestock/en/',
    },
    {
      'titleEn':
          'Poultry management research recommends stronger ventilation control in seasonal humidity.',
      'titleUr':
          'پولٹری مینجمنٹ تحقیق: موسمی نمی میں بہتر وینٹیلیشن کنٹرول کی سفارش۔',
      'source': 'Poultry World',
      'url': 'https://www.poultryworld.net/',
    },
  ];
  List<Map<String, String>> _plantHeadlines =
      List<Map<String, String>>.from(_fallbackPlantHeadlines);
  List<Map<String, String>> _animalHeadlines =
      List<Map<String, String>>.from(_fallbackAnimalHeadlines);

  static const List<Map<String, String>> _officialGovSources = [
    {
      'labelEn': 'Ministry of National Food Security & Research',
      'labelUr': 'قومی غذائی تحفظ و تحقیق کی وزارت',
      'url': 'https://www.mnfsr.gov.pk/',
    },
    {
      'labelEn': 'Punjab Agriculture Department',
      'labelUr': 'محکمہ زراعت پنجاب',
      'url': 'https://www.agripunjab.gov.pk/',
    },
    {
      'labelEn': 'Punjab Livestock Department',
      'labelUr': 'محکمہ لائیوسٹاک پنجاب',
      'url': 'https://livestock.punjab.gov.pk/',
    },
  ];

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  String _gregorianDateLabel(DateTime now) {
    const weekdaysEn = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    const weekdaysUr = <String>[
      'پیر',
      'منگل',
      'بدھ',
      'جمعرات',
      'جمعہ',
      'ہفتہ',
      'اتوار',
    ];
    const monthsEn = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const monthsUr = <String>[
      'جنوری',
      'فروری',
      'مارچ',
      'اپریل',
      'مئی',
      'جون',
      'جولائی',
      'اگست',
      'ستمبر',
      'اکتوبر',
      'نومبر',
      'دسمبر',
    ];

    final weekday = _isUrdu
        ? weekdaysUr[now.weekday - 1]
        : weekdaysEn[now.weekday - 1];
    final month = _isUrdu ? monthsUr[now.month - 1] : monthsEn[now.month - 1];
    return _isUrdu
        ? 'گریگورین: $weekday، ${now.day} $month ${now.year}'
        : 'Gregorian: $weekday, ${now.day} $month ${now.year}';
  }

  String _desiDateLabel(DateTime now) {
    const startMonthDay = <List<int>>[
      [3, 14],
      [4, 13],
      [5, 14],
      [6, 15],
      [7, 16],
      [8, 16],
      [9, 15],
      [10, 15],
      [11, 14],
      [12, 14],
      [1, 13],
      [2, 13],
    ];
    const monthsEn = <String>[
      'Chet',
      'Vaisakh',
      'Jeth',
      'Harh',
      'Sawan',
      'Bhadon',
      'Assu',
      'Katak',
      'Maghar',
      'Poh',
      'Magh',
      'Phagun',
    ];
    const monthsUr = <String>[
      'چیت',
      'ویساکھ',
      'جیٹھ',
      'ہاڑ',
      'ساون',
      'بھادوں',
      'اسو',
      'کاتک',
      'مگھر',
      'پوہ',
      'ماگھ',
      'پھگن',
    ];

    final useCurrentCycle =
        now.isAfter(DateTime(now.year, 3, 13, 23, 59, 59));
    final cycleStartYear = useCurrentCycle ? now.year : now.year - 1;

    final boundaries = List<DateTime>.generate(12, (index) {
      final month = startMonthDay[index][0];
      final day = startMonthDay[index][1];
      final year = month >= 3 ? cycleStartYear : cycleStartYear + 1;
      return DateTime(year, month, day);
    });

    var monthIndex = 0;
    for (var i = 0; i < boundaries.length; i++) {
      final isLast = i == boundaries.length - 1;
      final current = boundaries[i];
      final next = isLast ? DateTime(cycleStartYear + 1, 3, 14) : boundaries[i + 1];
      if ((now.isAtSameMomentAs(current) || now.isAfter(current)) && now.isBefore(next)) {
        monthIndex = i;
        break;
      }
    }

    final start = boundaries[monthIndex];
    final dayNo = now.difference(start).inDays + 1;
    final monthName = _isUrdu ? monthsUr[monthIndex] : monthsEn[monthIndex];
    return _isUrdu ? 'دیسی: $dayNo $monthName' : 'Desi: $dayNo $monthName';
  }

  String _hijriDateLabel(DateTime now) {
    final localDate = DateTime(now.year, now.month, now.day);

    // Gregorian to Julian day number.
    final a = (14 - localDate.month) ~/ 12;
    final y = localDate.year + 4800 - a;
    final m = localDate.month + 12 * a - 3;
    final jd =
        localDate.day +
        ((153 * m + 2) ~/ 5) +
        365 * y +
        (y ~/ 4) -
        (y ~/ 100) +
        (y ~/ 400) -
        32045;

    // Civil/tabular Hijri conversion (approximation).
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j =
        (((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719)) +
        ((l ~/ 5670) * ((43 * l) ~/ 15238));
    l =
        l -
        (((30 - j) ~/ 15) * ((17719 * j) ~/ 50)) -
        ((j ~/ 16) * ((15238 * j) ~/ 43)) +
        29;
    final hijriMonth = (24 * l) ~/ 709;
    final hijriDay = l - (709 * hijriMonth) ~/ 24;
    final hijriYear = 30 * n + j - 30;

    const monthsEn = <String>[
      'Muharram',
      'Safar',
      'Rabi al-Awwal',
      'Rabi al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Shaban',
      'Ramadan',
      'Shawwal',
      'Dhul Qadah',
      'Dhul Hijjah',
    ];
    const monthsUr = <String>[
      'محرم',
      'صفر',
      'ربیع الاول',
      'ربیع الثانی',
      'جمادی الاول',
      'جمادی الثانی',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذوالقعدہ',
      'ذوالحجہ',
    ];

    final monthName = _isUrdu
        ? monthsUr[(hijriMonth.clamp(1, 12)) - 1]
        : monthsEn[(hijriMonth.clamp(1, 12)) - 1];
    return _isUrdu
        ? 'ہجری: $hijriDay $monthName $hijriYear'
        : 'Hijri: $hijriDay $monthName $hijriYear AH';
  }

  Map<String, String>? _headlineFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final titleEn = (raw['title_en'] as String?)?.trim() ?? '';
    final titleUr = (raw['title_ur'] as String?)?.trim() ?? '';
    final source = (raw['source'] as String?)?.trim() ?? '';
    final url = (raw['url'] as String?)?.trim() ?? '';
    if (titleEn.isEmpty || source.isEmpty || url.isEmpty) {
      return null;
    }
    return {
      'titleEn': titleEn,
      'titleUr': titleUr.isNotEmpty ? titleUr : titleEn,
      'source': source,
      'url': url,
    };
  }

  Future<void> _fetchFarmerHeadlines() async {
    try {
      final uri = Uri.parse('$backendBaseUrl/farmer-headlines');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final plantItems =
          ((data['plant_headlines'] as List<dynamic>?) ?? <dynamic>[])
              .map(_headlineFromJson)
              .whereType<Map<String, String>>()
              .toList();
      final animalItems =
          ((data['animal_headlines'] as List<dynamic>?) ?? <dynamic>[])
              .map(_headlineFromJson)
              .whereType<Map<String, String>>()
              .toList();

      if (!mounted) return;
      setState(() {
        if (plantItems.isNotEmpty) {
          _plantHeadlines = plantItems;
        }
        if (animalItems.isNotEmpty) {
          _animalHeadlines = animalItems;
        }
      });
    } catch (_) {
      // Keep fallback headlines if backend is unavailable.
    }
  }

  Future<void> _openHeadlineLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Invalid headline link', 'ہیڈلائن لنک درست نہیں ہے')),
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Could not open headline link', 'ہیڈلائن لنک نہیں کھل سکا')),
        ),
      );
    }
  }

  Widget _disclaimerBanner() {
    return GestureDetector(
      onTap: () => _launchDisclaimerPage(),
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFFF57F17)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(
                  'Tap for government disclaimer & sources',
                  'حکومتی دستبرداری اور ذرائع کے لیے ٹیپ کریں',
                ),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchDisclaimerPage() {
    final disclaimerUrl = 'https://masif2070-code.github.io/agri_app/disclaimer.html';
    launchUrl(Uri.parse(disclaimerUrl), mode: LaunchMode.externalApplication).catchError((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Could not open disclaimer page', 'دستبرداری صفحہ کھول نہیں سکے')),
        ),
      );
    });
  }

  Widget _headlineTile(Map<String, String> item) {
    return InkWell(
      onTap: () => _openHeadlineLink(item['url'] ?? ''),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.fiber_manual_record, size: 8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isUrdu ? (item['titleUr'] ?? '') : (item['titleEn'] ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['source'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 14, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTopWeather(lat: _weatherLat, lon: _weatherLon);
    _fetchFarmerHeadlines();
  }

  IconData _weatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny;
    }
    if (code == 1 || code == 2) {
      return Icons.wb_cloudy;
    }
    if (code == 3 || code == 45 || code == 48) {
      return Icons.cloud;
    }
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.grain;
    }
    if (code >= 71 && code <= 77) {
      return Icons.ac_unit;
    }
    if (code >= 95) {
      return Icons.thunderstorm;
    }
    return Icons.cloud;
  }

  String _weatherConditionText(int code) {
    if (code == 0) return _t('Sunny', 'دھوپ');
    if (code == 1 || code == 2) return _t('Partly Cloudy', 'جزوی ابر آلود');
    if (code == 3 || code == 45 || code == 48) return _t('Cloudy', 'ابر آلود');
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return _t('Rain', 'بارش');
    }
    if (code >= 71 && code <= 77) return _t('Snow', 'برف');
    if (code >= 95) return _t('Storm', 'طوفان');
    return _t('Cloudy', 'ابر آلود');
  }

  String _forecastDayLabel(int index) {
    switch (index) {
      case 0:
        return _t('Today', 'آج');
      case 1:
        return _t('Tomorrow', 'کل');
      default:
        return _t('Day 3', 'تیسرا دن');
    }
  }

  Future<void> _useCurrentLocationWeather() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _weatherError = _t(
            'Location service is disabled.',
            'لوکیشن سروس بند ہے۔',
          );
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _weatherError = _t(
            'Location permission was not granted.',
            'لوکیشن کی اجازت نہیں ملی۔',
          );
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _weatherLat = pos.latitude;
        _weatherLon = pos.longitude;
        _weatherLocationLabel = _t('My Location', 'میری لوکیشن');
      });
      await _fetchTopWeather(lat: _weatherLat, lon: _weatherLon);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = _t(
          'Unable to fetch your location weather.',
          'آپ کی لوکیشن کا موسم حاصل نہیں ہو سکا۔',
        );
      });
    }
  }

  Future<void> _fetchTopWeather({
    required double lat,
    required double lon,
  }) async {
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
    });

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&forecast_days=3&timezone=Asia%2FKarachi',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Weather fetch failed (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current_weather'] as Map<String, dynamic>?;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (current == null || daily == null) {
        throw Exception('Weather data missing');
      }
      final codes = (daily['weathercode'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList();
      final maxTemps = (daily['temperature_2m_max'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final minTemps = (daily['temperature_2m_min'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      if (!mounted) return;
      setState(() {
        _temperature = (current['temperature'] as num?)?.toDouble();
        _windSpeed = (current['windspeed'] as num?)?.toDouble();
        _forecastCodes
          ..clear()
          ..addAll(codes.take(3));
        _forecastMax
          ..clear()
          ..addAll(maxTemps.take(3));
        _forecastMin
          ..clear()
          ..addAll(minTemps.take(3));
        _loadingWeather = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = _t(
          'Unable to load weather right now.',
          'اس وقت موسم لوڈ نہیں ہو سکا۔',
        );
        _loadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(_t('Agrology - Sections', 'ایگرولوجی - حصے'))),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.calendar_month,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _t('Date', 'تاریخ'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _gregorianDateLabel(now),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _desiDateLabel(now),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _hijriDateLabel(now),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _t('Weather', 'موسم'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _fetchTopWeather(
                                    lat: _weatherLat,
                                    lon: _weatherLon,
                                  ),
                                  icon: const Icon(Icons.refresh),
                                  tooltip: _t(
                                    'Refresh weather',
                                    'موسم ریفریش کریں',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final sideBySide = constraints.maxWidth >= 430;

                                final weatherPane = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(
                                        'Location: $_weatherLocationLabel',
                                        'مقام: $_weatherLocationLabel',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _useCurrentLocationWeather,
                                          icon: const Icon(Icons.my_location),
                                          label: Text(
                                            _t(
                                              'Use My Location',
                                              'میری لوکیشن استعمال کریں',
                                            ),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _weatherLat = defaultPakistanLat;
                                              _weatherLon = defaultPakistanLon;
                                              _weatherLocationLabel = _t(
                                                'Pakistan (default)',
                                                'پاکستان (ڈیفالٹ)',
                                              );
                                            });
                                            _fetchTopWeather(
                                              lat: _weatherLat,
                                              lon: _weatherLon,
                                            );
                                          },
                                          icon: const Icon(Icons.location_city),
                                          label: Text(
                                            _t(
                                              'Use Pakistan Default',
                                              'پاکستان ڈیفالٹ استعمال کریں',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (_loadingWeather)
                                      Text(
                                        _t(
                                          'Loading weather...',
                                          'موسم لوڈ ہو رہا ہے...',
                                        ),
                                      )
                                    else if (_weatherError != null)
                                      Text(
                                        _weatherError!,
                                        style: const TextStyle(color: Colors.red),
                                      )
                                    else
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _t(
                                              'Current: ${_temperature?.toStringAsFixed(1) ?? '--'}°C, Wind: ${_windSpeed?.toStringAsFixed(1) ?? '--'} km/h',
                                              'موجودہ: ${_temperature?.toStringAsFixed(1) ?? '--'}°C، ہوا: ${_windSpeed?.toStringAsFixed(1) ?? '--'} کلومیٹر/گھنٹہ',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: List.generate(
                                              _forecastCodes.length,
                                              (index) {
                                                return Expanded(
                                                  child: Card(
                                                    margin: EdgeInsets.only(
                                                      right:
                                                          index <
                                                              _forecastCodes
                                                                      .length -
                                                                  1
                                                          ? 6
                                                          : 0,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 6,
                                                          ),
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            _forecastDayLabel(
                                                              index,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Icon(
                                                            _weatherIcon(
                                                              _forecastCodes[index],
                                                            ),
                                                            size: 24,
                                                            color:
                                                                Colors.orange
                                                                    .shade700,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            _weatherConditionText(
                                                              _forecastCodes[index],
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                ),
                                                            textAlign:
                                                                TextAlign.center,
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            '${_forecastMax[index].toStringAsFixed(0)}° / ${_forecastMin[index].toStringAsFixed(0)}°',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _t(
                                        '3-day weather is shown before entering Crop or Animal sections.',
                                        'فصل یا جانور سیکشن میں جانے سے پہلے 3 دن کا موسم دکھایا جا رہا ہے۔',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                );

                                final headlinesPane = Container(
                                  margin: EdgeInsets.only(
                                    left: sideBySide ? 10 : 0,
                                    top: sideBySide ? 0 : 10,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t(
                                          'Farmer Headlines',
                                          'کسانوں کی ہیڈلائنز',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      _disclaimerBanner(),
                                      const SizedBox(height: 4),
                                      Text(
                                        _t(
                                          'Plant research',
                                          'پودوں کی تحقیق',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      ..._plantHeadlines
                                          .take(2)
                                          .map(_headlineTile),
                                      const SizedBox(height: 4),
                                      Text(
                                        _t(
                                          'Animal research',
                                          'جانوروں کی تحقیق',
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      ..._animalHeadlines
                                          .take(2)
                                          .map(_headlineTile),
                                    ],
                                  ),
                                );

                                if (sideBySide) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 6, child: weatherPane),
                                      Expanded(flex: 5, child: headlinesPane),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [weatherPane, headlinesPane],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('Choose a section', 'سیکشن منتخب کریں'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            ExpansionTile(
                              leading: const Icon(Icons.agriculture),
                              title: Text(_t('Crop Section', 'فصل سیکشن')),
                              subtitle: Text(
                                _t(
                                  'GIS field analysis and crop instructions',
                                  'GIS فیلڈ تجزیہ اور فصل ہدایات',
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HomeScreen(
                                            initialLanguage:
                                                widget.selectedLanguage,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(
                                      _t(
                                        'Open Crop Section',
                                        'فصل سیکشن کھولیں',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                            ExpansionTile(
                              leading: const Icon(Icons.pets),
                              title: Text(_t('Animal Section', 'جانور سیکشن')),
                              subtitle: Text(
                                _t(
                                  'Livestock and pet care guidance',
                                  'مویشی اور پالتو دیکھ بھال رہنمائی',
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E88E5),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AnimalSectionScreen(
                                            selectedLanguage:
                                                widget.selectedLanguage,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(
                                      _t(
                                        'Open Animal Section',
                                        'جانور سیکشن کھولیں',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                            ExpansionTile(
                              leading: const Icon(Icons.campaign),
                              title: Text(
                                _t('Farmer Headlines', 'کسان ہیڈلائنز'),
                              ),
                              subtitle: Text(
                                _t(
                                  'Research and market news updates',
                                  'تحقیقی اور مارکیٹ نیوز اپڈیٹس',
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00695C),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FarmerHeadlinesScreen(
                                            selectedLanguage:
                                                widget.selectedLanguage,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(
                                      _t(
                                        'Open Farmer Headlines',
                                        'کسان ہیڈلائنز کھولیں',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                            ExpansionTile(
                              leading: const Icon(Icons.price_change),
                              title: Text(
                                _t('Commodity Prices', 'کموڈیٹی قیمتیں'),
                              ),
                              subtitle: Text(
                                _t(
                                  'Fertilizer, wheat/rice, and gold rates',
                                  'کھاد، گندم/چاول، اور سونے کی قیمتیں',
                                ),
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6A1B9A),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CommodityPricesScreen(
                                            selectedLanguage:
                                                widget.selectedLanguage,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: Text(
                                      _t(
                                        'Open Commodity Prices',
                                        'کموڈیٹی قیمتیں کھولیں',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FarmerHeadlinesScreen extends StatefulWidget {
  const FarmerHeadlinesScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<FarmerHeadlinesScreen> createState() => _FarmerHeadlinesScreenState();
}

class _FarmerHeadlinesScreenState extends State<FarmerHeadlinesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, String>> _plantHeadlines = [];
  List<Map<String, String>> _animalHeadlines = [];

  static const List<Map<String, String>> _officialGovSources = [
    {
      'labelEn': 'Ministry of National Food Security & Research',
      'labelUr': 'قومی غذائی تحفظ و تحقیق کی وزارت',
      'url': 'https://www.mnfsr.gov.pk/',
    },
    {
      'labelEn': 'Punjab Agriculture Department',
      'labelUr': 'محکمہ زراعت پنجاب',
      'url': 'https://www.agripunjab.gov.pk/',
    },
    {
      'labelEn': 'Punjab Livestock Department',
      'labelUr': 'محکمہ لائیوسٹاک پنجاب',
      'url': 'https://livestock.punjab.gov.pk/',
    },
  ];

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  Map<String, String>? _headlineFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final titleEn = (raw['title_en'] as String?)?.trim() ?? '';
    final titleUr = (raw['title_ur'] as String?)?.trim() ?? '';
    final source = (raw['source'] as String?)?.trim() ?? '';
    final url = (raw['url'] as String?)?.trim() ?? '';
    if (titleEn.isEmpty || source.isEmpty || url.isEmpty) {
      return null;
    }
    return {
      'titleEn': titleEn,
      'titleUr': titleUr.isNotEmpty ? titleUr : titleEn,
      'source': source,
      'url': url,
    };
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid link', 'غلط لنک'))),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Could not open link', 'لنک نہیں کھل سکا'))),
      );
    }
  }

  Widget _disclaimerBanner() {
    return GestureDetector(
      onTap: () => _launchDisclaimerPage(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: Color(0xFFF57F17)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t(
                  'Tap for government disclaimer & sources',
                  'حکومتی دستبرداری اور ذرائع کے لیے ٹیپ کریں',
                ),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchDisclaimerPage() {
    final disclaimerUrl = 'https://masif2070-code.github.io/agri_app/disclaimer.html';
    launchUrl(Uri.parse(disclaimerUrl), mode: LaunchMode.externalApplication).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Could not open disclaimer page', 'دستبرداری صفحہ کھول نہیں سکے')),
          ),
        );
      }
    });
  }


  Future<void> _loadHeadlines() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$backendBaseUrl/farmer-headlines');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Headlines fetch failed (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final plant = ((data['plant_headlines'] as List<dynamic>?) ?? <dynamic>[])
          .map(_headlineFromJson)
          .whereType<Map<String, String>>()
          .toList();
      final animal = ((data['animal_headlines'] as List<dynamic>?) ?? <dynamic>[])
          .map(_headlineFromJson)
          .whereType<Map<String, String>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _plantHeadlines = plant;
        _animalHeadlines = animal;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('Unable to load headlines right now.', 'ہیڈلائنز لوڈ نہیں ہو سکیں۔');
        _loading = false;
      });
    }
  }

  Widget _headlineTile(Map<String, String> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(_isUrdu ? (item['titleUr'] ?? '') : (item['titleEn'] ?? '')),
        subtitle: Text(item['source'] ?? ''),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openLink(item['url'] ?? ''),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHeadlines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Farmer Headlines', 'کسان ہیڈلائنز')),
        actions: [
          IconButton(
            onPressed: _loadHeadlines,
            icon: const Icon(Icons.refresh),
            tooltip: _t('Refresh', 'ریفریش'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: _loading
            ? Center(child: Text(_t('Loading headlines...', 'ہیڈلائنز لوڈ ہو رہی ہیں...')))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _disclaimerBanner(),
                  const SizedBox(height: 8),
                  Text(
                    _t('Plant Research & News', 'پودوں کی تحقیق اور خبریں'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._plantHeadlines.map(_headlineTile),
                  const SizedBox(height: 10),
                  Text(
                    _t('Animal Research & News', 'جانوروں کی تحقیق اور خبریں'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._animalHeadlines.map(_headlineTile),
                ],
              ),
      ),
    );
  }
}

class CommodityPricesScreen extends StatefulWidget {
  const CommodityPricesScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<CommodityPricesScreen> createState() => _CommodityPricesScreenState();
}

class _CommodityPricesScreenState extends State<CommodityPricesScreen> {
  bool _loading = true;
  String? _error;
  String _updatedOn = '';
  String _regionEn = '';
  String _regionUr = '';
  String _sourceNoteEn = '';
  String _sourceNoteUr = '';
  String _disclaimerEn = '';
  String _disclaimerUr = '';
  List<Map<String, dynamic>> _items = [];

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  Map<String, dynamic>? _priceItemFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return {
      'titleEn': (raw['title_en'] as String?)?.trim() ?? '',
      'titleUr': (raw['title_ur'] as String?)?.trim() ?? '',
      'unitEn': (raw['unit_en'] as String?)?.trim() ?? '',
      'unitUr': (raw['unit_ur'] as String?)?.trim() ?? '',
      'noteEn': (raw['note_en'] as String?)?.trim() ?? '',
      'noteUr': (raw['note_ur'] as String?)?.trim() ?? '',
      'price': (raw['price_pkr'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<void> _loadCommodityPrices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$backendBaseUrl/commodity-prices');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Commodity prices fetch failed (${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = ((data['items'] as List<dynamic>?) ?? <dynamic>[])
          .map(_priceItemFromJson)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _updatedOn = (data['updated_on'] as String?) ?? '';
        _regionEn = (data['market_region_en'] as String?) ?? '';
        _regionUr = (data['market_region_ur'] as String?) ?? '';
        _sourceNoteEn = (data['source_note_en'] as String?) ?? '';
        _sourceNoteUr = (data['source_note_ur'] as String?) ?? '';
        _disclaimerEn = (data['disclaimer_en'] as String?) ?? '';
        _disclaimerUr = (data['disclaimer_ur'] as String?) ?? '';
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('Unable to load commodity prices right now.', 'قیمتیں اس وقت لوڈ نہیں ہو سکیں۔');
        _loading = false;
      });
    }
  }

  String _formatPkr(double value) {
    return value.toStringAsFixed(0);
  }

  @override
  void initState() {
    super.initState();
    _loadCommodityPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Commodity Prices', 'کموڈیٹی قیمتیں')),
        actions: [
          IconButton(
            onPressed: _loadCommodityPrices,
            icon: const Icon(Icons.refresh),
            tooltip: _t('Refresh', 'ریفریش'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: _loading
            ? Center(child: Text(_t('Loading prices...', 'قیمتیں لوڈ ہو رہی ہیں...')))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isUrdu ? _regionUr : _regionEn,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _t('Updated: $_updatedOn', 'اپڈیٹ: $_updatedOn'),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._items.map((item) {
                    return Card(
                      child: ListTile(
                        title: Text(_isUrdu ? item['titleUr'] as String : item['titleEn'] as String),
                        subtitle: Text(
                          '${_isUrdu ? item['unitUr'] as String : item['unitEn'] as String}\n${_isUrdu ? item['noteUr'] as String : item['noteEn'] as String}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          'PKR ${_formatPkr(item['price'] as double)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_isUrdu ? _sourceNoteUr : _sourceNoteEn),
                          const SizedBox(height: 6),
                          Text(
                            _isUrdu ? _disclaimerUr : _disclaimerEn,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AnimalSectionScreen extends StatefulWidget {
  const AnimalSectionScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<AnimalSectionScreen> createState() => _AnimalSectionScreenState();
}

class _AnimalSectionScreenState extends State<AnimalSectionScreen> {
  String _animalCategory = 'livestock';
  String _petCategory = 'dog';
  final Map<String, Map<String, bool>> _petSectionExpanded = {
    'dog': {
      'breeds': false,
      'young': false,
      'vaccine': false,
      'disease': false,
    },
    'cats': {
      'breeds': false,
      'young': false,
      'vaccine': false,
      'disease': false,
    },
    'birds': {
      'breeds': false,
      'young': false,
      'vaccine': false,
      'disease': false,
    },
  };

  Future<void> _openSourceLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Invalid source link', 'غلط سورس لنک'))),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Could not open source link', 'سورس لنک نہیں کھل سکا'))),
      );
    }
  }

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';

  String _t(String en, String ur) => _isUrdu ? ur : en;

  bool _isPetSectionExpanded(String sectionKey) {
    return _petSectionExpanded[_petCategory]?[sectionKey] ?? false;
  }

  void _setPetSectionExpanded(String sectionKey, bool expanded) {
    _petSectionExpanded[_petCategory] ??= {
      'breeds': false,
      'young': false,
      'vaccine': false,
      'disease': false,
    };
    _petSectionExpanded[_petCategory]![sectionKey] = expanded;
  }

  List<Widget> _livestockCards(BuildContext context) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Meat Section', 'گوشت سیکشن'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'For fattening, growth, feed conversion, and market-weight planning.',
                  'موٹاپا، نشوونما، فیڈ کنورژن، اور مارکیٹ وزن کی منصوبہ بندی کے لیے۔',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MeatSectionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.set_meal),
                  label: Text(_t('Open Meat Section', 'گوشت سیکشن کھولیں')),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Milk Section', 'دودھ سیکشن'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'For dairy management, milk yield optimization, and lactation planning.',
                  'ڈیری مینجمنٹ، دودھ کی پیداوار بہتر بنانے، اور لیکٹیشن پلاننگ کے لیے۔',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MilkSectionScreen(
                          selectedLanguage: widget.selectedLanguage,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.water_drop),
                  label: Text(_t('Open Milk Section', 'دودھ سیکشن کھولیں')),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Breeding Section', 'بریڈنگ سیکشن'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'For breed selection, sire recommendations, and breeding planning.',
                  'نسل کے انتخاب، سانڈ تجاویز، اور بریڈنگ پلاننگ کے لیے۔',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BreedingSectionScreen(
                          selectedLanguage: widget.selectedLanguage,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.hub),
                  label: Text(_t('Open Breeding Section', 'بریڈنگ سیکشن کھولیں')),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Health Section', 'صحت سیکشن'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'For vaccination schedules, deworming reminders, and basic disease prevention guidance.',
                  'ویکسین شیڈول، کیڑے مار یاد دہانیوں، اور بنیادی بیماری سے بچاؤ رہنمائی کے لیے۔',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HealthSectionScreen(
                          selectedLanguage: widget.selectedLanguage,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.health_and_safety),
                  label: Text(_t('Open Health Section', 'صحت سیکشن کھولیں')),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Map<String, String> _youngPetCare(String petCategory) {
    switch (petCategory) {
      case 'dog':
        return {
          'titleEn': 'Care for young dog',
          'titleUr': 'چھوٹے کتے کی دیکھ بھال',
          'bodyEn':
              'Keep puppies warm and dry, feed age-appropriate puppy starter diet, provide clean drinking water, deworm on schedule, and start gentle socialization early.',
          'bodyUr':
              'چھوٹے کتوں کو گرم اور خشک رکھیں، عمر کے مطابق خوراک دیں، صاف پانی مہیا کریں، وقت پر ڈی ورمنگ کریں، اور ابتدا ہی سے نرم انداز میں سماجی تربیت شروع کریں۔',
        };
      case 'cats':
        return {
          'titleEn': 'Care for young cat',
          'titleUr': 'چھوٹی بلی کی دیکھ بھال',
          'bodyEn':
              'Keep kittens warm, feed kitten diet in small frequent meals, maintain litter hygiene, check for fleas/worms, and avoid sudden diet changes.',
          'bodyUr':
              'بلی کے بچوں کو گرم رکھیں، تھوڑی تھوڑی مقدار میں بار بار خوراک دیں، لیٹر کی صفائی رکھیں، پسو اور کیڑوں کی جانچ کریں، اور خوراک میں اچانک تبدیلی نہ کریں۔',
        };
      case 'birds':
        return {
          'titleEn': 'Care for young bird',
          'titleUr': 'چھوٹے پرندے کی دیکھ بھال',
          'bodyEn':
              'Keep chicks or young birds in a warm draft-free place, give fresh clean water, provide species-appropriate starter feed, and keep cage or nest area very clean.',
          'bodyUr':
              'بچوں یا کم عمر پرندوں کو گرم اور ہوا کے جھونکوں سے محفوظ جگہ پر رکھیں، تازہ صاف پانی دیں، مناسب ابتدائی خوراک مہیا کریں، اور پنجرہ یا گھونسلہ اچھی طرح صاف رکھیں۔',
        };
      default:
        return {
          'titleEn': 'Care for young pet',
          'titleUr': 'کم عمر پالتو کی دیکھ بھال',
          'bodyEn': 'Provide warmth, clean feed, water, and timely veterinary care.',
          'bodyUr': 'گرمی، صاف خوراک، پانی، اور وقت پر ویٹرنری دیکھ بھال فراہم کریں۔',
        };
    }
  }

  List<Map<String, String>> _petVaccinePlan(String petCategory) {
    switch (petCategory) {
      case 'dog':
        return const [
          {
            'stageEn': '6-8 weeks',
            'stageUr': '6-8 ہفتے',
            'detailEn': 'First core puppy vaccine (DHPP or equivalent) and deworming.',
            'detailUr': 'پہلا بنیادی پپی ویکسین (DHPP یا مساوی) اور ڈی ورمنگ۔',
          },
          {
            'stageEn': '10-12 weeks',
            'stageUr': '10-12 ہفتے',
            'detailEn': 'Booster core vaccine and parasite control.',
            'detailUr': 'بوسٹر بنیادی ویکسین اور پیراسائٹ کنٹرول۔',
          },
          {
            'stageEn': '14-16 weeks',
            'stageUr': '14-16 ہفتے',
            'detailEn': 'Final puppy booster and rabies vaccine as advised locally.',
            'detailUr': 'آخری پپی بوسٹر اور مقامی ہدایت کے مطابق ریبیز ویکسین۔',
          },
          {
            'stageEn': 'Annual',
            'stageUr': 'سالانہ',
            'detailEn': 'Yearly booster and rabies renewal according to vet advice.',
            'detailUr': 'ویٹ کے مشورے کے مطابق سالانہ بوسٹر اور ریبیز تجدید۔',
          },
        ];
      case 'cats':
        return const [
          {
            'stageEn': '6-8 weeks',
            'stageUr': '6-8 ہفتے',
            'detailEn': 'First FVRCP vaccine and deworming.',
            'detailUr': 'پہلا FVRCP ویکسین اور ڈی ورمنگ۔',
          },
          {
            'stageEn': '10-12 weeks',
            'stageUr': '10-12 ہفتے',
            'detailEn': 'FVRCP booster and parasite control.',
            'detailUr': 'FVRCP بوسٹر اور پیراسائٹ کنٹرول۔',
          },
          {
            'stageEn': '14-16 weeks',
            'stageUr': '14-16 ہفتے',
            'detailEn': 'Rabies vaccine and final kitten booster if required.',
            'detailUr': 'ریبیز ویکسین اور ضرورت کے مطابق آخری کٹن بوسٹر۔',
          },
          {
            'stageEn': 'Annual',
            'stageUr': 'سالانہ',
            'detailEn': 'Annual booster and routine checkup.',
            'detailUr': 'سالانہ بوسٹر اور معمول کا معائنہ۔',
          },
        ];
      case 'birds':
        return const [
          {
            'stageEn': 'Early age',
            'stageUr': 'ابتدائی عمر',
            'detailEn': 'Consult local avian vet because bird vaccine schedules vary by species and region.',
            'detailUr': 'مقامی ایویئن ویٹ سے مشورہ کریں کیونکہ پرندوں کی ویکسین نسل اور علاقے کے مطابق مختلف ہوتی ہے۔',
          },
          {
            'stageEn': 'Growing stage',
            'stageUr': 'نشوونما کا مرحلہ',
            'detailEn': 'Maintain hygiene, parasite prevention, and any recommended regional vaccines.',
            'detailUr': 'صفائی، پیراسائٹ بچاؤ، اور تجویز کردہ مقامی ویکسین برقرار رکھیں۔',
          },
          {
            'stageEn': 'Annual',
            'stageUr': 'سالانہ',
            'detailEn': 'Health check, stool check, and any booster recommended for the species.',
            'detailUr': 'ہیلتھ چیک، اسٹول چیک، اور نسل کے مطابق تجویز کردہ بوسٹر۔',
          },
        ];
      default:
        return const [];
    }
  }

  List<Map<String, String>> _petDiseaseGuide(String petCategory) {
    switch (petCategory) {
      case 'dog':
        return const [
          {
            'diseaseEn': 'Parvovirus',
            'diseaseUr': 'پاروو وائرس',
            'treatmentEn': 'Urgent vet care, fluids, isolation, anti-vomiting treatment, and strict hygiene.',
            'treatmentUr': 'فوری ویٹ علاج، فلوئڈز، علیحدگی، قے روکنے کا علاج، اور سخت صفائی۔',
          },
          {
            'diseaseEn': 'Distemper',
            'diseaseUr': 'ڈسٹیمپر',
            'treatmentEn': 'Supportive vet treatment, isolation, fever control, and nutrition support.',
            'treatmentUr': 'سپورٹو ویٹ علاج، علیحدگی، بخار کنٹرول، اور غذائی سپورٹ۔',
          },
          {
            'diseaseEn': 'Mange / skin mites',
            'diseaseUr': 'مینج / جلدی کیڑے',
            'treatmentEn': 'Vet-prescribed anti-parasitic treatment, skin care, and bedding hygiene.',
            'treatmentUr': 'ویٹ کے مشورے سے اینٹی پیراسائٹ علاج، جلد کی دیکھ بھال، اور بستر کی صفائی۔',
          },
        ];
      case 'cats':
        return const [
          {
            'diseaseEn': 'Cat flu',
            'diseaseUr': 'کیٹ فلو',
            'treatmentEn': 'Supportive care, hydration, eye/nose cleaning, and vet-prescribed medicines.',
            'treatmentUr': 'سپورٹو کیئر، پانی کی فراہمی، آنکھ/ناک صفائی، اور ویٹ کی دی گئی دوائیں۔',
          },
          {
            'diseaseEn': 'Feline panleukopenia',
            'diseaseUr': 'فیلائن پین لیوکوپینیا',
            'treatmentEn': 'Emergency vet treatment, fluids, isolation, and sanitation.',
            'treatmentUr': 'ایمرجنسی ویٹ علاج، فلوئڈز، علیحدگی، اور صفائی۔',
          },
          {
            'diseaseEn': 'Ringworm / fungal skin disease',
            'diseaseUr': 'داد / فنگس جلدی بیماری',
            'treatmentEn': 'Antifungal treatment, environment cleaning, and isolation if needed.',
            'treatmentUr': 'اینٹی فنگل علاج، ماحول کی صفائی، اور ضرورت پر علیحدگی۔',
          },
        ];
      case 'birds':
        return const [
          {
            'diseaseEn': 'Respiratory infection',
            'diseaseUr': 'سانس کی انفیکشن',
            'treatmentEn': 'Warm cage, reduced stress, prompt avian vet consultation, and prescribed treatment.',
            'treatmentUr': 'گرم پنجرہ، کم دباؤ، فوری ایویئن ویٹ مشورہ، اور تجویز کردہ علاج۔',
          },
          {
            'diseaseEn': 'Coccidiosis / intestinal infection',
            'diseaseUr': 'کوکسڈیوسس / آنتوں کی انفیکشن',
            'treatmentEn': 'Clean housing, fresh water, stool testing, and targeted medicine from vet.',
            'treatmentUr': 'صاف رہائش، تازہ پانی، اسٹول ٹیسٹ، اور ویٹ کی دی گئی مخصوص دوا۔',
          },
          {
            'diseaseEn': 'External parasites',
            'diseaseUr': 'بیرونی پیراسائٹس',
            'treatmentEn': 'Cage disinfection, parasite control, and vet-approved anti-parasitic treatment.',
            'treatmentUr': 'پنجرہ جراثیم کشی، پیراسائٹ کنٹرول، اور ویٹ سے منظور شدہ اینٹی پیراسائٹ علاج۔',
          },
        ];
      default:
        return const [];
    }
  }

  List<Widget> _petsCards() {
    final petTitle = switch (_petCategory) {
      'dog' => _t('Dog', 'کتا'),
      'cats' => _t('Cats', 'بلیاں'),
      'birds' => _t('Birds', 'پرندے'),
      _ => _t('Dog', 'کتا'),
    };

    final petDescription = switch (_petCategory) {
      'dog' => _t(
          'Dog care features like feeding schedule, vaccination reminders, and basic health guidance will be added here.',
          'کتے کی دیکھ بھال کی خصوصیات جیسے خوراک شیڈول، ویکسین یاد دہانی اور بنیادی صحت رہنمائی یہاں شامل کی جائیں گی۔'),
      'cats' => _t(
          'Cat care features like nutrition plans, vaccination reminders, and hygiene tips will be added here.',
          'بلی کی دیکھ بھال کی خصوصیات جیسے غذائی پلان، ویکسین یاد دہانی اور صفائی کے مشورے یہاں شامل کیے جائیں گے۔'),
      'birds' => _t(
          'Bird care features like feed plans, cage hygiene guidance, and vaccination reminders will be added here.',
          'پرندوں کی دیکھ بھال کی خصوصیات جیسے خوراک پلان، پنجرہ صفائی رہنمائی اور ویکسین یاد دہانی یہاں شامل کی جائیں گی۔'),
      _ => _t(
          'Dog care features like feeding schedule, vaccination reminders, and basic health guidance will be added here.',
          'کتے کی دیکھ بھال کی خصوصیات جیسے خوراک شیڈول، ویکسین یاد دہانی اور بنیادی صحت رہنمائی یہاں شامل کی جائیں گی۔'),
    };

    final petIcon = switch (_petCategory) {
      'dog' => Icons.pets,
      'cats' => Icons.cruelty_free,
      'birds' => Icons.flutter_dash,
      _ => Icons.pets,
    };

    final famousListTitle = _petCategory == 'birds'
        ? _t('Famous bird pets', 'مشہور پالتو پرندے')
        : _t('Famous breeds', 'مشہور نسلیں');

    final birdSpecies = const <Map<String, Object>>[
      {
        'speciesEn': 'Pigeon',
        'speciesUr': 'کبوتر',
        'lineEn':
            'Calm, home-oriented, and known for strong navigation and flock bonding.',
        'lineUr':
            'پرسکون، گھر سے مانوس، اور مضبوط راستہ شناسی و غول کے ساتھ وابستگی رکھنے والا۔',
        'breedsEn': ['Homing Pigeon', 'Fantail', 'Lahore Pigeon'],
        'breedsUr': ['ہومنگ کبوتر', 'فین ٹیل', 'لاہوری کبوتر'],
      },
      {
        'speciesEn': 'Budgerigar (Budgie)',
        'speciesUr': 'بجریگر (بجی)',
        'lineEn': 'Active, social, and responds well to daily interaction.',
        'lineUr': 'متحرک، ملنسار، اور روزانہ توجہ پر اچھا ردعمل دینے والا۔',
        'breedsEn': ['English Budgie', 'American Budgie', 'Rainbow Budgie'],
        'breedsUr': ['انگلش بجی', 'امریکن بجی', 'رینبو بجی'],
      },
      {
        'speciesEn': 'Cockatiel',
        'speciesUr': 'کاکاٹیل',
        'lineEn': 'Friendly, expressive, and often whistles to communicate.',
        'lineUr': 'دوستانہ، اظہار پسند، اور آواز یا سیٹی سے رابطہ کرنے والا۔',
        'breedsEn': ['Grey Cockatiel', 'Lutino', 'Pied'],
        'breedsUr': ['گرے کاکاٹیل', 'لٹینو', 'پائیڈ'],
      },
      {
        'speciesEn': 'African Grey Parrot',
        'speciesUr': 'افریقی گرے طوطا',
        'lineEn':
            'Very intelligent, observant, and quick to learn words/sounds.',
        'lineUr':
            'انتہائی ذہین، مشاہدہ کرنے والا، اور الفاظ یا آوازیں جلد سیکھنے والا۔',
        'breedsEn': ['Congo African Grey', 'Timneh African Grey'],
        'breedsUr': ['کانگو افریقی گرے', 'ٹمنے افریقی گرے'],
      },
    ];

    final petBreeds = switch (_petCategory) {
      'dog' => const [
          {
          'breedEn': 'Pakistani Bully (Bully Kutta)',
          'breedUr': 'پاکستانی بُلی (بلی کُتہ)',
          'lineEn':
            'Strong, fearless, and highly territorial, needing firm training and experienced handling.',
          'lineUr':
            'طاقتور، بے خوف، اور اپنے علاقے کا سخت محافظ، جسے مضبوط تربیت اور تجربہ کار دیکھ بھال کی ضرورت ہوتی ہے۔',
          'imageUrl':
            'https://upload.wikimedia.org/wikipedia/commons/2/22/Bully_Kutta.jpg',
          'source': 'Wikimedia Commons',
          'sourceUrl':
            'https://commons.wikimedia.org/wiki/File:Bully_Kutta.jpg',
          },
          {
          'breedEn': 'Turkish Kangal',
          'breedUr': 'ترک کانگل',
          'lineEn':
            'Large, loyal, and naturally protective, especially responsive as a livestock guardian.',
          'lineUr':
            'بڑا، وفادار، اور قدرتی طور پر محافظ، خاص طور پر ریوڑ کی حفاظت میں بہت مؤثر۔',
          'imageUrl':
            'https://upload.wikimedia.org/wikipedia/commons/8/85/Kangal_dog.jpg',
          'source': 'Wikimedia Commons',
          'sourceUrl':
            'https://commons.wikimedia.org/wiki/File:Kangal_dog.jpg',
          },
          {
            'breedEn': 'German Shepherd',
            'breedUr': 'جرمن شیفرڈ',
            'lineEn': 'Alert, highly trainable, and protective with family.',
            'lineUr': 'چوکنا، تربیت میں آسان، اور خاندان کے لیے محافظ۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/0/02/Sch%C3%A4ferhund%2C_R%C3%BCde%2C_schwarz-braun_%282008%29.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Sch%C3%A4ferhund,_R%C3%BCde,_schwarz-braun_(2008).jpg',
          },
          {
            'breedEn': 'Labrador Retriever',
            'breedUr': 'لیبراڈور ریٹریور',
            'lineEn': 'Friendly, social, and very responsive to commands.',
            'lineUr': 'دوستانہ، ملنسار، اور احکامات پر اچھا ردعمل دینے والا۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/2/26/YellowLabradorLooking_new.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:YellowLabradorLooking_new.jpg',
          },
          {
            'breedEn': 'Siberian Husky',
            'breedUr': 'سائبیرین ہسکی',
            'lineEn':
                'Energetic, playful, and needs regular exercise and attention.',
            'lineUr':
                'توانائی سے بھرپور، کھیلنے والا، اور باقاعدہ ورزش و توجہ کا محتاج۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/d/d2/Siberian-husky.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Siberian-husky.jpg',
          },
        ],
      'cats' => const [
          {
            'breedEn': 'Persian',
            'breedUr': 'پرشین',
            'lineEn': 'Calm, affectionate, and prefers a quiet indoor routine.',
            'lineUr':
                'پرسکون، پیار کرنے والی، اور گھر کے پُرسکون ماحول کو پسند کرنے والی۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/5/56/Persian_cat_at_Cat_Caf%C3%A9.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Persian_cat_at_Cat_Caf%C3%A9.jpg',
          },
          {
            'breedEn': 'Siamese',
            'breedUr': 'سیامی',
            'lineEn': 'Vocal, intelligent, and strongly bonded to owners.',
            'lineUr':
                'آواز دینے والی، ذہین، اور مالک سے مضبوط وابستگی رکھنے والی۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/2/25/Siam_lilacpoint.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Siam_lilacpoint.jpg',
          },
          {
            'breedEn': 'Maine Coon',
            'breedUr': 'مین کون',
            'lineEn':
                'Gentle, social, and adaptable with children and families.',
            'lineUr':
                'نرم مزاج، ملنسار، اور بچوں و خاندان کے ساتھ اچھی طرح گھلنے ملنے والی۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/5/5f/Adult_Male_Maine_Coon.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Adult_Male_Maine_Coon.jpg',
          },
        ],
      'birds' => const [
          {
          'breedEn': 'Pigeon',
          'breedUr': 'کبوتر',
          'lineEn':
            'Calm, home-oriented, and known for strong navigation and flock bonding.',
          'lineUr':
            'پرسکون، گھر سے مانوس، اور مضبوط راستہ شناسی و غول کے ساتھ وابستگی رکھنے والا۔',
          'imageUrl':
            'https://upload.wikimedia.org/wikipedia/commons/b/b1/Rock_Pigeon_Columba_livia.jpg',
          'source': 'Wikimedia Commons',
          'sourceUrl':
            'https://commons.wikimedia.org/wiki/File:Rock_Pigeon_Columba_livia.jpg',
          },
          {
            'breedEn': 'Budgerigar (Budgie)',
            'breedUr': 'بجریگر (بجی)',
            'lineEn':
                'Active, social, and responds well to daily interaction.',
            'lineUr': 'متحرک، ملنسار، اور روزانہ توجہ پر اچھا ردعمل دینے والا۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/8/89/Budgerigar-male-strzelecki-qld.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Budgerigar-male-strzelecki-qld.jpg',
          },
          {
            'breedEn': 'Cockatiel',
            'breedUr': 'کاکاٹیل',
            'lineEn':
                'Friendly, expressive, and often whistles to communicate.',
            'lineUr':
                'دوستانہ، اظہار پسند، اور آواز یا سیٹی سے رابطہ کرنے والا۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/1/1d/Cockatiel_Parrot.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Cockatiel_Parrot.jpg',
          },
          {
            'breedEn': 'African Grey Parrot',
            'breedUr': 'افریقی گرے طوطا',
            'lineEn':
                'Very intelligent, observant, and quick to learn words/sounds.',
            'lineUr':
                'انتہائی ذہین، مشاہدہ کرنے والا، اور الفاظ یا آوازیں جلد سیکھنے والا۔',
            'imageUrl':
                'https://upload.wikimedia.org/wikipedia/commons/5/56/Psittacus_erithacus_-perching_on_tray-8a.jpg',
            'source': 'Wikimedia Commons',
            'sourceUrl':
              'https://commons.wikimedia.org/wiki/File:Psittacus_erithacus_-perching_on_tray-8a.jpg',
          },
        ],
      _ => const [],
    };

    final youngCare = _youngPetCare(_petCategory);
    final vaccinePlan = _petVaccinePlan(_petCategory);
    final diseaseGuide = _petDiseaseGuide(_petCategory);

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Pets Section', 'پالتو جانور سیکشن'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: Text(_t('Dog', 'کتا')),
                    selected: _petCategory == 'dog',
                    onSelected: (_) {
                      setState(() => _petCategory = 'dog');
                    },
                  ),
                  ChoiceChip(
                    label: Text(_t('Cats', 'بلیاں')),
                    selected: _petCategory == 'cats',
                    onSelected: (_) {
                      setState(() => _petCategory = 'cats');
                    },
                  ),
                  ChoiceChip(
                    label: Text(_t('Birds', 'پرندے')),
                    selected: _petCategory == 'birds',
                    onSelected: (_) {
                      setState(() => _petCategory = 'birds');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                petDescription,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _t('$petTitle section is coming soon', '$petTitle سیکشن جلد آ رہا ہے'),
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(petIcon, color: const Color(0xFF1E88E5)),
                  const SizedBox(width: 8),
                  Text(
                    _t('Selected category: $petTitle', 'منتخب کیٹیگری: $petTitle'),
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  initiallyExpanded: _isPetSectionExpanded('breeds'),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _setPetSectionExpanded('breeds', expanded);
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    famousListTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    if (_petCategory == 'birds')
                      ...birdSpecies.map(
                        (species) {
                          final speciesBreeds = _isUrdu
                              ? (species['breedsUr'] as List<Object>).cast<String>()
                              : (species['breedsEn'] as List<Object>).cast<String>();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE3F2FD)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t(
                                      species['speciesEn'] as String,
                                      species['speciesUr'] as String,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t(
                                      species['lineEn'] as String,
                                      species['lineUr'] as String,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _t('Different breeds', 'مختلف نسلیں'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E88E5),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...speciesBreeds.map(
                                    (breedName) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text('• $breedName'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      ...petBreeds.map(
                        (breed) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE3F2FD)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(
                                    breed['breedEn'] ?? '',
                                    breed['breedUr'] ?? '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _t(
                                    breed['lineEn'] ?? '',
                                    breed['lineUr'] ?? '',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFFF7FBF8),
                child: ExpansionTile(
                  initiallyExpanded: _isPetSectionExpanded('young'),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _setPetSectionExpanded('young', expanded);
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    _t(
                      youngCare['titleEn'] ?? '',
                      youngCare['titleUr'] ?? '',
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    Text(
                      _t(
                        youngCare['bodyEn'] ?? '',
                        youngCare['bodyUr'] ?? '',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFFFFFBF2),
                child: ExpansionTile(
                  initiallyExpanded: _isPetSectionExpanded('vaccine'),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _setPetSectionExpanded('vaccine', expanded);
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    _t('Vaccine plan for a year', 'ایک سال کا ویکسین پلان'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    ...vaccinePlan.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(plan['stageEn'] ?? '', plan['stageUr'] ?? ''),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _t(plan['detailEn'] ?? '', plan['detailUr'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: const Color(0xFFFFF4F4),
                child: ExpansionTile(
                  initiallyExpanded: _isPetSectionExpanded('disease'),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _setPetSectionExpanded('disease', expanded);
                    });
                  },
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    _t('Prevalent diseases and treatments', 'عام بیماریاں اور علاج'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    ...diseaseGuide.map(
                      (disease) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                disease['diseaseEn'] ?? '',
                                disease['diseaseUr'] ?? '',
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _t(
                                disease['treatmentEn'] ?? '',
                                disease['treatmentUr'] ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Animal Section', 'جانور سیکشن'))),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDFF3E3), Color(0xFFF4FAF4), Color(0xFFEAF7EC)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        'Get animal recommendations from symptoms and photos.',
                        'علامات اور تصاویر سے جانور کے لیے سفارش حاصل کریں۔',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'Upload a photo, describe the symptoms, and get first guidance before contacting a veterinarian.',
                        'تصویر اپ لوڈ کریں، علامات لکھیں، اور ویٹرنری ڈاکٹر سے رابطے سے پہلے ابتدائی رہنمائی حاصل کریں۔',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimalPhotoRecommendationScreen(
                                selectedLanguage: widget.selectedLanguage,
                                initialAnimalType: _animalCategory == 'livestock'
                                    ? 'Buffalo'
                                    : _petCategory == 'cats'
                                    ? 'Cat'
                                    : _petCategory == 'birds'
                                    ? 'Bird'
                                    : 'Dog',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          _t(
                            'Get recommendation from animal photo',
                            'جانور کی تصویر سے سفارش حاصل کریں',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'Choose animal category',
                'جانوروں کی کیٹیگری منتخب کریں',
              ),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _animalCategory = 'livestock');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _animalCategory == 'livestock'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.agriculture),
                    label: Text(_t('Livestock', 'مویشی')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _animalCategory = 'pets');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _animalCategory == 'pets'
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFF64B5F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.pets),
                    label: Text(_t('Pets', 'پالتو جانور')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_animalCategory == 'livestock') ..._livestockCards(context),
            if (_animalCategory == 'pets') ..._petsCards(),
          ],
        ),
      ),
    );
  }
}

class AnimalPhotoRecommendationScreen extends StatefulWidget {
  const AnimalPhotoRecommendationScreen({
    super.key,
    required this.selectedLanguage,
    required this.initialAnimalType,
  });

  final String selectedLanguage;
  final String initialAnimalType;

  @override
  State<AnimalPhotoRecommendationScreen> createState() =>
      _AnimalPhotoRecommendationScreenState();
}

class _AnimalPhotoRecommendationScreenState
    extends State<AnimalPhotoRecommendationScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  late String _animalType;
  String _symptomFocus = 'general';
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _recommendation;

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  @override
  void initState() {
    super.initState();
    _animalType = widget.initialAnimalType;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(
          'Could not pick image. Please try again.',
          'تصویر منتخب نہیں ہو سکی، دوبارہ کوشش کریں۔',
        );
      });
    }
  }

  Future<void> _submitRecommendation() async {
    if (_selectedImageBytes == null) {
      setState(() {
        _error = _t(
          'Please select an animal photo first.',
          'پہلے جانور کی تصویر منتخب کریں۔',
        );
      });
      return;
    }
    if (_notesController.text.trim().length < 4) {
      setState(() {
        _error = _t(
          'Please describe the symptoms in a little detail.',
          'براہ کرم علامات تھوڑی تفصیل سے لکھیں۔',
        );
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _recommendation = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendBaseUrl/animal-photo-recommendation'),
      );
      request.fields['animal_type'] = _animalType;
      request.fields['symptom_focus'] = _symptomFocus;
      request.fields['notes'] = _notesController.text.trim();
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          _selectedImageBytes!,
          filename: _selectedImageName ?? 'animal_photo.jpg',
        ),
      );

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception(responseBody);
      }

      if (!mounted) return;
      setState(() {
        _recommendation = jsonDecode(responseBody) as Map<String, dynamic>;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(
          'Unable to get animal recommendation right now.',
          'فی الحال جانور کی سفارش حاصل نہیں ہو سکی۔',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'urgent':
        return Colors.red.shade700;
      case 'same_day':
        return Colors.orange.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Animal Photo Recommendation', 'جانور کی تصویر سے سفارش'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Upload a clear photo and write the symptoms you observed.',
                      'واضح تصویر اپ لوڈ کریں اور دیکھی گئی علامات لکھیں۔',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_t('Pick from gallery', 'گیلری سے منتخب کریں')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(_t('Use camera', 'کیمرہ استعمال کریں')),
                      ),
                    ],
                  ),
                  if (_selectedImageBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _selectedImageBytes!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedImageName ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _animalType,
                    decoration: InputDecoration(
                      labelText: _t('Animal type', 'جانور کی قسم'),
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Buffalo', child: Text('Buffalo')),
                      DropdownMenuItem(value: 'Cow', child: Text('Cow')),
                      DropdownMenuItem(value: 'Goat', child: Text('Goat')),
                      DropdownMenuItem(value: 'Sheep', child: Text('Sheep')),
                      DropdownMenuItem(value: 'Camel', child: Text('Camel')),
                      DropdownMenuItem(value: 'Dog', child: Text('Dog')),
                      DropdownMenuItem(value: 'Cat', child: Text('Cat')),
                      DropdownMenuItem(value: 'Bird', child: Text('Bird')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _animalType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _symptomFocus,
                    decoration: InputDecoration(
                      labelText: _t('Main symptom area', 'اہم علامتی حصہ'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'general', child: Text(_t('General', 'عمومی'))),
                      DropdownMenuItem(value: 'skin', child: Text(_t('Skin / parasites', 'جلد / پیراسائٹ'))),
                      DropdownMenuItem(value: 'digestion', child: Text(_t('Digestion / feeding', 'ہاضمہ / خوراک'))),
                      DropdownMenuItem(value: 'breathing', child: Text(_t('Breathing', 'سانس'))),
                      DropdownMenuItem(value: 'injury', child: Text(_t('Injury / swelling', 'چوٹ / سوجن'))),
                      DropdownMenuItem(value: 'weakness', child: Text(_t('Weakness / fever', 'کمزوری / بخار'))),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _symptomFocus = value);
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: _t('Symptoms observed', 'دیکھی گئی علامات'),
                      hintText: _t(
                        'Example: cough, nasal discharge, not eating, wound on leg, itching, diarrhea',
                        'مثال: کھانسی، ناک سے پانی، چارہ نہ کھانا، ٹانگ پر زخم، خارش، دست',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitRecommendation,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.medical_information_outlined),
                      label: Text(
                        _submitting
                            ? _t('Getting recommendation...', 'سفارش حاصل کی جا رہی ہے...')
                            : _t('Get recommendation', 'سفارش حاصل کریں'),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          if (_recommendation != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _recommendation!['possible_issue']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _urgencyColor(
                              _recommendation!['urgency_level']?.toString() ?? 'monitor',
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            (_recommendation!['urgency_level']?.toString() ?? 'monitor').toUpperCase(),
                            style: TextStyle(
                              color: _urgencyColor(
                                _recommendation!['urgency_level']?.toString() ?? 'monitor',
                              ),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recommendation!['recommendation']?.toString() ?? '',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recommendation!['confidence_note']?.toString() ?? '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    ...((_recommendation!['next_steps'] as List<dynamic>? ?? <dynamic>[])
                        .map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(step.toString())),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                    Text(
                      _recommendation!['disclaimer']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HealthSectionScreen extends StatefulWidget {
  const HealthSectionScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<HealthSectionScreen> createState() => _HealthSectionScreenState();
}

class _HealthSectionScreenState extends State<HealthSectionScreen> {
  String _selectedHealthAnimal = 'Buffalo';
  final Map<String, String> _selectedDiseaseByAnimal = {};

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  String _animalUrdu(String animal) {
    switch (animal) {
      case 'Buffalo':
        return 'بھینس';
      case 'Cow':
        return 'گائے';
      case 'Sheep':
        return 'بھیڑ';
      case 'Goat':
        return 'بکری';
      default:
        return animal;
    }
  }

  List<Map<String, String>> _healthGuideByAnimal(String animal) {
    switch (animal) {
      case 'Buffalo':
        return const [
          {
            'diseaseEn': 'Hemorrhagic Septicemia (HS)',
            'diseaseUr': 'ہیموریجک سیپٹی سیمیا (HS)',
            'symptomsEn':
                'High fever, throat swelling, breathing difficulty, sudden weakness.',
            'symptomsUr':
                'تیز بخار، گلے کی سوجن، سانس میں دشواری، اچانک کمزوری۔',
            'treatmentEn':
                'Immediate vet visit, early antibiotics/anti-inflammatory, isolate animal, urgent HS vaccination program for herd.',
            'treatmentUr':
                'فوراً ویٹ سے رابطہ کریں، جلد اینٹی بایوٹک/سوزش کم کرنے والی دوا، جانور کو الگ رکھیں، ریوڑ کے لیے HS ویکسین پروگرام کریں۔',
          },
          {
            'diseaseEn': 'Foot-and-Mouth Disease (FMD)',
            'diseaseUr': 'منہ کھر کی بیماری (FMD)',
            'symptomsEn':
                'Mouth blisters, excessive salivation, lameness, drop in feed and milk.',
            'symptomsUr':
                'منہ میں چھالے، زیادہ رال، لنگڑاہٹ، خوراک اور دودھ میں کمی۔',
            'treatmentEn':
                'Supportive care, mouth/hoof antiseptic wash, pain control, strict isolation and disinfection; vaccinate unaffected stock.',
            'treatmentUr':
                'سپورٹو کیئر، منہ/کھر کی جراثیم کش صفائی، درد کا کنٹرول، سخت علیحدگی اور جراثیم کشی؛ غیر متاثرہ جانوروں کی ویکسین کریں۔',
          },
          {
            'diseaseEn': 'Mastitis',
            'diseaseUr': 'تھن کی سوزش (ماسٹائٹس)',
            'symptomsEn':
                'Hot painful udder, clots/watery milk, reduced milk yield.',
            'symptomsUr':
                'تھن گرم اور دردناک، دودھ میں لوتھڑے/پتلا پن، دودھ میں کمی۔',
            'treatmentEn':
                'Milk culture where possible, vet-prescribed intramammary treatment, frequent stripping, udder hygiene and dry bedding.',
            'treatmentUr':
                'ممکن ہو تو دودھ ٹیسٹ، ویٹ کے مشورے سے تھن کا علاج، بار بار دودھ نکالنا، تھن صفائی اور خشک بچھونا۔',
          },
          {
            'diseaseEn':
                'Red Water (Babesiosis / Phosphorus Deficiency Hemoglobinuria)',
            'diseaseUr': 'ریڈ واٹر (بیبیسیوسس / فاسفورس کمی ہیموگلوبین یوریا)',
            'symptomsEn':
                'Red/dark urine, anemia and weakness; high fever is more suggestive of babesiosis, while recent calving + low phosphorus intake may indicate nutritional hemoglobinuria.',
            'symptomsUr':
                'سرخ/گہرا پیشاب، خون کی کمی اور کمزوری؛ تیز بخار عموماً بیبیسیوسس کی طرف اشارہ کرتا ہے جبکہ بچے کے بعد اور فاسفورس کمی غذائی ہیموگلوبین یوریا کی علامت ہو سکتی ہے۔',
            'treatmentEn':
                'Urgent vet differential diagnosis (blood smear/lab tests). Treat cause-specific: anti-protozoals and tick control for babesiosis, or phosphorus therapy plus mineral correction for deficiency-related cases, with fluids/supportive care.',
            'treatmentUr':
                'فوری ویٹ ڈفرینشل تشخیص (بلڈ اسمئیر/لیب ٹیسٹ) ضروری ہے۔ وجہ کے مطابق علاج کریں: بیبیسیوسس میں اینٹی پروٹوزول اور ٹِک کنٹرول، جبکہ کمی والے کیس میں فاسفورس تھراپی اور منرل درستگی، ساتھ فلوئڈ/سپورٹو کیئر۔',
          },
          {
            'diseaseEn': 'Milk Fever (Hypocalcemia)',
            'diseaseUr': 'ملک فیور (ہائپوکیلسیما)',
            'symptomsEn':
                'Weakness after calving, cold ears, tremors, inability to stand, low appetite.',
            'symptomsUr':
                'بچے کے بعد کمزوری، کان ٹھنڈے، کپکپی، کھڑا نہ ہو پانا، بھوک کم ہونا۔',
            'treatmentEn':
                'Emergency calcium therapy by veterinarian, warm bedding, careful lifting support and transition mineral balance in diet.',
            'treatmentUr':
                'ویٹرنرین کے ذریعے ہنگامی کیلشیم تھراپی، گرم بچھونا، احتیاط سے اٹھانے کی سپورٹ اور خوراک میں ٹرانزیشن منرل توازن۔',
          },
          {
            'diseaseEn': 'Grass Tetany (Hypomagnesemia)',
            'diseaseUr': 'گراس ٹیٹنی (ہائپو میگنیشیمیا)',
            'symptomsEn':
                'Nervousness, muscle twitching, staggering gait, convulsions, sudden collapse.',
            'symptomsUr':
                'گھبراہٹ، پٹھوں کی پھڑکن، لڑکھڑاتی چال، دورے، اچانک گر جانا۔',
            'treatmentEn':
                'Immediate veterinary emergency treatment with magnesium therapy, calm handling, and preventive magnesium supplementation in feed/mineral mix.',
            'treatmentUr':
                'فوری ویٹرنری ایمرجنسی علاج کے طور پر میگنیشیم تھراپی، پرسکون ہینڈلنگ، اور خوراک/منرل مکس میں میگنیشیم سپلیمنٹ شامل کریں۔',
          },
          {
            'diseaseEn': 'Liver Fluke (Fasciolosis)',
            'diseaseUr': 'جگر کی سنڈی (فیشیولوسس)',
            'symptomsEn':
                'Progressive weight loss, bottle jaw, anemia, reduced milk yield and weakness.',
            'symptomsUr':
                'بتدریج وزن میں کمی، جبڑے کے نیچے سوجن، خون کی کمی، دودھ میں کمی اور کمزوری۔',
            'treatmentEn':
                'Vet-confirmed diagnosis, strategic flukicide treatment, liver-supportive feeding and control of snail-infested wet grazing areas.',
            'treatmentUr':
                'ویٹ سے تصدیق شدہ تشخیص، منصوبہ بند فلوک کش دوا، جگر کو سپورٹ دینے والی خوراک، اور گھونگھے والے گیلے چراگاہی علاقوں پر کنٹرول۔',
          },
          {
            'diseaseEn': 'Anthrax',
            'diseaseUr': 'اینتھریکس',
            'symptomsEn':
                'Sudden death, high fever, bleeding from body openings, no rigor mortis.',
            'symptomsUr':
                'اچانک موت، تیز بخار، جسمانی سوراخوں سے خون آنا، لاش کا سخت نہ ہونا۔',
            'treatmentEn':
                'Emergency veterinary alert, do not open carcass, strict quarantine, immediate herd vaccination and safe disposal protocol.',
            'treatmentUr':
                'فوری ویٹرنری اطلاع، لاش نہ کھولیں، سخت قرنطینہ، ریوڑ کی فوری ویکسین اور محفوظ تلفی کا طریقہ اپنائیں۔',
          },
          {
            'diseaseEn': 'Black Quarter (BQ)',
            'diseaseUr': 'بلیک کوارٹر (BQ)',
            'symptomsEn':
                'Sudden fever, painful muscle swelling, severe lameness, depression.',
            'symptomsUr':
                'اچانک بخار، پٹھوں میں دردناک سوجن، شدید لنگڑاہٹ، سستی۔',
            'treatmentEn':
                'Immediate vet treatment with early antibiotics, anti-inflammatory support, isolation and urgent BQ vaccination of in-contact animals.',
            'treatmentUr':
                'فوری ویٹ علاج کے ساتھ ابتدائی اینٹی بایوٹک، سوزش کم کرنے والی سپورٹ، علیحدگی اور رابطے میں آئے جانوروں کی فوری BQ ویکسین۔',
          },
        ];
      case 'Cow':
        return const [
          {
            'diseaseEn': 'Foot-and-Mouth Disease (FMD)',
            'diseaseUr': 'منہ کھر کی بیماری (FMD)',
            'symptomsEn':
                'Fever, mouth lesions, hoof pain, salivation, reduced milk and appetite.',
            'symptomsUr':
                'بخار، منہ کے زخم، کھر میں درد، رال، دودھ اور بھوک میں کمی۔',
            'treatmentEn':
                'Supportive treatment, soft feed, hoof care, biosecurity isolation; maintain vaccine boosters.',
            'treatmentUr':
                'سپورٹو علاج، نرم خوراک، کھر کی دیکھ بھال، بایو سکیورٹی کے ساتھ علیحدگی؛ ویکسین بوسٹر جاری رکھیں۔',
          },
          {
            'diseaseEn': 'Lumpy Skin Disease (LSD)',
            'diseaseUr': 'لمپی اسکن بیماری (LSD)',
            'symptomsEn':
                'Skin nodules, fever, swollen lymph nodes, reduced milk production.',
            'symptomsUr': 'جلد پر گلٹیاں، بخار، لمف نوڈ سوجن، دودھ میں کمی۔',
            'treatmentEn':
                'Vet-supervised supportive therapy, wound care, fly/tick control, and vaccination of at-risk animals.',
            'treatmentUr':
                'ویٹ کی نگرانی میں سپورٹو علاج، زخم کی دیکھ بھال، مکھی/ٹِک کنٹرول، اور خطرے والے جانوروں کی ویکسین۔',
          },
          {
            'diseaseEn': 'Mastitis',
            'diseaseUr': 'تھن کی سوزش (ماسٹائٹس)',
            'symptomsEn':
                'Udder swelling, abnormal milk, pain during milking, sudden yield drop.',
            'symptomsUr':
                'تھن سوجن، غیر معمولی دودھ، دودھ نکالتے وقت درد، اچانک پیداوار میں کمی۔',
            'treatmentEn':
                'Prompt mastitis testing, vet medication protocol, teat dipping and improved milking hygiene.',
            'treatmentUr':
                'فوری ماسٹائٹس ٹیسٹ، ویٹ کے مطابق ادویات، ٹیٹ ڈِپ اور دودھ نکالنے کی صفائی بہتر کریں۔',
          },
          {
            'diseaseEn':
                'Red Water (Babesiosis / Phosphorus Deficiency Hemoglobinuria)',
            'diseaseUr': 'ریڈ واٹر (بیبیسیوسس / فاسفورس کمی ہیموگلوبین یوریا)',
            'symptomsEn':
                'Coffee/red urine, weakness, anemia and milk drop; fever/tick exposure suggest babesiosis, while peri-parturient cows with poor mineral intake may have phosphorus-deficiency hemoglobinuria.',
            'symptomsUr':
                'کافی/سرخ پیشاب، کمزوری، خون کی کمی اور دودھ میں کمی؛ بخار/ٹِک ایکسپوژر بیبیسیوسس کی طرف اشارہ کرتا ہے جبکہ بچے کے قریب گائیں میں کم منرل خوراک فاسفورس کمی ہیموگلوبین یوریا کا سبب بن سکتی ہے۔',
            'treatmentEn':
                'Confirm cause with veterinarian (smear/biochemistry). Use anti-babesial therapy + tick control for babesiosis, or phosphorus supplementation and dietary mineral balancing for deficiency cases, with supportive fluids.',
            'treatmentUr':
                'ویٹرنرین سے وجہ کی تصدیق کریں (اسمئیر/بایوکیمسٹری)۔ بیبیسیوسس میں اینٹی بیبیسیئل علاج + ٹِک کنٹرول، جبکہ کمی والے کیس میں فاسفورس سپلیمنٹ اور خوراکی منرل بیلنس، ساتھ سپورٹو فلوئڈز دیں۔',
          },
          {
            'diseaseEn': 'Milk Fever (Hypocalcemia)',
            'diseaseUr': 'ملک فیور (ہائپوکیلسیما)',
            'symptomsEn':
                'Usually near calving: muscle weakness, staggering, low body temperature, recumbency.',
            'symptomsUr':
                'اکثر بچے کے قریب: پٹھوں کی کمزوری، لڑکھڑاہٹ، جسمانی درجہ حرارت کم، لیٹ جانا۔',
            'treatmentEn':
                'Immediate IV/oral calcium under vet supervision, monitor heart rate, and adjust pre-calving mineral feeding.',
            'treatmentUr':
                'ویٹ نگرانی میں فوری آئی وی/اورل کیلشیم، دل کی دھڑکن مانیٹر کریں، اور بچے سے پہلے منرل فیڈنگ درست کریں۔',
          },
          {
            'diseaseEn': 'Grass Tetany (Hypomagnesemia)',
            'diseaseUr': 'گراس ٹیٹنی (ہائپو میگنیشیمیا)',
            'symptomsEn':
                'Excitability, muscle tremors, stiff gait, teeth grinding, sudden convulsions.',
            'symptomsUr':
                'زیادہ بے چینی، پٹھوں کی کپکپی، اکڑی ہوئی چال، دانت پیسنا، اچانک دورے۔',
            'treatmentEn':
                'Urgent magnesium treatment by veterinarian, reduce stress, provide oral magnesium follow-up and correct mineral imbalance in ration.',
            'treatmentUr':
                'ویٹرنرین کے ذریعے فوری میگنیشیم علاج، تناؤ کم کریں، بعد ازاں اورل میگنیشیم دیں اور خوراکی منرل عدم توازن درست کریں۔',
          },
          {
            'diseaseEn': 'Liver Fluke (Fasciolosis)',
            'diseaseUr': 'جگر کی سنڈی (فیشیولوسس)',
            'symptomsEn':
                'Chronic weight loss, pale mucosa, poor body condition, diarrhea and milk decline.',
            'symptomsUr':
                'دائمی وزن میں کمی، جھلیاں پیلی، جسمانی حالت خراب، اسہال اور دودھ میں کمی۔',
            'treatmentEn':
                'Fecal/lab confirmation, stage-appropriate flukicide protocol, nutrition correction and drainage of wet grazing patches to break fluke cycle.',
            'treatmentUr':
                'فیکل/لیب تصدیق، مرحلے کے مطابق فلوک کش پروٹوکول، غذائی درستگی اور گیلی چراگاہ کے نکاس سے فلوک سائیکل توڑیں۔',
          },
          {
            'diseaseEn': 'Anthrax',
            'diseaseUr': 'اینتھریکس',
            'symptomsEn':
                'Peracute death, fever, breathing distress, dark blood from natural openings.',
            'symptomsUr':
                'اچانک/تیز موت، بخار، سانس کی تکلیف، قدرتی سوراخوں سے گہرا خون۔',
            'treatmentEn':
                'Immediate district vet notification, quarantine, carcass biosecure disposal, and ring vaccination in surrounding farms.',
            'treatmentUr':
                'فوری ضلعی ویٹ اطلاع، قرنطینہ، لاش کی محفوظ تلفی، اور اردگرد فارموں میں رنگ ویکسینیشن۔',
          },
          {
            'diseaseEn': 'Black Quarter (BQ)',
            'diseaseUr': 'بلیک کوارٹر (BQ)',
            'symptomsEn':
                'Acute fever, crackling painful swelling in heavy muscles, reluctance to move.',
            'symptomsUr':
                'شدید بخار، بڑے پٹھوں میں کڑکڑاہٹ کے ساتھ دردناک سوجن، چلنے سے گریز۔',
            'treatmentEn':
                'Urgent antibiotics in early stage, anti-inflammatory support, strict sanitation and preventive vaccination.',
            'treatmentUr':
                'ابتدائی مرحلے میں فوری اینٹی بایوٹک، سوزش کم کرنے والی سپورٹ، سخت صفائی اور حفاظتی ویکسینیشن۔',
          },
        ];
      case 'Sheep':
        return const [
          {
            'diseaseEn': 'PPR (Peste des Petits Ruminants)',
            'diseaseUr': 'پی پی آر',
            'symptomsEn':
                'High fever, nasal discharge, mouth sores, diarrhea, rapid weakness.',
            'symptomsUr':
                'تیز بخار، ناک سے رطوبت، منہ کے زخم، اسہال، تیز کمزوری۔',
            'treatmentEn':
                'No specific antiviral; urgent supportive care, fluid therapy, antibiotics for secondary infection, emergency vaccination ring.',
            'treatmentUr':
                'مخصوص اینٹی وائرل نہیں؛ فوری سپورٹو کیئر، فلوئڈ تھراپی، ثانوی انفیکشن کے لیے اینٹی بایوٹک، ایمرجنسی ویکسین رنگ۔',
          },
          {
            'diseaseEn': 'Enterotoxemia (ET)',
            'diseaseUr': 'انٹرو ٹوکسی میا (ET)',
            'symptomsEn':
                'Sudden death in fast-growing lambs, abdominal pain, diarrhea, nervous signs.',
            'symptomsUr':
                'تیزی سے بڑھنے والے برّوں میں اچانک موت، پیٹ درد، اسہال، اعصابی علامات۔',
            'treatmentEn':
                'Emergency vet response, antitoxin where available, strict feed transition and ET vaccination boosters.',
            'treatmentUr':
                'فوری ویٹ رسپانس، دستیاب ہو تو اینٹی ٹاکسن، خوراک کی بتدریج تبدیلی اور ET بوسٹر ویکسین۔',
          },
          {
            'diseaseEn': 'Sheep Pox',
            'diseaseUr': 'بھیڑ چیچک',
            'symptomsEn':
                'Skin lesions, fever, eye/nose discharge, reduced grazing.',
            'symptomsUr': 'جلدی دانے، بخار، آنکھ/ناک سے رطوبت، چرائی میں کمی۔',
            'treatmentEn':
                'Isolation, skin lesion care, secondary infection control, and preventive flock vaccination.',
            'treatmentUr':
                'علیحدگی، جلدی زخم کی دیکھ بھال، ثانوی انفیکشن کنٹرول، اور ریوڑ کی حفاظتی ویکسین۔',
          },
          {
            'diseaseEn': 'Anthrax',
            'diseaseUr': 'اینتھریکس',
            'symptomsEn':
                'Sudden death, high fever, trembling, bleeding from mouth/nose.',
            'symptomsUr': 'اچانک موت، تیز بخار، کپکپی، منہ/ناک سے خون آنا۔',
            'treatmentEn':
                'Emergency reporting, isolate flock, avoid opening carcass, rapid ring vaccination and strict disinfection.',
            'treatmentUr':
                'فوری رپورٹنگ، ریوڑ کو الگ کریں، لاش نہ کھولیں، فوری رنگ ویکسینیشن اور سخت جراثیم کشی کریں۔',
          },
          {
            'diseaseEn': 'Bluetongue (Severe Form)',
            'diseaseUr': 'بلو ٹنگ (شدید شکل)',
            'symptomsEn':
                'High fever, facial swelling, mouth ulcers, lameness, breathing stress.',
            'symptomsUr':
                'تیز بخار، چہرے کی سوجن، منہ کے زخم، لنگڑاہٹ، سانس میں دباؤ۔',
            'treatmentEn':
                'Immediate supportive care, vector control (midges), anti-inflammatory therapy and strict movement control.',
            'treatmentUr':
                'فوری سپورٹو کیئر، ویکٹر کنٹرول (مڈجز)، سوزش کم کرنے والا علاج اور نقل و حرکت پر سخت کنٹرول۔',
          },
          {
            'diseaseEn': 'Liver Fluke (Fasciolosis)',
            'diseaseUr': 'جگر کی سنڈی (فیشیولوسس)',
            'symptomsEn':
                'Weight loss, bottle jaw, anemia, reduced wool/meat performance and weakness.',
            'symptomsUr':
                'وزن میں کمی، جبڑے کے نیچے سوجن، خون کی کمی، اون/گوشت کارکردگی میں کمی اور کمزوری۔',
            'treatmentEn':
                'Strategic flukicide dosing (vet guided), pasture and snail control, plus follow-up deworming plan by season.',
            'treatmentUr':
                'ویٹ رہنمائی کے ساتھ منصوبہ بند فلوک کش ڈوز، چراگاہ اور گھونگھا کنٹرول، اور موسم کے مطابق فالو اپ ڈی ورمنگ پلان۔',
          },
        ];
      case 'Goat':
        return const [
          {
            'diseaseEn': 'PPR (Goat Plague)',
            'diseaseUr': 'پی پی آر (بکری طاعون)',
            'symptomsEn':
                'Fever, coughing, eye/nose discharge, mouth erosions, severe diarrhea.',
            'symptomsUr':
                'بخار، کھانسی، آنکھ/ناک سے رطوبت، منہ کے زخم، شدید اسہال۔',
            'treatmentEn':
                'Supportive therapy, dehydration control, antibiotics for secondary bacterial infections, mass vaccination planning.',
            'treatmentUr':
                'سپورٹو تھراپی، پانی کی کمی کا کنٹرول، ثانوی بیکٹیریل انفیکشن کے لیے اینٹی بایوٹک، اجتماعی ویکسین پلاننگ۔',
          },
          {
            'diseaseEn': 'Goat Pox',
            'diseaseUr': 'بکری چیچک',
            'symptomsEn':
                'Fever, raised skin lesions, depression, reduced feed intake.',
            'symptomsUr': 'بخار، ابھری جلدی گلٹیاں، کمزوری، خوراک میں کمی۔',
            'treatmentEn':
                'Isolation, wound hygiene, anti-inflammatory support, insect control and annual vaccination.',
            'treatmentUr':
                'علیحدگی، زخم کی صفائی، سوزش کم کرنے والی سپورٹ، کیڑوں کا کنٹرول اور سالانہ ویکسین۔',
          },
          {
            'diseaseEn': 'Internal Parasites (Worm Burden)',
            'diseaseUr': 'اندرونی پیراسائٹس (کیڑوں کا بوجھ)',
            'symptomsEn':
                'Weight loss, rough coat, pale gums, diarrhea, poor growth.',
            'symptomsUr':
                'وزن میں کمی، کھال خراب، مسوڑھے پیلے، اسہال، نشوونما کم۔',
            'treatmentEn':
                'Fecal test-guided deworming, pasture rotation, mineral support and follow-up dosing by vet advice.',
            'treatmentUr':
                'فیکل ٹیسٹ کے مطابق ڈی ورمنگ، چراگاہ کی گردش، منرل سپورٹ، اور ویٹ مشورے سے فالو اپ ڈوز۔',
          },
          {
            'diseaseEn': 'CCPP (Contagious Caprine Pleuropneumonia)',
            'diseaseUr': 'سی سی پی پی (متعدی بکری نمونیا)',
            'symptomsEn':
                'Very high fever, severe cough, painful breathing, nasal discharge, sudden deaths.',
            'symptomsUr':
                'بہت تیز بخار، شدید کھانسی، دردناک سانس، ناک سے رطوبت، اچانک اموات۔',
            'treatmentEn':
                'Urgent vet-directed antibiotics, anti-inflammatory support, strict isolation, ventilation improvement and emergency vaccination strategy.',
            'treatmentUr':
                'فوری ویٹ ہدایت کے مطابق اینٹی بایوٹک، سوزش کم کرنے والی سپورٹ، سخت علیحدگی، ہوا داری بہتر کریں اور ایمرجنسی ویکسین حکمت عملی اپنائیں۔',
          },
          {
            'diseaseEn': 'Anthrax',
            'diseaseUr': 'اینتھریکس',
            'symptomsEn':
                'Sudden collapse, fever, dark blood discharge, rapid death in herd pockets.',
            'symptomsUr':
                'اچانک گرنا، بخار، گہرا خون خارج ہونا، ریوڑ کے حصوں میں تیز اموات۔',
            'treatmentEn':
                'Immediate veterinary alert, quarantine, carcass safety protocols and ring vaccination of nearby stock.',
            'treatmentUr':
                'فوری ویٹرنری اطلاع، قرنطینہ، لاش حفاظتی پروٹوکول، اور قریبی جانوروں کی رنگ ویکسینیشن۔',
          },
          {
            'diseaseEn': 'Liver Fluke (Fasciolosis)',
            'diseaseUr': 'جگر کی سنڈی (فیشیولوسس)',
            'symptomsEn':
                'Poor growth, anemia, rough coat, bottle jaw and lowered milk in lactating does.',
            'symptomsUr':
                'نشوونما میں کمی، خون کی کمی، کھال خراب، جبڑے کے نیچے سوجن اور دودھ دینے والی بکریوں میں دودھ کم ہونا۔',
            'treatmentEn':
                'Vet-directed flukicide regimen, mineral support, and strict wet-area/snail control in grazing fields.',
            'treatmentUr':
                'ویٹ ہدایت کے مطابق فلوک کش ادویاتی نظام، منرل سپورٹ، اور چراگاہ کے گیلے علاقوں/گھونگھوں پر سخت کنٹرول۔',
          },
        ];
      default:
        return const [];
    }
  }

  String _severityLevelForDisease(String diseaseEn) {
    final d = diseaseEn.toLowerCase();
    if (d.contains('hemorrhagic septicemia') ||
        d.contains('ppr') ||
        d.contains('foot-and-mouth') ||
        d.contains('enterotoxemia') ||
        d.contains('anthrax') ||
        d.contains('black quarter') ||
        d.contains('ccpp') ||
        d.contains('bluetongue') ||
        d.contains('red water') ||
        d.contains('milk fever') ||
        d.contains('hypomagnesemia') ||
        d.contains('grass tetany') ||
        d.contains('liver fluke') ||
        d.contains('fasciolosis')) {
      return 'high';
    }
    if (d.contains('lumpy skin') || d.contains('pox')) {
      return 'medium';
    }
    return 'low';
  }

  Color _severityColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _severityLabel(String level) {
    switch (level) {
      case 'high':
        return _t('Emergency: High', 'ہنگامی: زیادہ');
      case 'medium':
        return _t('Priority: Medium', 'ترجیح: درمیانی');
      default:
        return _t('Routine: Low', 'معمول: کم');
    }
  }

  List<Map<String, String>> _activeFormulasForDisease(String diseaseEn) {
    final d = diseaseEn.toLowerCase();

    if (d.contains('hemorrhagic septicemia')) {
      return const [
        {
          'en': 'Oxytetracycline (active ingredient)',
          'ur': 'آکسی ٹیٹراسائکلین (فعال جزو)',
        },
        {
          'en': 'Ceftiofur / broad-spectrum antibiotic class (vet guided)',
          'ur': 'سیفٹیوفر / براڈ اسپیکٹرم اینٹی بایوٹک کلاس (ویٹ نگرانی)',
        },
        {
          'en': 'Flunixin or ketoprofen (anti-inflammatory support)',
          'ur': 'فلونکسین یا کیٹوپروفین (سوزش کم کرنے والی سپورٹ)',
        },
      ];
    }

    if (d.contains('foot-and-mouth')) {
      return const [
        {
          'en': 'Povidone-iodine mouth/hoof antiseptic wash',
          'ur': 'پوویڈون آئیوڈین منہ/کھر جراثیم کش واش',
        },
        {
          'en': 'Flunixin meglumine (pain and fever support)',
          'ur': 'فلونکسین میگلومین (درد اور بخار سپورٹ)',
        },
        {
          'en': 'Oral electrolytes and energy support solution',
          'ur': 'اورل الیکٹرولائٹس اور توانائی سپورٹ محلول',
        },
      ];
    }

    if (d.contains('mastitis')) {
      return const [
        {
          'en': 'Cloxacillin intramammary formulation',
          'ur': 'کلوکساسلین انٹرا میمری فارمولا',
        },
        {
          'en': 'Cephapirin intramammary formulation',
          'ur': 'سیفاپیرن انٹرا میمری فارمولا',
        },
        {
          'en': 'Amoxicillin + clavulanate class (culture/vet based)',
          'ur': 'ایموکسی سلین + کلاویولانیٹ کلاس (کلچر/ویٹ کی بنیاد پر)',
        },
      ];
    }

    if (d.contains('lumpy skin')) {
      return const [
        {
          'en': 'Meloxicam or flunixin (supportive anti-inflammatory)',
          'ur': 'میلوکسیکام یا فلونکسین (سپورٹو سوزش کم کرنے والی)',
        },
        {
          'en': 'Oxytetracycline for secondary bacterial infection control',
          'ur': 'ثانوی بیکٹیریل انفیکشن کنٹرول کے لیے آکسی ٹیٹراسائکلین',
        },
        {
          'en': 'Topical antiseptic (povidone-iodine/chlorhexidine)',
          'ur': 'موضعی جراثیم کش (پوویڈون آئیوڈین/کلورہیکسیڈین)',
        },
      ];
    }

    if (d.contains('anthrax')) {
      return const [
        {
          'en': 'Procaine penicillin G (early cases, vet emergency protocol)',
          'ur': 'پروکین پینسلن جی (ابتدائی کیسز، ویٹ ایمرجنسی پروٹوکول)',
        },
        {
          'en': 'Oxytetracycline class (alternative where indicated)',
          'ur': 'آکسی ٹیٹراسائکلین کلاس (ضرورت کے مطابق متبادل)',
        },
        {
          'en': 'Disinfection with formaldehyde/chlorine compounds as advised',
          'ur': 'ویٹ مشورے کے مطابق فارملڈیہائیڈ/کلورین مرکبات سے جراثیم کشی',
        },
      ];
    }

    if (d.contains('black quarter')) {
      return const [
        {
          'en': 'Penicillin-streptomycin combination (early stage)',
          'ur': 'پینسلن-اسٹریپٹومائسین کمبینیشن (ابتدائی مرحلہ)',
        },
        {
          'en': 'Oxytetracycline injectable class',
          'ur': 'آکسی ٹیٹراسائکلین انجیکشن کلاس',
        },
        {
          'en': 'NSAID support: flunixin/ketoprofen',
          'ur': 'این ایس اے آئی ڈی سپورٹ: فلونکسین/کیٹوپروفین',
        },
      ];
    }

    if (d.contains('red water')) {
      return const [
        {
          'en': 'Diminazene aceturate (babesiosis pathway)',
          'ur': 'ڈائمنیزین ایسیچیوریٹ (بیبیسیوسس راستہ)',
        },
        {
          'en': 'Imidocarb dipropionate (babesiosis pathway)',
          'ur': 'ایمیڈوکارب ڈائی پروپیونیٹ (بیبیسیوسس راستہ)',
        },
        {
          'en':
              'Sodium acid phosphate / phosphorus therapy (deficiency pathway)',
          'ur': 'سوڈیم ایسڈ فاسفیٹ / فاسفورس تھراپی (کمی راستہ)',
        },
      ];
    }

    if (d.contains('milk fever')) {
      return const [
        {
          'en': 'Calcium borogluconate IV (vet emergency use)',
          'ur': 'کیلشیم بوروگلوکونیٹ آئی وی (ویٹ ایمرجنسی استعمال)',
        },
        {
          'en': 'Oral calcium gel/bolus follow-up',
          'ur': 'اورل کیلشیم جیل/بولس فالو اپ',
        },
        {
          'en': 'Calcium-phosphorus-magnesium transition mineral mix',
          'ur': 'کیلشیم-فاسفورس-میگنیشیم ٹرانزیشن منرل مکس',
        },
      ];
    }

    if (d.contains('grass tetany') || d.contains('hypomagnesemia')) {
      return const [
        {
          'en': 'Magnesium sulfate solution (IV/SC under vet)',
          'ur': 'میگنیشیم سلفیٹ محلول (ویٹ نگرانی میں آئی وی/ایس سی)',
        },
        {
          'en': 'Magnesium oxide oral supplementation',
          'ur': 'میگنیشیم آکسائیڈ اورل سپلیمنٹ',
        },
        {
          'en': 'Calcium-magnesium combined emergency formulations',
          'ur': 'کیلشیم-میگنیشیم مشترکہ ایمرجنسی فارمولیشنز',
        },
      ];
    }

    if (d.contains('liver fluke') || d.contains('fasciolosis')) {
      return const [
        {
          'en': 'Triclabendazole (immature + adult flukes)',
          'ur': 'ٹرائیکلابینڈازول (کم عمر + بالغ فلوک)',
        },
        {
          'en': 'Closantel (stage/season based use)',
          'ur': 'کلوسینٹیل (مرحلہ/موسم کے مطابق استعمال)',
        },
        {
          'en': 'Oxyclozanide (adult fluke control)',
          'ur': 'آکسی کلوزانائیڈ (بالغ فلوک کنٹرول)',
        },
      ];
    }

    if (d.contains('ppr')) {
      return const [
        {
          'en': 'Oral/IV electrolyte fluids for dehydration',
          'ur': 'پانی کی کمی کے لیے اورل/آئی وی الیکٹرولائٹ فلوئڈز',
        },
        {
          'en': 'Oxytetracycline class for secondary bacterial infection',
          'ur': 'ثانوی بیکٹیریل انفیکشن کے لیے آکسی ٹیٹراسائکلین کلاس',
        },
        {
          'en': 'NSAID supportive care (meloxicam/flunixin)',
          'ur': 'این ایس اے آئی ڈی سپورٹو کیئر (میلوکسیکام/فلونکسین)',
        },
      ];
    }

    if (d.contains('enterotoxemia')) {
      return const [
        {
          'en': 'Clostridium perfringens antitoxin (where available)',
          'ur': 'کلسٹریڈیم پرفرنجنز اینٹی ٹاکسن (دستیاب ہونے پر)',
        },
        {
          'en': 'Penicillin class (early intervention)',
          'ur': 'پینسلن کلاس (ابتدائی مداخلت)',
        },
        {
          'en': 'Fluid and bicarbonate support (vet protocol)',
          'ur': 'فلوئڈ اور بائیکاربو نیٹ سپورٹ (ویٹ پروٹوکول)',
        },
      ];
    }

    if (d.contains('sheep pox') || d.contains('goat pox')) {
      return const [
        {
          'en': 'Topical antiseptic: povidone-iodine/chlorhexidine',
          'ur': 'موضعی جراثیم کش: پوویڈون آئیوڈین/کلورہیکسیڈین',
        },
        {
          'en': 'Oxytetracycline class for secondary infections',
          'ur': 'ثانوی انفیکشن کے لیے آکسی ٹیٹراسائکلین کلاس',
        },
        {
          'en': 'Anti-inflammatory support (meloxicam/flunixin)',
          'ur': 'سوزش کم کرنے والی سپورٹ (میلوکسیکام/فلونکسین)',
        },
      ];
    }

    if (d.contains('bluetongue')) {
      return const [
        {
          'en': 'NSAID support: flunixin/meloxicam',
          'ur': 'این ایس اے آئی ڈی سپورٹ: فلونکسین/میلوکسیکام',
        },
        {
          'en': 'Electrolyte fluid therapy and nutrition support',
          'ur': 'الیکٹرولائٹ فلوئڈ تھراپی اور غذائی سپورٹ',
        },
        {
          'en': 'Topical oral lesion antiseptic care',
          'ur': 'منہ کے زخموں کی موضعی جراثیم کش نگہداشت',
        },
      ];
    }

    if (d.contains('ccpp')) {
      return const [
        {
          'en': 'Tylosin class antibiotics (vet directed)',
          'ur': 'ٹائلوسین کلاس اینٹی بایوٹک (ویٹ ہدایت کے مطابق)',
        },
        {
          'en': 'Oxytetracycline / florfenicol class options',
          'ur': 'آکسی ٹیٹراسائکلین / فلورفینیکول کلاس آپشنز',
        },
        {
          'en': 'NSAID + respiratory supportive therapy',
          'ur': 'این ایس اے آئی ڈی + تنفسی سپورٹو تھراپی',
        },
      ];
    }

    if (d.contains('internal parasites')) {
      return const [
        {'en': 'Albendazole class', 'ur': 'البینڈازول کلاس'},
        {'en': 'Fenbendazole class', 'ur': 'فینبینڈازول کلاس'},
        {
          'en': 'Levamisole / ivermectin class (rotation by vet advice)',
          'ur': 'لیوامیزول / آئیورمیکٹن کلاس (ویٹ مشورے سے روٹیشن)',
        },
      ];
    }

    return const [
      {
        'en': 'Use vet-prescribed active ingredient protocols only',
        'ur': 'صرف ویٹ کی ہدایت کردہ فعال جزو پروٹوکول استعمال کریں',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final healthGuide = _healthGuideByAnimal(_selectedHealthAnimal);
    final diseaseOptions = healthGuide.map((e) => e['diseaseEn']!).toList();
    String selectedDisease =
        _selectedDiseaseByAnimal[_selectedHealthAnimal] ?? diseaseOptions.first;
    if (!diseaseOptions.contains(selectedDisease)) {
      selectedDisease = diseaseOptions.first;
    }
    final selectedDiseaseItem = healthGuide.firstWhere(
      (e) => e['diseaseEn'] == selectedDisease,
    );

    return Scaffold(
      appBar: AppBar(title: Text(_t('Health Section', 'صحت سیکشن'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _t('Select animal species', 'جانور کی قسم منتخب کریں'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_t('Buffalo', 'بھینس')),
                selected: _selectedHealthAnimal == 'Buffalo',
                onSelected: (_) =>
                    setState(() => _selectedHealthAnimal = 'Buffalo'),
              ),
              ChoiceChip(
                label: Text(_t('Cow', 'گائے')),
                selected: _selectedHealthAnimal == 'Cow',
                onSelected: (_) =>
                    setState(() => _selectedHealthAnimal = 'Cow'),
              ),
              ChoiceChip(
                label: Text(_t('Sheep', 'بھیڑ')),
                selected: _selectedHealthAnimal == 'Sheep',
                onSelected: (_) =>
                    setState(() => _selectedHealthAnimal = 'Sheep'),
              ),
              ChoiceChip(
                label: Text(_t('Goat', 'بکری')),
                selected: _selectedHealthAnimal == 'Goat',
                onSelected: (_) =>
                    setState(() => _selectedHealthAnimal = 'Goat'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Feed with balanced mineral nutrients and timely vaccination will save your animal from many lethal diseases.',
              'متوازن منرل غذائیت اور بروقت ویکسینیشن آپ کے جانور کو کئی جان لیوا بیماریوں سے بچا سکتی ہے۔',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Text(
            _t('Select disease name', 'بیماری کا نام منتخب کریں'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedDisease,
            decoration: InputDecoration(labelText: _t('Disease', 'بیماری')),
            items: healthGuide
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['diseaseEn']!,
                    child: Text(_t(item['diseaseEn']!, item['diseaseUr']!)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedDiseaseByAnimal[_selectedHealthAnimal] = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              final severityLevel = _severityLevelForDisease(
                selectedDiseaseItem['diseaseEn']!,
              );
              final severityColor = _severityColor(severityLevel);
              final formulas = _activeFormulasForDisease(
                selectedDiseaseItem['diseaseEn']!,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _t(
                                selectedDiseaseItem['diseaseEn']!,
                                selectedDiseaseItem['diseaseUr']!,
                              ),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: severityColor),
                            ),
                            child: Text(
                              _severityLabel(severityLevel),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: severityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Symptoms', 'علامات'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          selectedDiseaseItem['symptomsEn']!,
                          selectedDiseaseItem['symptomsUr']!,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Treatment options', 'علاج کے اختیارات'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          selectedDiseaseItem['treatmentEn']!,
                          selectedDiseaseItem['treatmentUr']!,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Recommended active formulas (no brand names)',
                          'تجویز کردہ فعال فارمولے (برانڈ نام نہیں)',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      ...formulas.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('- ${_t(f['en']!, f['ur']!)}'),
                        ),
                      ),
                      Text(
                        _t(
                          'Dose must be prescribed by a qualified veterinarian.',
                          'خوراک لازماً مستند ویٹرنرین تجویز کرے گا۔',
                        ),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t(
                          'These recommendations are for information only.',
                          'یہ سفارشات صرف معلومات کے لیے ہیں۔',
                        ),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              'Selected species: $_selectedHealthAnimal',
              'منتخب جانور: ${_animalUrdu(_selectedHealthAnimal)}',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            _t(
              'Important: This section is for guidance only. Always confirm diagnosis, dosage, and withdrawal period with a qualified veterinarian.',
              'اہم: یہ سیکشن صرف رہنمائی کے لیے ہے۔ تشخیص، خوراک اور ادویات کے وقفہ استعمال کی تصدیق لازماً مستند ویٹرنرین سے کریں۔',
            ),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class MilkSectionScreen extends StatefulWidget {
  const MilkSectionScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<MilkSectionScreen> createState() => _MilkSectionScreenState();
}

class _MilkSectionScreenState extends State<MilkSectionScreen> {
  String _selectedMilkStage = 'pregnant';
  String _selectedMilkAnimal = 'buffalo';
  final Map<String, String> _selectedMonthByContext = {};

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';

  String _t(String en, String ur) => _isUrdu ? ur : en;

  String _animalUrdu(String animal) {
    switch (animal) {
      case 'Buffalo':
        return 'بھینس';
      case 'Cow':
        return 'گائے';
      case 'Sheep':
        return 'بھیڑ';
      case 'Goat':
        return 'بکری';
      default:
        return animal;
    }
  }

  String _monthText(String text) {
    if (!_isUrdu) return text;
    return text
        .replaceAll('Month 1', 'مہینہ 1')
        .replaceAll('Month 2', 'مہینہ 2')
        .replaceAll('Month 3', 'مہینہ 3')
        .replaceAll('Month 4', 'مہینہ 4')
        .replaceAll('Month 5', 'مہینہ 5')
        .replaceAll('Month 6', 'مہینہ 6')
        .replaceAll('Month 7', 'مہینہ 7')
        .replaceAll('Month 8', 'مہینہ 8')
        .replaceAll('Month 9', 'مہینہ 9')
        .replaceAll('Month 8-10', 'مہینہ 8-10')
        .replaceAll('Month 5-6', 'مہینہ 5-6')
        .replaceAll('post-calving', 'بچے کے بعد')
        .replaceAll('post-lambing', 'برہ کے بعد')
        .replaceAll('post-kidding', 'بچے کے بعد');
  }

  String _recText(String text) {
    if (!_isUrdu) return text;
    return text
        .replaceAll('Green fodder', 'سبز چارہ')
        .replaceAll('concentrate', 'کنسنٹریٹ')
        .replaceAll('Concentrate', 'کنسنٹریٹ')
        .replaceAll('mineral mix', 'منرل مکس')
        .replaceAll('mineral mixture', 'منرل مکسچر')
        .replaceAll('clean water', 'صاف پانی')
        .replaceAll('Clean water', 'صاف پانی')
        .replaceAll('deworming', 'کیڑے مار دوا')
        .replaceAll('Deworming', 'کیڑے مار دوا')
        .replaceAll('vaccination', 'ویکسین')
        .replaceAll('Vaccination', 'ویکسین')
        .replaceAll('health check', 'صحت کا معائنہ')
        .replaceAll('vet check', 'ویٹرنری معائنہ')
        .replaceAll('Pregnancy confirmation', 'حمل کی تصدیق')
        .replaceAll('Pregnancy diagnosis', 'حمل کی تشخیص')
        .replaceAll('heat detection', 'ہیٹ کی شناخت')
        .replaceAll('Heat detection', 'ہیٹ کی شناخت')
        .replaceAll('body condition', 'جسمانی حالت')
        .replaceAll('milk output', 'دودھ کی پیداوار')
        .replaceAll('milk declines', 'دودھ کم ہو')
        .replaceAll('fiber', 'فائبر')
        .replaceAll('ration', 'خوراک')
        .replaceAll('silage', 'سائیلج')
        .replaceAll('bypass protein', 'بائی پاس پروٹین')
        .replaceAll('vitamin ADE', 'وٹامن ADE')
        .replaceAll('FMD booster', 'FMD بوسٹر')
        .replaceAll('FMD vaccination', 'FMD ویکسین')
        .replaceAll('HS vaccine', 'HS ویکسین')
        .replaceAll('BQ vaccine', 'BQ ویکسین')
        .replaceAll('PPR vaccine/booster', 'PPR ویکسین/بوسٹر')
        .replaceAll('ET vaccine', 'ET ویکسین')
        .replaceAll('Sheep pox vaccine', 'بھیڑ چیچک ویکسین')
        .replaceAll('Goat pox vaccine', 'بکری چیچک ویکسین')
        .replaceAll('dry-off', 'خشک دور')
        .replaceAll('pregnant', 'حاملہ')
        .replaceAll('No breeding', 'بریڈنگ نہ کریں')
        .replaceAll('Breed only when', 'بریڈنگ صرف اس وقت کریں جب')
        .replaceAll('Confirm conception', 'حمل کی تصدیق کریں')
        .replaceAll('Final pre-calving', 'بچے سے پہلے آخری')
        .replaceAll('Final pre-lambing', 'برہ دینے سے پہلے آخری')
        .replaceAll('Final pre-kidding', 'بچہ دینے سے پہلے آخری');
  }

  List<Map<String, String>> _pregnantPlanByAnimal(String animal) {
    if (animal == 'Buffalo') {
      return const [
        {
          'month': 'Month 1',
          'feed':
              'Green fodder 20-25 kg/day + concentrate 2.5 kg/day + mineral mix 50 g/day.',
          'vaccine': 'General health check, deworming if due.',
        },
        {
          'month': 'Month 2',
          'feed':
              'Green fodder 22-25 kg/day + concentrate 2.5-3 kg/day + clean water free choice.',
          'vaccine': 'FMD vaccination as per local schedule.',
        },
        {
          'month': 'Month 3',
          'feed': 'Add dry roughage 3-4 kg/day to improve rumen health.',
          'vaccine': 'HS vaccine (before monsoon region schedule).',
        },
        {
          'month': 'Month 4',
          'feed':
              'Concentrate up to 3 kg/day + calcium-phosphorus balance in ration.',
          'vaccine': 'Routine vet check and body condition score.',
        },
        {
          'month': 'Month 5',
          'feed':
              'Good quality silage 8-10 kg/day + green fodder 18-20 kg/day.',
          'vaccine': 'Deworming repeat (if parasite risk high).',
        },
        {
          'month': 'Month 6',
          'feed': 'Concentrate 3.5 kg/day + bypass protein 200 g/day.',
          'vaccine': 'BQ vaccine where recommended.',
        },
        {
          'month': 'Month 7',
          'feed':
              'Start transition feeding: increase energy density gradually.',
          'vaccine': 'FMD booster if due in your area.',
        },
        {
          'month': 'Month 8',
          'feed':
              'Concentrate 4 kg/day + mineral mix 60 g/day + vitamin ADE support.',
          'vaccine': 'Check for mastitis risk and udder edema signs.',
        },
        {
          'month': 'Month 9',
          'feed':
              'Last month: smaller frequent meals, high-quality digestible feed.',
          'vaccine': 'Final pre-calving vet exam; keep calving pen sanitized.',
        },
      ];
    }

    if (animal == 'Sheep') {
      return const [
        {
          'month': 'Month 1',
          'feed':
              'Good pasture + 200 g concentrate/day + mineral mix and clean water.',
          'vaccine': 'Deworming and body condition scoring.',
        },
        {
          'month': 'Month 2',
          'feed': 'Add quality hay 0.5-1 kg/day + concentrate 250 g/day.',
          'vaccine': 'Enterotoxemia (ET) vaccine as per local schedule.',
        },
        {
          'month': 'Month 3',
          'feed': 'Increase protein level slowly; avoid sudden feed changes.',
          'vaccine': 'PPR vaccine/booster if due in area program.',
        },
        {
          'month': 'Month 4',
          'feed':
              'Late gestation ration: concentrate 300-350 g/day + mineral support.',
          'vaccine': 'Sheep pox vaccine where recommended.',
        },
        {
          'month': 'Month 5',
          'feed':
              'Small frequent meals with highly digestible feed before lambing.',
          'vaccine': 'Final pre-lambing health check and clean lambing pen.',
        },
      ];
    }

    if (animal == 'Goat') {
      return const [
        {
          'month': 'Month 1',
          'feed':
              'Green browse + hay + 200 g concentrate/day + mineral mixture.',
          'vaccine': 'General check and deworming if needed.',
        },
        {
          'month': 'Month 2',
          'feed': 'Good quality forage + 250 g concentrate/day + clean water.',
          'vaccine': 'ET vaccine as per local plan.',
        },
        {
          'month': 'Month 3',
          'feed':
              'Increase nutrient density gradually to support fetal growth.',
          'vaccine': 'PPR vaccine/booster by district schedule.',
        },
        {
          'month': 'Month 4',
          'feed':
              'Concentrate 300-350 g/day + calcium-phosphorus mineral support.',
          'vaccine': 'Goat pox vaccine where advised.',
        },
        {
          'month': 'Month 5',
          'feed': 'Last month: small frequent digestible meals before kidding.',
          'vaccine': 'Final pre-kidding vet exam and kidding-pen hygiene.',
        },
      ];
    }

    return const [
      {
        'month': 'Month 1',
        'feed':
            'Green fodder 18-22 kg/day + concentrate 2-2.5 kg/day + mineral mix 40 g/day.',
        'vaccine': 'Pregnancy confirmation and baseline health check.',
      },
      {
        'month': 'Month 2',
        'feed': 'Dry roughage 2-3 kg/day + balanced protein ration.',
        'vaccine': 'FMD vaccination as per local calendar.',
      },
      {
        'month': 'Month 3',
        'feed': 'Concentrate 2.5 kg/day; avoid over-conditioning.',
        'vaccine': 'HS vaccine in endemic zones.',
      },
      {
        'month': 'Month 4',
        'feed': 'Silage 6-8 kg/day + green fodder 16-18 kg/day.',
        'vaccine': 'Routine deworming if due and fecal load is high.',
      },
      {
        'month': 'Month 5',
        'feed': 'Concentrate 3 kg/day + mineral mixture + salt lick.',
        'vaccine': 'BQ vaccine where advised by local vet.',
      },
      {
        'month': 'Month 6',
        'feed': 'Increase energy slowly; maintain fiber to prevent acidosis.',
        'vaccine': 'Vet exam and body condition adjustment.',
      },
      {
        'month': 'Month 7',
        'feed':
            'Transition diet starts: 10-15% more energy than mid-gestation.',
        'vaccine': 'FMD booster if due.',
      },
      {
        'month': 'Month 8',
        'feed': 'Concentrate 3.5-4 kg/day + calcium management + vitamin ADE.',
        'vaccine': 'Observe edema, lameness, and appetite changes.',
      },
      {
        'month': 'Month 9',
        'feed':
            'Pre-calving ration: highly digestible feed in small frequent meals.',
        'vaccine': 'Final pre-calving check and clean calving environment.',
      },
    ];
  }

  Widget _pregnantAnimalPlanCard(
    String animal,
    Color color,
    String selectedMonth,
  ) {
    final plan = _pregnantPlanByAnimal(animal);
    final row = plan.firstWhere(
      (item) => item['month'] == selectedMonth,
      orElse: () => plan.first,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('$animal Pregnant Plan', '${_animalUrdu(animal)} حمل پلان'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: color.withValues(alpha: 0.08),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthText(row['month']!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      'Feed: ${row['feed']!}',
                      'خوراک: ${_recText(row['feed']!)}',
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _t(
                      'Vaccination/Health: ${row['vaccine']!}',
                      'ویکسین/صحت: ${_recText(row['vaccine']!)}',
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _lactatingPlanByAnimal(String animal) {
    if (animal == 'Buffalo') {
      return const [
        {
          'month': 'Month 1 (0-30 days post-calving)',
          'feed':
              'Green fodder 22-25 kg/day + concentrate 1 kg per 2.5 liters milk + mineral mix 60 g/day + ad-lib water.',
          'breeding':
              'No breeding; focus on uterine recovery and heat observation from day 35 onward.',
        },
        {
          'month': 'Month 2',
          'feed':
              'High-energy ration with bypass protein 200 g/day; maintain fiber for rumen health.',
          'breeding':
              'Start regular heat detection twice daily; record first visible heat.',
        },
        {
          'month': 'Month 3',
          'feed':
              'Concentrate adjusted to milk yield; add yeast/probiotic support if milk drops.',
          'breeding':
              'Plan first service around 60-90 days if body condition and health are good.',
        },
        {
          'month': 'Month 4',
          'feed':
              'Silage 8-10 kg/day + quality green fodder + mineral/vitamin supplementation.',
          'breeding': 'AI on observed standing heat; use AM-PM rule.',
        },
        {
          'month': 'Month 5',
          'feed':
              'Sustain peak-milk diet with balanced protein-energy ratio and adequate calcium.',
          'breeding': 'Pregnancy diagnosis 45-60 days after breeding.',
        },
        {
          'month': 'Month 6',
          'feed':
              'If pregnant, avoid overfeeding concentrate and keep stable ration quality.',
          'breeding': 'Repeat breeding only if open and clinically fit.',
        },
        {
          'month': 'Month 7',
          'feed':
              'Gradual reduction in concentrate if milk declines; continue mineral mix.',
          'breeding':
              'Confirm pregnancy status and expected calving date planning.',
        },
        {
          'month': 'Month 8-10',
          'feed':
              'Move toward dry-period preparation: more roughage, controlled energy intake.',
          'breeding':
              'No further breeding if confirmed pregnant; focus on dry-off management.',
        },
      ];
    }

    if (animal == 'Sheep') {
      return const [
        {
          'month': 'Month 1 (0-30 days post-lambing)',
          'feed':
              'Good pasture + hay + 300 g concentrate/day + mineral support.',
          'breeding': 'No breeding; focus on recovery and lamb nursing.',
        },
        {
          'month': 'Month 2',
          'feed':
              'Increase concentrate based on milk output and body condition.',
          'breeding': 'Monitor heat signs after uterine recovery.',
        },
        {
          'month': 'Month 3',
          'feed': 'Maintain energy-protein balance and adequate clean water.',
          'breeding':
              'Breed only when body score is adequate and heat is clear.',
        },
        {
          'month': 'Month 4',
          'feed':
              'Adjust ration as milk declines; keep mineral and salt access.',
          'breeding': 'Service/ram exposure in planned breeding season.',
        },
        {
          'month': 'Month 5-6',
          'feed':
              'Prepare dry-off gradually with more roughage and less concentrate.',
          'breeding': 'Confirm conception and prepare next gestation plan.',
        },
      ];
    }

    if (animal == 'Goat') {
      return const [
        {
          'month': 'Month 1 (0-30 days post-kidding)',
          'feed':
              'Browse/forage + 300 g concentrate/day + mineral mix + water.',
          'breeding': 'No breeding in first month; postpartum recovery first.',
        },
        {
          'month': 'Month 2',
          'feed':
              'Boost ration quality for peak milk with protein-rich feed sources.',
          'breeding': 'Begin heat detection and record cycles.',
        },
        {
          'month': 'Month 3',
          'feed': 'Maintain balanced ration; avoid sudden concentrate spikes.',
          'breeding':
              'Consider breeding when healthy and target kidding season is near.',
        },
        {
          'month': 'Month 4',
          'feed':
              'Adjust concentrate to milk trend; continue mineral supplementation.',
          'breeding': 'Service on clear heat signs only.',
        },
        {
          'month': 'Month 5-6',
          'feed':
              'Transition toward dry period with controlled energy and good forage.',
          'breeding': 'Pregnancy check and next-cycle planning.',
        },
      ];
    }

    return const [
      {
        'month': 'Month 1 (0-30 days post-calving)',
        'feed':
            'Green fodder 18-22 kg/day + concentrate 1 kg per 2.5-3 liters milk + mineral mix 50 g/day.',
        'breeding':
            'No breeding in first month; monitor uterine involution and postpartum health.',
      },
      {
        'month': 'Month 2',
        'feed':
            'Increase ration density with quality concentrate and bypass fat if needed.',
        'breeding': 'Start heat detection and record estrus signs.',
      },
      {
        'month': 'Month 3',
        'feed':
            'Maintain high digestible energy and protein for peak lactation support.',
        'breeding':
            'First AI/service typically at 60-90 days postpartum if condition is suitable.',
      },
      {
        'month': 'Month 4',
        'feed':
            'Concentrate based on milk records; keep effective fiber to avoid acidosis.',
        'breeding': 'Breed on standing heat using AM-PM timing.',
      },
      {
        'month': 'Month 5',
        'feed':
            'Continue mineral-vitamin support (Ca, P, trace minerals) and clean water.',
        'breeding': 'Pregnancy test 45-60 days after service.',
      },
      {
        'month': 'Month 6',
        'feed':
            'If open, optimize feed and rebreed; if pregnant, stabilize intake and avoid stress.',
        'breeding': 'Repeat service if not pregnant and cycle is normal.',
      },
      {
        'month': 'Month 7',
        'feed':
            'Adjust ration as milk declines; keep body condition score around target.',
        'breeding': 'Pregnancy re-check and calving schedule update.',
      },
      {
        'month': 'Month 8-10',
        'feed':
            'Prepare for dry period with gradual concentrate reduction and quality roughage.',
        'breeding': 'No breeding if pregnant; set dry-off and transition plan.',
      },
    ];
  }

  Widget _lactatingAnimalPlanCard(
    String animal,
    Color color,
    String selectedMonth,
  ) {
    final plan = _lactatingPlanByAnimal(animal);
    final row = plan.firstWhere(
      (item) => item['month'] == selectedMonth,
      orElse: () => plan.first,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                '$animal Lactating Plan',
                '${_animalUrdu(animal)} دودھ پلانے کا پلان',
              ),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: color.withValues(alpha: 0.08),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _monthText(row['month']!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      'Feed: ${row['feed']!}',
                      'خوراک: ${_recText(row['feed']!)}',
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _t(
                      'Breeding: ${row['breeding']!}',
                      'بریڈنگ: ${_recText(row['breeding']!)}',
                    ),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageTile({
    required String id,
    IconData? icon,
    Widget? customIcon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isSelected = _selectedMilkStage == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMilkStage = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              customIcon ??
                  Icon(
                    icon!,
                    color: isSelected ? Colors.white : color,
                    size: 28,
                  ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool pregnant = _selectedMilkStage == 'pregnant';
    final selectedAnimalLabel = switch (_selectedMilkAnimal) {
      'buffalo' => 'Buffalo',
      'cow' => 'Cow',
      'sheep' => 'Sheep',
      'goat' => 'Goat',
      _ => 'Buffalo',
    };
    final selectedAnimalColor = switch (_selectedMilkAnimal) {
      'buffalo' => Colors.indigo.shade700,
      'cow' => Colors.green.shade700,
      'sheep' => Colors.blueGrey.shade700,
      'goat' => Colors.brown.shade700,
      _ => Colors.indigo.shade700,
    };
    final selectedAnimalAsset = switch (_selectedMilkAnimal) {
      'buffalo' => 'assets/images/measurement_buffalo.svg',
      'cow' => 'assets/images/measurement_cattle.svg',
      'sheep' => 'assets/images/measurement_sheep.svg',
      'goat' => 'assets/images/measurement_goat.svg',
      _ => 'assets/images/measurement_buffalo.svg',
    };
    final activePlan = pregnant
        ? _pregnantPlanByAnimal(selectedAnimalLabel)
        : _lactatingPlanByAnimal(selectedAnimalLabel);
    final monthOptions = activePlan.map((row) => row['month']!).toList();
    final monthKey =
        '${pregnant ? 'pregnant' : 'lactating'}|$selectedAnimalLabel';
    String selectedMonth =
        _selectedMonthByContext[monthKey] ?? monthOptions.first;
    if (!monthOptions.contains(selectedMonth)) {
      selectedMonth = monthOptions.first;
    }
    final title = pregnant ? 'Pregnant Animal Plan' : 'Lactating Animal Plan';
    final subtitle = pregnant
        ? 'Monthly feed and vaccination plan for selected animal'
        : 'Monthly feed and care plan for selected animal';

    return Scaffold(
      appBar: AppBar(title: Text(_t('Milk Section', 'دودھ سیکشن'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _t('Select milk stage', 'دودھ کا مرحلہ منتخب کریں'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stageTile(
                id: 'pregnant',
                customIcon: SizedBox(
                  width: 34,
                  height: 34,
                  child: SvgPicture.asset(
                    selectedAnimalAsset,
                    fit: BoxFit.contain,
                  ),
                ),
                title: _t('Pregnant', 'حاملہ'),
                subtitle: _t('Before calving', 'بچے سے پہلے'),
                color: Colors.deepOrange.shade600,
              ),
              const SizedBox(width: 12),
              _stageTile(
                id: 'lactating',
                icon: Icons.water_drop,
                title: _t('Lactating', 'دودھ پلانے والی'),
                subtitle: _t('After calving', 'بچے کے بعد'),
                color: Colors.blue.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Select animal', 'جانور منتخب کریں'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(_t('Buffalo', 'بھینس')),
                        selected: _selectedMilkAnimal == 'buffalo',
                        onSelected: (_) =>
                            setState(() => _selectedMilkAnimal = 'buffalo'),
                      ),
                      ChoiceChip(
                        label: Text(_t('Cow', 'گائے')),
                        selected: _selectedMilkAnimal == 'cow',
                        onSelected: (_) =>
                            setState(() => _selectedMilkAnimal = 'cow'),
                      ),
                      ChoiceChip(
                        label: Text(_t('Sheep', 'بھیڑ')),
                        selected: _selectedMilkAnimal == 'sheep',
                        onSelected: (_) =>
                            setState(() => _selectedMilkAnimal = 'sheep'),
                      ),
                      ChoiceChip(
                        label: Text(_t('Goat', 'بکری')),
                        selected: _selectedMilkAnimal == 'goat',
                        onSelected: (_) =>
                            setState(() => _selectedMilkAnimal = 'goat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pregnant
                        ? _t(
                            'Select pregnancy month',
                            'حمل کا مہینہ منتخب کریں',
                          )
                        : _t(
                            'Select lactation month',
                            'دودھ پلانے کا مہینہ منتخب کریں',
                          ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMonth,
                    decoration: InputDecoration(
                      labelText: _t('Month', 'مہینہ'),
                    ),
                    items: monthOptions
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(m),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonthByContext[monthKey] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      'Selected animal: $selectedAnimalLabel',
                      'منتخب جانور: ${_animalUrdu(selectedAnimalLabel)}',
                    ),
                    style: TextStyle(fontSize: 13, color: selectedAnimalColor),
                  ),
                  const SizedBox(height: 10),
                  if (pregnant) ...[
                    _pregnantAnimalPlanCard(
                      selectedAnimalLabel,
                      selectedAnimalColor,
                      selectedMonth,
                    ),
                    Text(
                      _t(
                        'Note: Adjust vaccination dates to your district veterinary calendar.',
                        'نوٹ: ویکسین کی تاریخیں اپنے ضلعی ویٹرنری کیلنڈر کے مطابق رکھیں۔',
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else ...[
                    _lactatingAnimalPlanCard(
                      selectedAnimalLabel,
                      selectedAnimalColor,
                      selectedMonth,
                    ),
                    Text(
                      _t(
                        'Note: Keep regular milk recording, udder hygiene, and hydration checks.',
                        'نوٹ: دودھ کا ریکارڈ، تھنوں کی صفائی، اور پانی کی نگرانی باقاعدگی سے کریں۔',
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BreedingSectionScreen extends StatefulWidget {
  const BreedingSectionScreen({super.key, required this.selectedLanguage});

  final String selectedLanguage;

  @override
  State<BreedingSectionScreen> createState() => _BreedingSectionScreenState();
}

class _BreedingSectionScreenState extends State<BreedingSectionScreen> {
  String _selectedAnimal = 'Buffalo';
  String _selectedBreedingPurpose = 'milk';
  String _selectedPakistanDistrict = 'Lahore';
  bool _showFullSireChecklist = false;
  final Map<String, String> _selectedBreedByAnimal = {};

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';
  String _t(String en, String ur) => _isUrdu ? ur : en;

  String _animalUrdu(String animal) {
    switch (animal) {
      case 'Buffalo':
        return 'بھینس';
      case 'Cow':
        return 'گائے';
      case 'Sheep':
        return 'بھیڑ';
      case 'Goat':
        return 'بکری';
      default:
        return animal;
    }
  }

  String _sireText(String text) {
    if (!_isUrdu) return text;
    return text
        .replaceAll(
          'proven milk-line AI sire',
          'تصدیق شدہ دودھ لائن اے آئی سانڈ',
        )
        .replaceAll('strong udder traits', 'تھن کی مضبوط خصوصیات')
        .replaceAll('high lactation daughters', 'زیادہ دودھ دینے والی نسل')
        .replaceAll('commercial Kundi semen line', 'کمرشل کنڈی سیمین لائن')
        .replaceAll('fertility-focused line', 'زرخیزی پر مبنی لائن')
        .replaceAll('balanced milk and fertility', 'متوازن دودھ اور زرخیزی')
        .replaceAll('high-yield line', 'زیادہ پیداوار لائن')
        .replaceAll('better fat percentage line', 'بہتر چکنائی فیصد لائن')
        .replaceAll('strong fertility line', 'مضبوط زرخیزی لائن')
        .replaceAll('milk persistency line', 'دودھ برقرار رکھنے کی لائن')
        .replaceAll('udder conformation line', 'تھن ساخت لائن')
        .replaceAll('heat tolerance line', 'گرمی برداشت لائن')
        .replaceAll('adaptability line', 'مطابقت لائن')
        .replaceAll('fat % line', 'چکنائی % لائن')
        .replaceAll('high milk volume', 'زیادہ دودھ مقدار')
        .replaceAll('better fertility balance', 'بہتر زرخیزی توازن')
        .replaceAll('commercial dairy cross line', 'کمرشل ڈیری کراس لائن')
        .replaceAll('high fat and SNF line', 'زیادہ چکنائی اور SNF لائن')
        .replaceAll(
          'medium-size efficient dairy line',
          'درمیانے سائز کی موثر ڈیری لائن',
        )
        .replaceAll('commercial crossbreeding line', 'کمرشل کراس بریڈنگ لائن')
        .replaceAll(
          'growth + milking ewe line',
          'نشوونما + دودھ دینے والی مادہ لائن',
        )
        .replaceAll('commercial flock sire line', 'کمرشل ریوڑ سانڈ لائن')
        .replaceAll('body size line', 'جسمانی سائز لائن')
        .replaceAll('maternal performance line', 'مادری کارکردگی لائن')
        .replaceAll('market lamb growth line', 'مارکیٹ برہ نشوونما لائن')
        .replaceAll('hardiness line', 'سخت جانی لائن')
        .replaceAll('commercial adaptation line', 'کمرشل مطابقت لائن')
        .replaceAll('milk + growth line', 'دودھ + نشوونما لائن')
        .replaceAll('large-frame line', 'بڑا جسمانی فریم لائن')
        .replaceAll('proven buck semen line', 'تصدیق شدہ بکر سیمین لائن')
        .replaceAll('dairy type line', 'ڈیری قسم لائن')
        .replaceAll('fertility and kidding line', 'زرخیزی اور بچے دینے کی لائن')
        .replaceAll('commercial buck line', 'کمرشل بکر لائن')
        .replaceAll('fast growth line', 'تیز نشوونما لائن')
        .replaceAll('kidding performance line', 'بچے دینے کی کارکردگی لائن')
        .replaceAll('farm adaptation line', 'فارم مطابقت لائن')
        .replaceAll(
          'Use locally proven AI sire from certified semen center',
          'قریبی مصدقہ سیمین سینٹر سے مقامی طور پر ثابت شدہ اے آئی سانڈ استعمال کریں',
        );
  }

  List<Map<String, String>> _sireSelectionQualities(
    String animal,
    String purpose,
    String breed,
  ) {
    final milkBase = <Map<String, String>>[
      {
        'en': 'High milk EBV/progeny records (daughter average milk yield).',
        'ur':
            'زیادہ دودھ کے EBV/نسلی ریکارڈ دیکھیں (بیٹیوں کی اوسط دودھ پیداوار)۔',
      },
      {
        'en': 'Udder and teat quality in dam-line to reduce mastitis risk.',
        'ur':
            'تھن اور چچک کی ساخت (ماں کی لائن) اچھی ہو تاکہ ماسٹائٹس کا خطرہ کم رہے۔',
      },
      {
        'en':
            'Fertility indicators: conception rate and calving interval of daughters.',
        'ur':
            'زرخیزی اشارے دیکھیں: کنسیپشن ریٹ اور بیٹیوں کے بچے دینے کا وقفہ۔',
      },
      {
        'en':
            'Ask vet: Is semen tested for motility, morphology, and disease-free status?',
        'ur':
            'ویٹ سے پوچھیں: کیا سیمین موٹیلیٹی، ساخت اور بیماری سے پاک ہونے کے لیے ٹیسٹ شدہ ہے؟',
      },
    ];

    final meatBase = <Map<String, String>>[
      {
        'en':
            'Fast growth genetics (ADG) and strong feed conversion efficiency.',
        'ur': 'تیز نشوونما (ADG) اور بہتر فیڈ کنورژن والی جینیات ترجیح دیں۔',
      },
      {
        'en':
            'Frame size and muscle depth suitable for your target market weight.',
        'ur': 'مارکیٹ وزن کے مطابق جسمانی فریم اور پٹھوں کی گہرائی مناسب ہو۔',
      },
      {
        'en': 'Calving ease/birth weight balance to avoid difficult births.',
        'ur':
            'پیدائش میں مشکل سے بچنے کے لیے برتھ ویٹ اور کیلونگ ایز کا توازن دیکھیں۔',
      },
      {
        'en':
            'Ask vet: Are there records for carcass quality, dressing %, and survivability?',
        'ur':
            'ویٹ سے پوچھیں: کیا کارکاس کوالٹی، ڈریسنگ فیصد اور بقا کے ریکارڈ موجود ہیں؟',
      },
    ];

    final speciesSpecific = <Map<String, String>>[];
    switch (animal) {
      case 'Buffalo':
        speciesSpecific.add({
          'en':
              'Prefer sires with proven heat tolerance and summer fertility in local herds.',
          'ur':
              'مقامی ریوڑ میں گرمی برداشت اور گرمیوں کی زرخیزی ثابت شدہ سانڈ کو ترجیح دیں۔',
        });
        break;
      case 'Cow':
        speciesSpecific.add({
          'en':
              'Prefer sires with strong feet/leg structure for long productive life.',
          'ur':
              'لمبی پیداواری عمر کے لیے ٹانگوں اور کھروں کی مضبوط ساخت والے سانڈ منتخب کریں۔',
        });
        break;
      case 'Sheep':
        speciesSpecific.add({
          'en': 'Choose rams with flock health history and low lambing losses.',
          'ur':
              'ایسے مینڈھے منتخب کریں جن میں ریوڑ صحت کا اچھا ریکارڈ اور کم برہ نقصان ہو۔',
        });
        break;
      case 'Goat':
        speciesSpecific.add({
          'en':
              'Choose bucks with strong kidding records and kid survival rates.',
          'ur':
              'ایسے بکر منتخب کریں جن میں بچے دینے اور بچوں کی بقا کا اچھا ریکارڈ ہو۔',
        });
        break;
    }

    final breedSpecific = <Map<String, String>>[];
    switch ('$animal|$purpose|$breed') {
      case 'Cow|meat|Brahman':
        breedSpecific.addAll([
          {
            'en':
                'Prioritize heat tolerance and tick resistance records for tropical conditions.',
            'ur':
                'گرم علاقوں کے لیے گرمی برداشت اور ٹِک مزاحمت کے ریکارڈ کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet for birth-weight trend in progeny to reduce calving difficulty.',
            'ur':
                'پیدائش میں مشکل کم کرنے کے لیے ویٹ سے نسل کے برتھ ویٹ رجحان کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Cow|meat|Angus Cross':
        breedSpecific.addAll([
          {
            'en':
                'Check marbling and carcass-quality records if selling to premium beef markets.',
            'ur':
                'اگر پریمیم بیف مارکیٹ ہدف ہو تو ماربلنگ اور کارکاس کوالٹی ریکارڈ چیک کریں۔',
          },
          {
            'en':
                'Ask vet about finishing age and feedlot performance of related offspring.',
            'ur':
                'ویٹ سے متعلقہ نسل کی فِنشنگ عمر اور فیڈلاٹ کارکردگی کے بارے میں پوچھیں۔',
          },
        ]);
        break;
      case 'Cow|milk|Sahiwal':
        breedSpecific.addAll([
          {
            'en':
                'Prefer lines with persistency across late lactation, not only peak yield.',
            'ur':
                'صرف پِیک پیداوار نہیں بلکہ لیٹ لیکٹیشن میں بھی مسلسل دودھ دینے والی لائن لیں۔',
          },
          {
            'en':
                'Ask vet for mastitis history and somatic cell count trends in daughters.',
            'ur':
                'ویٹ سے بیٹیوں میں ماسٹائٹس اور سومیٹک سیل کاؤنٹ رجحان کی معلومات لیں۔',
          },
        ]);
        break;
      case 'Buffalo|milk|Nili-Ravi':
        breedSpecific.addAll([
          {
            'en':
                'Select sires with higher fat % and strong udder attachment in female line.',
            'ur':
                'زیادہ چکنائی فیصد اور مادہ لائن میں مضبوط تھن جوڑ والے سانڈ منتخب کریں۔',
          },
          {
            'en':
                'Ask vet about reproductive efficiency under local feeding conditions.',
            'ur': 'ویٹ سے مقامی فیڈنگ حالات میں تولیدی کارکردگی کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Goat|milk|Beetal':
        breedSpecific.addAll([
          {
            'en':
                'Prefer bucks with higher kidding percentage and strong mothering lines.',
            'ur':
                'زیادہ بچے دینے کی شرح اور مضبوط مادری لائن والے بکر کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet about pedigree-linked disease history before insemination.',
            'ur':
                'انسیمینیشن سے پہلے ویٹ سے نسلی بیماری کے ریکارڈ کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Sheep|meat|Kajli':
        breedSpecific.addAll([
          {
            'en':
                'Choose rams with stronger loin width and fast pre-weaning lamb growth.',
            'ur':
                'ایسے مینڈھے منتخب کریں جن میں کمر کی چوڑائی بہتر اور برہ کی ابتدائی نشوونما تیز ہو۔',
          },
          {
            'en': 'Ask vet for lamb survival and parasite resistance records.',
            'ur': 'ویٹ سے برہ بقا اور پیراسائٹ مزاحمت کے ریکارڈ ضرور لیں۔',
          },
        ]);
        break;
      case 'Buffalo|milk|Murrah':
        breedSpecific.addAll([
          {
            'en':
                'Select Murrah sires with high milk-fat daughters and consistent lactation curves.',
            'ur':
                'ایسے مراح سانڈ منتخب کریں جن کی بیٹیاں زیادہ چکنائی اور مستقل لیکٹیشن دکھائیں۔',
          },
          {
            'en':
                'Ask vet for semen batch fertility reports from similar local production systems.',
            'ur':
                'ویٹ سے اسی طرح کے مقامی فارم سسٹم میں سیمین بیچ کی زرخیزی رپورٹ ضرور لیں۔',
          },
        ]);
        break;
      case 'Buffalo|milk|Kundi':
        breedSpecific.addAll([
          {
            'en':
                'Prefer Kundi lines with stronger udder attachment and better calving interval.',
            'ur':
                'کنڈی نسل میں مضبوط تھن جوڑ اور بہتر بچے دینے کے وقفے والی لائن لیں۔',
          },
          {
            'en':
                'Ask vet to verify records for repeat breeding and postpartum recovery.',
            'ur':
                'ویٹ سے ریپیٹ بریڈنگ اور پیدائش کے بعد بحالی کے ریکارڈ کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Buffalo|meat|Kundi':
        breedSpecific.addAll([
          {
            'en':
                'Choose sires with strong body depth and better feed conversion in male progeny.',
            'ur':
                'ایسے سانڈ لیں جن میں جسمانی گہرائی بہتر اور نر بچوں میں فیڈ کنورژن اچھا ہو۔',
          },
          {
            'en':
                'Ask vet for growth-to-market-age data of previous offspring groups.',
            'ur':
                'ویٹ سے پچھلی نسل کے مارکیٹ عمر تک نشوونما کے ڈیٹا کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Buffalo|meat|Murrah':
        breedSpecific.addAll([
          {
            'en':
                'Prioritize muscle depth and finishing performance under your ration type.',
            'ur':
                'اپنے راشن سسٹم کے مطابق پٹھوں کی گہرائی اور فِنشنگ کارکردگی کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet about carcass yield records and heat-stress resilience in offspring.',
            'ur':
                'ویٹ سے نسل میں کارکاس پیداوار اور گرمی کے دباؤ برداشت کے ریکارڈ پوچھیں۔',
          },
        ]);
        break;
      case 'Buffalo|meat|Nili-Ravi':
        breedSpecific.addAll([
          {
            'en':
                'Select lines with better frame growth and steady weight gain to finishing.',
            'ur':
                'ایسی لائن منتخب کریں جس میں جسمانی فریم بہتر ہو اور وزن میں مسلسل اضافہ ہو۔',
          },
          {
            'en':
                'Ask vet for field data on slaughter age and market acceptance.',
            'ur': 'ویٹ سے ذبح عمر اور مارکیٹ قبولیت کا فیلڈ ڈیٹا ضرور لیں۔',
          },
        ]);
        break;
      case 'Cow|milk|Friesian Cross':
        breedSpecific.addAll([
          {
            'en':
                'Focus on udder health and longevity traits to control mastitis losses.',
            'ur':
                'ماسٹائٹس نقصان کم کرنے کے لیے تھن صحت اور لمبی پیداواری عمر کی خصوصیات دیکھیں۔',
          },
          {
            'en':
                'Ask vet for daughter fertility and heat-stress performance under local climate.',
            'ur':
                'ویٹ سے بیٹیوں کی زرخیزی اور مقامی موسم میں گرمی برداشت کارکردگی پوچھیں۔',
          },
        ]);
        break;
      case 'Cow|milk|Jersey Cross':
        breedSpecific.addAll([
          {
            'en':
                'Prefer sires with higher fat and SNF inheritance for value-added milk.',
            'ur':
                'ویلیو ایڈیڈ دودھ کے لیے زیادہ چکنائی اور SNF منتقل کرنے والی لائن کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet to confirm fertility, calving ease, and body-condition stability.',
            'ur':
                'ویٹ سے زرخیزی، آسان پیدائش اور باڈی کنڈیشن استحکام کی تصدیق کروائیں۔',
          },
        ]);
        break;
      case 'Cow|milk|Cholistani':
        breedSpecific.addAll([
          {
            'en':
                'Choose adaptive lines with stable yield in hot and low-input conditions.',
            'ur':
                'گرم اور کم وسائل والے ماحول میں مستحکم پیداوار دینے والی موافق لائن لیں۔',
          },
          {
            'en':
                'Ask vet for fertility and disease-resistance trends in village herds.',
            'ur':
                'ویٹ سے دیہی ریوڑ میں زرخیزی اور بیماری مزاحمت کے رجحانات پوچھیں۔',
          },
        ]);
        break;
      case 'Cow|meat|Cholistani':
        breedSpecific.addAll([
          {
            'en':
                'Prefer hardy beef lines with stronger growth under grazing + stall feeding.',
            'ur':
                'چرائی اور باڑے دونوں نظام میں بہتر نشوونما دینے والی مضبوط بیف لائن منتخب کریں۔',
          },
          {
            'en':
                'Ask vet about frame score and market-weight age from local records.',
            'ur':
                'ویٹ سے مقامی ریکارڈ کے مطابق فریم اسکور اور مارکیٹ وزن عمر پوچھیں۔',
          },
        ]);
        break;
      case 'Cow|meat|Sahiwal':
        breedSpecific.addAll([
          {
            'en':
                'Choose sires balancing growth with calving ease for dual-purpose herds.',
            'ur':
                'دوہری پیداوار والے ریوڑ کے لیے نشوونما اور آسان پیدائش کا متوازن سانڈ منتخب کریں۔',
          },
          {
            'en':
                'Ask vet for survival, fertility, and finishing weight records of offspring.',
            'ur':
                'ویٹ سے نسل میں بقا، زرخیزی اور فِنشنگ وزن کے ریکارڈ کی تصدیق کریں۔',
          },
        ]);
        break;
      case 'Sheep|milk|Lohi':
        breedSpecific.addAll([
          {
            'en':
                'Prefer rams from ewes with consistent milking and good mothering behavior.',
            'ur':
                'ایسے مینڈھے لیں جن کی مادہ لائن میں مسلسل دودھ اور اچھی مادری صلاحیت ہو۔',
          },
          {
            'en':
                'Ask vet for lamb survival and udder-health history in related ewes.',
            'ur':
                'ویٹ سے متعلقہ ماداؤں میں برہ بقا اور تھن صحت کا ریکارڈ پوچھیں۔',
          },
        ]);
        break;
      case 'Sheep|milk|Kajli':
        breedSpecific.addAll([
          {
            'en':
                'Select Kajli lines with better maternal milk and lamb growth balance.',
            'ur':
                'کاجلی نسل میں مادری دودھ اور برہ نشوونما کا متوازن ریکارڈ دیکھیں۔',
          },
          {
            'en':
                'Ask vet to review prolificacy and lambing interval data before selection.',
            'ur':
                'ویٹ سے انتخاب سے پہلے زیادہ بچوں کی شرح اور برہ وقفہ کا ڈیٹا چیک کروائیں۔',
          },
        ]);
        break;
      case 'Sheep|meat|Thalli':
        breedSpecific.addAll([
          {
            'en':
                'Prioritize hardiness and weight gain on range-based feeding systems.',
            'ur':
                'رینج فیڈنگ نظام میں سخت جانی اور وزن بڑھنے کی صلاحیت کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet for parasite resilience and flock mortality records.',
            'ur': 'ویٹ سے پیراسائٹ مزاحمت اور ریوڑ اموات کے ریکارڈ ضرور لیں۔',
          },
        ]);
        break;
      case 'Sheep|meat|Lohi':
        breedSpecific.addAll([
          {
            'en':
                'Choose Lohi rams with strong growth and acceptable carcass conformation.',
            'ur':
                'لوہی مینڈھے منتخب کریں جن میں بہتر نشوونما اور مناسب کارکاس ساخت ہو۔',
          },
          {
            'en':
                'Ask vet for feed efficiency and finishing-time records in lambs.',
            'ur':
                'ویٹ سے برہ میں فیڈ ایفیشنسی اور فِنشنگ وقت کے ریکارڈ پوچھیں۔',
          },
        ]);
        break;
      case 'Goat|milk|Kamori':
        breedSpecific.addAll([
          {
            'en':
                'Prefer Kamori bucks with good udder traits and longer milking duration in daughters.',
            'ur':
                'کاموری بکر میں بیٹیوں کے بہتر تھن اور لمبے دودھ دورانیے کی خصوصیات دیکھیں۔',
          },
          {
            'en':
                'Ask vet about kidding interval, teat defects, and mastitis history.',
            'ur':
                'ویٹ سے بچے دینے کے وقفے، چچک نقائص اور ماسٹائٹس ہسٹری کی معلومات لیں۔',
          },
        ]);
        break;
      case 'Goat|meat|Teddy':
        breedSpecific.addAll([
          {
            'en':
                'Choose compact bucks with rapid kid growth and better survivability.',
            'ur':
                'ایسے ٹیڈی بکر منتخب کریں جن میں بچے کی تیز نشوونما اور بہتر بقا ہو۔',
          },
          {
            'en':
                'Ask vet for weaning weight and kid mortality records by sire line.',
            'ur':
                'ویٹ سے بکری بچے کے ویوننگ وزن اور اموات کے ریکارڈ (سانڈ لائن کے مطابق) پوچھیں۔',
          },
        ]);
        break;
      case 'Goat|meat|Beetal':
        breedSpecific.addAll([
          {
            'en':
                'Select larger-frame Beetal lines with stronger muscle gain to market age.',
            'ur':
                'بڑے فریم اور مارکیٹ عمر تک بہتر پٹھا بڑھانے والی بیٹل لائن منتخب کریں۔',
          },
          {
            'en':
                'Ask vet for carcass yield and feed efficiency data from related kids.',
            'ur':
                'ویٹ سے متعلقہ بچوں میں کارکاس پیداوار اور فیڈ ایفیشنسی ڈیٹا حاصل کریں۔',
          },
        ]);
        break;
      case 'Goat|meat|Kamori':
        breedSpecific.addAll([
          {
            'en':
                'Prioritize frame growth and adaptability for your housing and climate system.',
            'ur':
                'اپنے رہائشی اور موسمی نظام کے مطابق فریم نشوونما اور مطابقت کو ترجیح دیں۔',
          },
          {
            'en':
                'Ask vet for breeding soundness exam and herd-level disease screening results.',
            'ur':
                'ویٹ سے بریڈنگ ساؤنڈنس ٹیسٹ اور ریوڑ کی بیماری اسکریننگ نتائج طلب کریں۔',
          },
        ]);
        break;
    }

    final base = purpose == 'milk' ? milkBase : meatBase;
    return [...breedSpecific, ...speciesSpecific, ...base];
  }

  List<String> _breedsByAnimal(String animal, String purpose) {
    switch ('$animal|$purpose') {
      case 'Buffalo|milk':
        return const ['Nili-Ravi', 'Murrah', 'Kundi'];
      case 'Buffalo|meat':
        return const ['Kundi', 'Murrah', 'Nili-Ravi'];
      case 'Cow|milk':
        return const [
          'Sahiwal',
          'Friesian Cross',
          'Jersey Cross',
          'Cholistani',
        ];
      case 'Cow|meat':
        return const ['Cholistani', 'Sahiwal', 'Brahman', 'Angus Cross'];
      case 'Sheep|milk':
        return const ['Lohi', 'Kajli'];
      case 'Sheep|meat':
        return const ['Kajli', 'Thalli', 'Lohi'];
      case 'Goat|milk':
        return const ['Beetal', 'Kamori'];
      case 'Goat|meat':
        return const ['Teddy', 'Beetal', 'Kamori'];
      default:
        return const ['Nili-Ravi'];
    }
  }

  List<String> _commercialSireSuggestions(
    String animal,
    String purpose,
    String breed,
  ) {
    switch ('$animal|$purpose|$breed') {
      case 'Buffalo|milk|Nili-Ravi':
        return const [
          'NR-Alpha (proven milk-line AI sire)',
          'NR-Gold (strong udder traits)',
          'NR-Max (high lactation daughters)',
        ];
      case 'Buffalo|milk|Kundi':
        return const [
          'KD-Prime (commercial Kundi semen line)',
          'KD-Star (fertility-focused line)',
          'KD-Elite (balanced milk and fertility)',
        ];
      case 'Buffalo|milk|Murrah':
        return const [
          'Murrah-M1 (high-yield line)',
          'Murrah-M2 (better fat percentage line)',
          'Murrah-M3 (strong fertility line)',
        ];
      case 'Cow|milk|Sahiwal':
        return const [
          'Sahiwal-S1 (milk persistency line)',
          'Sahiwal-S2 (udder conformation line)',
          'Sahiwal-S3 (heat tolerance line)',
        ];
      case 'Cow|milk|Cholistani':
        return const [
          'Chol-C1 (adaptability line)',
          'Chol-C2 (fat % line)',
          'Chol-C3 (fertility line)',
        ];
      case 'Cow|milk|Friesian Cross':
        return const [
          'HFX-F1 (high milk volume)',
          'HFX-F2 (better fertility balance)',
          'HFX-F3 (commercial dairy cross line)',
        ];
      case 'Cow|milk|Jersey Cross':
        return const [
          'JRX-J1 (high fat and SNF line)',
          'JRX-J2 (medium-size efficient dairy line)',
          'JRX-J3 (commercial crossbreeding line)',
        ];
      case 'Sheep|milk|Lohi':
        return const [
          'Lohi-L1 (growth + milking ewe line)',
          'Lohi-L2 (fertility-focused line)',
          'Lohi-L3 (commercial flock sire line)',
        ];
      case 'Sheep|milk|Kajli':
        return const [
          'Kajli-K1 (body size line)',
          'Kajli-K2 (maternal performance line)',
          'Kajli-K3 (market lamb growth line)',
        ];
      case 'Sheep|milk|Thalli':
        return const [
          'Thalli-T1 (hardiness line)',
          'Thalli-T2 (fertility line)',
          'Thalli-T3 (commercial adaptation line)',
        ];
      case 'Goat|milk|Beetal':
        return const [
          'Beetal-B1 (milk + growth line)',
          'Beetal-B2 (large-frame line)',
          'Beetal-B3 (proven buck semen line)',
        ];
      case 'Goat|milk|Kamori':
        return const [
          'Kamori-K1 (dairy type line)',
          'Kamori-K2 (fertility and kidding line)',
          'Kamori-K3 (commercial buck line)',
        ];
      case 'Goat|milk|Teddy':
        return const [
          'Teddy-T1 (fast growth line)',
          'Teddy-T2 (kidding performance line)',
          'Teddy-T3 (farm adaptation line)',
        ];
      case 'Buffalo|meat|Kundi':
        return const [
          'KD-Meat1 (frame growth line)',
          'KD-Meat2 (finishing efficiency line)',
          'KD-Meat3 (market-weight line)',
        ];
      case 'Buffalo|meat|Murrah':
        return const [
          'MR-Meat1 (rapid growth line)',
          'MR-Meat2 (muscle depth line)',
          'MR-Meat3 (carcass balance line)',
        ];
      case 'Buffalo|meat|Nili-Ravi':
        return const [
          'NR-Meat1 (body size line)',
          'NR-Meat2 (feed conversion line)',
          'NR-Meat3 (commercial beef line)',
        ];
      case 'Cow|meat|Cholistani':
        return const [
          'CH-Meat1 (hardy beef line)',
          'CH-Meat2 (growth line)',
          'CH-Meat3 (market adaptability line)',
        ];
      case 'Cow|meat|Sahiwal':
        return const [
          'SW-Meat1 (dual-purpose line)',
          'SW-Meat2 (frame growth line)',
          'SW-Meat3 (fertility + growth line)',
        ];
      case 'Cow|meat|Brahman':
        return const [
          'BR-Meat1 (heat-tolerant beef line)',
          'BR-Meat2 (frame growth line)',
          'BR-Meat3 (hardy feedlot line)',
        ];
      case 'Cow|meat|Angus Cross':
        return const [
          'AX-Meat1 (early maturity line)',
          'AX-Meat2 (carcass quality line)',
          'AX-Meat3 (market finishing line)',
        ];
      case 'Sheep|meat|Kajli':
        return const [
          'KJ-Meat1 (heavy lamb line)',
          'KJ-Meat2 (muscle line)',
          'KJ-Meat3 (market lamb line)',
        ];
      case 'Sheep|meat|Thalli':
        return const [
          'TH-Meat1 (hardy range line)',
          'TH-Meat2 (growth line)',
          'TH-Meat3 (flock meat line)',
        ];
      case 'Sheep|meat|Lohi':
        return const [
          'LH-Meat1 (dual utility line)',
          'LH-Meat2 (maternal + growth line)',
          'LH-Meat3 (commercial flock line)',
        ];
      case 'Goat|meat|Teddy':
        return const [
          'TD-Meat1 (fast growth line)',
          'TD-Meat2 (compact meat line)',
          'TD-Meat3 (market kid line)',
        ];
      case 'Goat|meat|Beetal':
        return const [
          'BT-Meat1 (large-frame line)',
          'BT-Meat2 (muscle gain line)',
          'BT-Meat3 (commercial meat line)',
        ];
      case 'Goat|meat|Kamori':
        return const [
          'KM-Meat1 (frame + growth line)',
          'KM-Meat2 (adaptability line)',
          'KM-Meat3 (commercial buck line)',
        ];
      default:
        return const ['Use locally proven AI sire from certified semen center'];
    }
  }

  List<Map<String, String>> _pakistanMarketSireReferences(
    String animal,
    String purpose,
  ) {
    switch ('$animal|$purpose') {
      case 'Cow|milk':
        return const [
          {
            'en': 'Holstein line (e.g., Supersire)',
            'ur': 'ہولسٹین لائن (مثلاً Supersire)',
          },
          {
            'en': 'Holstein line (e.g., Mogul)',
            'ur': 'ہولسٹین لائن (مثلاً Mogul)',
          },
          {
            'en': 'Jersey line (e.g., Valentino)',
            'ur': 'جرسی لائن (مثلاً Valentino)',
          },
          {
            'en': 'Sahiwal progeny-tested local codes',
            'ur': 'ساہیوال پروجنی ٹیسٹڈ مقامی کوڈز',
          },
        ];
      case 'Cow|meat':
        return const [
          {
            'en': 'Brahman line imports (city distributors)',
            'ur': 'براہمن لائن امپورٹس (شہری ڈسٹری بیوٹرز)',
          },
          {
            'en': 'Angus Cross beef semen lines',
            'ur': 'اینگس کراس بیف سیمین لائنز',
          },
          {
            'en': 'Cholistani hardy beef-type local lines',
            'ur': 'چولستانی مضبوط بیف ٹائپ مقامی لائنز',
          },
          {
            'en': 'Sahiwal dual-purpose meat lines',
            'ur': 'ساہیوال دوہری مقصد گوشت لائنز',
          },
        ];
      case 'Buffalo|milk':
        return const [
          {
            'en': 'Nili-Ravi proven local AI codes',
            'ur': 'نیلی راوی ثابت شدہ مقامی اے آئی کوڈز',
          },
          {
            'en': 'Murrah high-fat line imports',
            'ur': 'مراح ہائی فیٹ لائن امپورٹس',
          },
          {
            'en': 'Kundi fertility-focused local lines',
            'ur': 'کنڈی زرخیزی پر مبنی مقامی لائنز',
          },
        ];
      case 'Buffalo|meat':
        return const [
          {
            'en': 'Nili-Ravi frame-growth local lines',
            'ur': 'نیلی راوی فریم گروتھ مقامی لائنز',
          },
          {'en': 'Murrah meat-finishing lines', 'ur': 'مراح میٹ فِنشنگ لائنز'},
          {'en': 'Kundi market-weight lines', 'ur': 'کنڈی مارکیٹ ویٹ لائنز'},
        ];
      case 'Sheep|milk':
        return const [
          {
            'en': 'Lohi milk-maternal ram lines',
            'ur': 'لوہی دودھ و مادری مینڈھا لائنز',
          },
          {
            'en': 'Kajli dual milk-growth lines',
            'ur': 'کاجلی دودھ + نشوونما لائنز',
          },
        ];
      case 'Sheep|meat':
        return const [
          {'en': 'Kajli heavy lamb lines', 'ur': 'کاجلی ہیوی لیمب لائنز'},
          {'en': 'Thalli hardy meat lines', 'ur': 'تھلی مضبوط گوشت لائنز'},
          {
            'en': 'Lohi commercial flock meat lines',
            'ur': 'لوہی کمرشل فلاک گوشت لائنز',
          },
        ];
      case 'Goat|milk':
        return const [
          {
            'en': 'Beetal dairy-growth buck lines',
            'ur': 'بیٹل ڈیری-گروتھ بکر لائنز',
          },
          {
            'en': 'Kamori dairy-type buck lines',
            'ur': 'کاموری ڈیری ٹائپ بکر لائنز',
          },
        ];
      case 'Goat|meat':
        return const [
          {
            'en': 'Teddy fast-growth buck lines',
            'ur': 'ٹیڈی تیز نشوونما بکر لائنز',
          },
          {
            'en': 'Beetal large-frame meat lines',
            'ur': 'بیٹل بڑے فریم گوشت لائنز',
          },
          {
            'en': 'Kamori adaptable commercial meat lines',
            'ur': 'کاموری موافق کمرشل گوشت لائنز',
          },
        ];
      default:
        return const [
          {
            'en': 'Ask nearest certified semen station for latest market list',
            'ur':
                'تازہ مارکیٹ لسٹ کے لیے قریبی مصدقہ سیمین اسٹیشن سے رابطہ کریں',
          },
        ];
    }
  }

  List<String> _pakistanDistricts() {
    return const [
      'Lahore',
      'Karachi',
      'Peshawar',
      'Quetta',
      'Hyderabad',
      'Gilgit',
      'Muzaffarabad',
    ];
  }

  Future<void> _openUriWithFeedback(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Unable to open link. Please check your phone/WhatsApp setup.',
              'لنک نہیں کھل سکا۔ براہ کرم فون/واٹس ایپ سیٹ اپ چیک کریں۔',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _callSupplier(String phone) async {
    await _openUriWithFeedback(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _openSupplierWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final pakNumber = cleaned.startsWith('0')
        ? '92${cleaned.substring(1)}'
        : cleaned;
    await _openUriWithFeedback(Uri.parse('https://wa.me/$pakNumber'));
  }

  List<Map<String, String>> _districtSupplierPlaceholders(String district) {
    switch (district) {
      case 'Lahore':
        return const [
          {
            'en': 'Government Semen Unit (District Livestock Office), Lahore',
            'ur': 'سرکاری سیمین یونٹ (ضلع لائیوسٹاک آفس)، لاہور',
            'phone': '0300-0000001',
            'whatsapp': '0300-0000001',
          },
          {
            'en': 'Registered AI Technician Network - Lahore peri-urban belt',
            'ur': 'رجسٹرڈ اے آئی ٹیکنیشن نیٹ ورک - لاہور پیری اربن بیلٹ',
            'phone': '0300-0000002',
            'whatsapp': '0300-0000002',
          },
        ];
      case 'Karachi':
        return const [
          {
            'en': 'District Livestock Breeding Desk, Karachi',
            'ur': 'ضلع لائیوسٹاک بریڈنگ ڈیسک، کراچی',
            'phone': '0300-0000051',
            'whatsapp': '0300-0000051',
          },
          {
            'en': 'Certified AI Technician Network - Karachi division',
            'ur': 'مصدقہ اے آئی ٹیکنیشن نیٹ ورک - کراچی ڈویژن',
            'phone': '0300-0000052',
            'whatsapp': '0300-0000052',
          },
        ];
      case 'Peshawar':
        return const [
          {
            'en': 'District Livestock Service Point, Peshawar',
            'ur': 'ضلع لائیوسٹاک سروس پوائنٹ، پشاور',
            'phone': '0300-0000061',
            'whatsapp': '0300-0000061',
          },
          {
            'en': 'Certified Breeding Providers - Peshawar/Charsadda',
            'ur': 'مصدقہ بریڈنگ فراہم کنندگان - پشاور/چارسدہ',
            'phone': '0300-0000062',
            'whatsapp': '0300-0000062',
          },
        ];
      case 'Quetta':
        return const [
          {
            'en': 'District Livestock Breeding Unit, Quetta',
            'ur': 'ضلع لائیوسٹاک بریڈنگ یونٹ، کوئٹہ',
            'phone': '0300-0000071',
            'whatsapp': '0300-0000071',
          },
          {
            'en': 'Certified Semen Access Point - Quetta division',
            'ur': 'مصدقہ سیمین رسائی پوائنٹ - کوئٹہ ڈویژن',
            'phone': '0300-0000072',
            'whatsapp': '0300-0000072',
          },
        ];
      case 'Hyderabad':
        return const [
          {
            'en': 'District Livestock Extension Desk, Hyderabad',
            'ur': 'ضلع لائیوسٹاک ایکسٹینشن ڈیسک، حیدرآباد',
            'phone': '0300-0000081',
            'whatsapp': '0300-0000081',
          },
          {
            'en': 'Registered AI Providers - Hyderabad/Tando belt',
            'ur': 'رجسٹرڈ اے آئی فراہم کنندگان - حیدرآباد/ٹنڈو بیلٹ',
            'phone': '0300-0000082',
            'whatsapp': '0300-0000082',
          },
        ];
      case 'Gilgit':
        return const [
          {
            'en': 'Regional Livestock Breeding Desk, Gilgit',
            'ur': 'علاقائی لائیوسٹاک بریڈنگ ڈیسک، گلگت',
            'phone': '0300-0000101',
            'whatsapp': '0300-0000101',
          },
          {
            'en': 'Certified Field AI Contact - Gilgit Baltistan',
            'ur': 'مصدقہ فیلڈ اے آئی رابطہ - گلگت بلتستان',
            'phone': '0300-0000102',
            'whatsapp': '0300-0000102',
          },
        ];
      case 'Muzaffarabad':
        return const [
          {
            'en': 'District Livestock Support Center, Muzaffarabad',
            'ur': 'ضلع لائیوسٹاک معاونتی مرکز، مظفرآباد',
            'phone': '0300-0000111',
            'whatsapp': '0300-0000111',
          },
          {
            'en': 'Registered Breeding Service Providers - AJK region',
            'ur': 'رجسٹرڈ بریڈنگ سروس فراہم کنندگان - آزاد کشمیر خطہ',
            'phone': '0300-0000112',
            'whatsapp': '0300-0000112',
          },
        ];
      case 'Faisalabad':
        return const [
          {
            'en': 'District Livestock Semen Point, Faisalabad',
            'ur': 'ضلع لائیوسٹاک سیمین پوائنٹ، فیصل آباد',
            'phone': '0300-0000011',
            'whatsapp': '0300-0000011',
          },
          {
            'en':
                'Private Certified Breeding Service Providers - Samundri/Jaranwala',
            'ur': 'نجی مصدقہ بریڈنگ سروس فراہم کنندگان - سمندری/جڑانوالہ',
            'phone': '0300-0000012',
            'whatsapp': '0300-0000012',
          },
        ];
      case 'Multan':
        return const [
          {
            'en': 'Regional Livestock Breeding Desk, Multan',
            'ur': 'علاقائی لائیوسٹاک بریڈنگ ڈیسک، ملتان',
            'phone': '0300-0000021',
            'whatsapp': '0300-0000021',
          },
          {
            'en': 'Certified AI Route Providers - Shujabad/Jalalpur',
            'ur': 'مصدقہ اے آئی روٹ فراہم کنندگان - شجاع آباد/جلال پور',
            'phone': '0300-0000022',
            'whatsapp': '0300-0000022',
          },
        ];
      case 'Sahiwal':
        return const [
          {
            'en': 'Sahiwal Breed Support and Semen Access Point',
            'ur': 'ساہیوال نسل معاونت اور سیمین رسائی پوائنٹ',
            'phone': '0300-0000031',
            'whatsapp': '0300-0000031',
          },
          {
            'en': 'Registered Field AI Workers - Okara/Sahiwal corridor',
            'ur': 'رجسٹرڈ فیلڈ اے آئی ورکرز - اوکاڑہ/ساہیوال کوریڈور',
            'phone': '0300-0000032',
            'whatsapp': '0300-0000032',
          },
        ];
      case 'Bahawalpur':
        return const [
          {
            'en': 'District Livestock Breeding Unit, Bahawalpur',
            'ur': 'ضلع لائیوسٹاک بریڈنگ یونٹ، بہاولپور',
            'phone': '0300-0000041',
            'whatsapp': '0300-0000041',
          },
          {
            'en': 'Certified Semen Supply Channels - Yazman/Hasilpur',
            'ur': 'مصدقہ سیمین سپلائی چینلز - یزمان/حاصل پور',
            'phone': '0300-0000042',
            'whatsapp': '0300-0000042',
          },
        ];
      default:
        return const [
          {
            'en':
                'Contact nearest District Livestock Office for updated certified suppliers',
            'ur':
                'اپ ڈیٹ مصدقہ سپلائرز کے لیے قریبی ضلع لائیوسٹاک آفس سے رابطہ کریں',
            'phone': '0300-0000099',
            'whatsapp': '0300-0000099',
          },
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final breedKey = '$_selectedAnimal|$_selectedBreedingPurpose';
    final breedOptions = _breedsByAnimal(
      _selectedAnimal,
      _selectedBreedingPurpose,
    );
    String selectedBreed =
        _selectedBreedByAnimal[breedKey] ?? breedOptions.first;
    if (!breedOptions.contains(selectedBreed)) {
      selectedBreed = breedOptions.first;
      _selectedBreedByAnimal[breedKey] = selectedBreed;
    }
    final sireSuggestions = _commercialSireSuggestions(
      _selectedAnimal,
      _selectedBreedingPurpose,
      selectedBreed,
    );
    final pakistanMarketRefs = _pakistanMarketSireReferences(
      _selectedAnimal,
      _selectedBreedingPurpose,
    );
    final districtSupplierRefs = _districtSupplierPlaceholders(
      _selectedPakistanDistrict,
    );
    final sireQualityChecklist = _sireSelectionQualities(
      _selectedAnimal,
      _selectedBreedingPurpose,
      selectedBreed,
    );
    final topSireQualityChecklist = sireQualityChecklist.take(5).toList();
    final displayedSireChecklist = _showFullSireChecklist
        ? sireQualityChecklist
        : topSireQualityChecklist;

    return Scaffold(
      appBar: AppBar(title: Text(_t('Breeding Section', 'بریڈنگ سیکشن'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _t('Select animal', 'جانور منتخب کریں'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_t('Buffalo', 'بھینس')),
                selected: _selectedAnimal == 'Buffalo',
                onSelected: (_) => setState(() => _selectedAnimal = 'Buffalo'),
              ),
              ChoiceChip(
                label: Text(_t('Cow', 'گائے')),
                selected: _selectedAnimal == 'Cow',
                onSelected: (_) => setState(() => _selectedAnimal = 'Cow'),
              ),
              ChoiceChip(
                label: Text(_t('Sheep', 'بھیڑ')),
                selected: _selectedAnimal == 'Sheep',
                onSelected: (_) => setState(() => _selectedAnimal = 'Sheep'),
              ),
              ChoiceChip(
                label: Text(_t('Goat', 'بکری')),
                selected: _selectedAnimal == 'Goat',
                onSelected: (_) => setState(() => _selectedAnimal = 'Goat'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'Use of quality sires will help you develop better quality animals.',
              'معیاری سانڈ کے استعمال سے آپ بہتر معیار کے جانور تیار کر سکتے ہیں۔',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Select breeding purpose', 'بریڈنگ کا مقصد منتخب کریں'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(_t('Milk', 'دودھ')),
                        selected: _selectedBreedingPurpose == 'milk',
                        onSelected: (_) =>
                            setState(() => _selectedBreedingPurpose = 'milk'),
                      ),
                      ChoiceChip(
                        label: Text(_t('Meat', 'گوشت')),
                        selected: _selectedBreedingPurpose == 'meat',
                        onSelected: (_) =>
                            setState(() => _selectedBreedingPurpose = 'meat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('Select breed', 'نسل منتخب کریں'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBreed,
                    decoration: InputDecoration(labelText: _t('Breed', 'نسل')),
                    items: breedOptions
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b,
                            child: Text(b),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedBreedByAnimal[breedKey] = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'Suggested commercially available sires',
                      'تجویز کردہ دستیاب سانڈ',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...sireSuggestions.map(
                    (sire) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '- ${_sireText(sire)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'Popular in Pakistan market (verify locally)',
                      'پاکستان مارکیٹ میں مشہور (مقامی تصدیق لازمی)',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...pakistanMarketRefs.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '- ${_t(item['en']!, item['ur']!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  Text(
                    _t(
                      'Always verify straw code, progeny records, conception rate, and disease-free certificate before purchase.',
                      'خریداری سے پہلے اسٹرا کوڈ، نسلی ریکارڈ، کنسیپشن ریٹ اور بیماری سے پاک سرٹیفکیٹ لازماً چیک کریں۔',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'District-wise supplier placeholders (Pakistan)',
                      'ضلع وار سپلائر پلیس ہولڈرز (پاکستان)',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPakistanDistrict,
                    decoration: InputDecoration(
                      labelText: _t('District', 'ضلع'),
                    ),
                    items: _pakistanDistricts()
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d,
                            child: Text(d),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedPakistanDistrict = value;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  ...districtSupplierRefs.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(item['en']!, item['ur']!),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Phone', 'فون')}: ${item['phone']!}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _callSupplier(item['phone']!),
                                  icon: const Icon(Icons.call, size: 18),
                                  label: Text(_t('Call', 'کال')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openSupplierWhatsApp(item['whatsapp']!),
                                  icon: const Icon(Icons.chat, size: 18),
                                  label: Text(_t('WhatsApp', 'واٹس ایپ')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _t(
                      'Replace these placeholders with your verified local contacts and AI technician phone numbers.',
                      'ان پلیس ہولڈرز کو اپنے تصدیق شدہ مقامی رابطوں اور اے آئی ٹیکنیشن فون نمبرز سے تبدیل کریں۔',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      _showFullSireChecklist
                          ? 'Complete sire selection checklist before insemination'
                          : 'Top 5 sire selection checks before insemination',
                      _showFullSireChecklist
                          ? 'انسیمینیشن سے پہلے سانڈ انتخاب کی مکمل چیک لسٹ'
                          : 'انسیمینیشن سے پہلے سانڈ انتخاب کے ٹاپ 5 نکات',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...displayedSireChecklist.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '- ${_t(item['en']!, item['ur']!)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showFullSireChecklist = !_showFullSireChecklist;
                        });
                      },
                      child: Text(
                        _t(
                          _showFullSireChecklist ? 'Show Top 5' : 'Show All',
                          _showFullSireChecklist
                              ? 'صرف ٹاپ 5 دکھائیں'
                              : 'سب دکھائیں',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Selected animal: $_selectedAnimal',
                      'منتخب جانور: ${_animalUrdu(_selectedAnimal)}',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _t(
                      'Selected purpose: ${_selectedBreedingPurpose == 'milk' ? 'Milk' : 'Meat'}',
                      'منتخب مقصد: ${_selectedBreedingPurpose == 'milk' ? 'دودھ' : 'گوشت'}',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _t(
                      'Note: Confirm sire availability from your nearest certified semen station or breeding center.',
                      'نوٹ: سانڈ کی دستیابی اپنے قریبی مصدقہ سیمین اسٹیشن یا بریڈنگ سینٹر سے ضرور تصدیق کریں۔',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MeatSectionScreen extends StatefulWidget {
  const MeatSectionScreen({super.key});

  @override
  State<MeatSectionScreen> createState() => _MeatSectionScreenState();
}

class _MeatSectionScreenState extends State<MeatSectionScreen> {
  final currentWeightController = TextEditingController();
  final girthController = TextEditingController();
  final bodyLengthController = TextEditingController();
  String _selectedAnimalType = 'Cattle';
  String _selectedAgeCategory = '1–2 years';
  String? _selectedPurpose; // 'buy_sell' or 'fatten'

  String? _weightResult;
  String? _weightError;

  @override
  void dispose() {
    currentWeightController.dispose();
    girthController.dispose();
    bodyLengthController.dispose();
    super.dispose();
  }

  (double, String) _weightFormulaByAnimalType() {
    switch (_selectedAnimalType) {
      case 'Buffalo':
        return (11000.0, 'BW = G^2 x L / 11000');
      case 'Goat':
        return (10850.0, 'BW = G^2 x L / 10850');
      case 'Sheep':
        return (10950.0, 'BW = G^2 x L / 10950');
      case 'Cattle':
      default:
        return (10840.0, 'BW = G^2 x L / 10840');
    }
  }

  double _estimateBodyWeightKg(double girthCm, double bodyLengthCm) {
    final (divisor, _) = _weightFormulaByAnimalType();
    return (girthCm * girthCm * bodyLengthCm) / divisor;
  }

  (double, double) _dressingRangeByAnimalType() {
    switch (_selectedAnimalType) {
      case 'Buffalo':
        return (0.48, 0.56);
      case 'Goat':
        return (0.44, 0.52);
      case 'Sheep':
        return (0.46, 0.54);
      case 'Cattle':
      default:
        return (0.50, 0.58);
    }
  }

  String _estimatedMeatText(double bodyWeightKg) {
    final (lowPct, highPct) = _dressingRangeByAnimalType();
    final low = bodyWeightKg * lowPct;
    final high = bodyWeightKg * highPct;
    return 'Estimated dressed meat yield ($_selectedAnimalType): ${low.toStringAsFixed(1)}-${high.toStringAsFixed(1)} kg (${(lowPct * 100).toStringAsFixed(0)}-${(highPct * 100).toStringAsFixed(0)}% dressing).\nاندازہ گوشت: ${low.toStringAsFixed(1)}-${high.toStringAsFixed(1)} کلو';
  }

  String _formulaHintText() {
    final (_, formulaText) = _weightFormulaByAnimalType();
    return 'Estimation formula / اندازہ فارمولہ ($_selectedAnimalType): $formulaText';
  }

  int get _ageCategoryMonths {
    switch (_selectedAgeCategory) {
      case 'Under 6 months':
        return 3;
      case '6–12 months':
        return 9;
      case '1–2 years':
        return 18;
      case '2–3 years':
        return 30;
      case '3–5 years':
        return 48;
      default:
        return 72; // Over 5 years
    }
  }

  (double, double) _priceRangePerKg() {
    final m = _ageCategoryMonths;
    switch (_selectedAnimalType) {
      case 'Buffalo':
        if (m <= 3) return (550, 700);
        if (m <= 9) return (700, 850);
        if (m <= 18) return (850, 1050);
        if (m <= 30) return (800, 1000);
        if (m <= 48) return (700, 900);
        return (600, 780);
      case 'Goat':
        if (m <= 3) return (900, 1200);
        if (m <= 9) return (1100, 1500);
        if (m <= 18) return (1200, 1600);
        if (m <= 30) return (1100, 1450);
        if (m <= 48) return (950, 1300);
        return (850, 1100);
      case 'Sheep':
        if (m <= 3) return (850, 1100);
        if (m <= 9) return (1000, 1350);
        if (m <= 18) return (1100, 1500);
        if (m <= 30) return (1000, 1400);
        if (m <= 48) return (900, 1250);
        return (800, 1050);
      case 'Cattle':
      default:
        if (m <= 3) return (500, 650);
        if (m <= 9) return (650, 800);
        if (m <= 18) return (800, 1000);
        if (m <= 30) return (750, 950);
        if (m <= 48) return (650, 800);
        return (550, 700);
    }
  }

  String _formatPrice(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _estimatedPriceText(double bodyWeightKg) {
    final (lowRate, highRate) = _priceRangePerKg();
    final lowTotal = _formatPrice((bodyWeightKg * lowRate).round());
    final highTotal = _formatPrice((bodyWeightKg * highRate).round());
    return 'Estimated market price ($_selectedAgeCategory $_selectedAnimalType): '
        'PKR $lowTotal – $highTotal\n'
        'اندازہ بازار قیمت: $lowTotal – $highTotal روپے\n'
        '(@ PKR ${lowRate.toStringAsFixed(0)}–${highRate.toStringAsFixed(0)}/kg — approximate Pakistan market rates / تقریبی پاکستان بازار قیمت)';
  }

  void _calculateWeight() {
    final currentWeightText = currentWeightController.text.trim();
    final girthText = girthController.text.trim();
    final lengthText = bodyLengthController.text.trim();

    setState(() {
      _weightError = null;
      _weightResult = null;
    });

    if (currentWeightText.isNotEmpty) {
      final currentWeight = double.tryParse(currentWeightText);
      if (currentWeight == null || currentWeight <= 0) {
        setState(() {
          _weightError =
              'Enter a valid current weight in kg.\nوزن صحیح درج کریں (کلو میں)۔';
        });
        return;
      }
      setState(() {
        _weightResult =
            'Current animal weight / جانور کا وزن: ${currentWeight.toStringAsFixed(1)} kg\n'
            '${_estimatedMeatText(currentWeight)}\n\n'
            '${_estimatedPriceText(currentWeight)}';
      });
      return;
    }

    final girthCm = double.tryParse(girthText);
    final bodyLengthCm = double.tryParse(lengthText);

    if (girthCm == null ||
        bodyLengthCm == null ||
        girthCm <= 0 ||
        bodyLengthCm <= 0) {
      setState(() {
        _weightError =
            'If current weight is not known, enter valid girth and body length in cm.\nاگر وزن معلوم نہیں، تو چھاتی گھیر اور لمبائی (سینٹی میٹر میں) درج کریں۔';
      });
      return;
    }

    final estimatedWeight = _estimateBodyWeightKg(girthCm, bodyLengthCm);
    final (_, formulaText) = _weightFormulaByAnimalType();
    setState(() {
      _weightResult =
          'Estimated body weight ($_selectedAnimalType) / اندازہ شدہ وزن: ${estimatedWeight.toStringAsFixed(1)} kg (using $formulaText)\n'
          '${_estimatedMeatText(estimatedWeight)}\n\n'
          '${_estimatedPriceText(estimatedWeight)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meat Section / گوشت سیکشن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Animal Body Weight / جانور کا وزن',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAnimalType,
                    decoration: const InputDecoration(
                      labelText: 'Animal type / جانور کی قسم',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Cattle',
                        child: Text('Cattle / گائے'),
                      ),
                      DropdownMenuItem(
                        value: 'Buffalo',
                        child: Text('Buffalo / بھینس'),
                      ),
                      DropdownMenuItem(
                        value: 'Goat',
                        child: Text('Goat / بکری'),
                      ),
                      DropdownMenuItem(
                        value: 'Sheep',
                        child: Text('Sheep / بھیڑ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedAnimalType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAgeCategory,
                    decoration: const InputDecoration(
                      labelText: 'Age of animal / جانور کی عمر',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Under 6 months',
                        child: Text('Under 6 months / 6 ماہ سے کم'),
                      ),
                      DropdownMenuItem(
                        value: '6–12 months',
                        child: Text('6–12 months / 6–12 ماہ'),
                      ),
                      DropdownMenuItem(
                        value: '1–2 years',
                        child: Text('1–2 years / 1–2 سال'),
                      ),
                      DropdownMenuItem(
                        value: '2–3 years',
                        child: Text('2–3 years / 2–3 سال'),
                      ),
                      DropdownMenuItem(
                        value: '3–5 years',
                        child: Text('3–5 years / 3–5 سال'),
                      ),
                      DropdownMenuItem(
                        value: 'Over 5 years',
                        child: Text('Over 5 years / 5 سال سے زیادہ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedAgeCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  // ── PURPOSE SELECTOR ─────────────────────────────
                  const Text(
                    'What do you want to do? / آپ کیا کرنا چاہتے ہیں؟',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedPurpose = 'buy_sell';
                            _weightResult = null;
                            _weightError = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedPurpose == 'buy_sell'
                                  ? Colors.blue.shade700
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade400,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.sell_outlined,
                                  size: 28,
                                  color: _selectedPurpose == 'buy_sell'
                                      ? Colors.white
                                      : Colors.blue.shade700,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Buy / Sell',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPurpose == 'buy_sell'
                                        ? Colors.white
                                        : Colors.blue.shade700,
                                  ),
                                ),
                                Text(
                                  'خریدنا / بیچنا',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _selectedPurpose == 'buy_sell'
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedPurpose = 'fatten';
                            _weightResult = null;
                            _weightError = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedPurpose == 'fatten'
                                  ? Colors.green.shade700
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade400,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.grass,
                                  size: 28,
                                  color: _selectedPurpose == 'fatten'
                                      ? Colors.white
                                      : Colors.green.shade700,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fatten',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPurpose == 'fatten'
                                        ? Colors.white
                                        : Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'موٹا کرنا',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _selectedPurpose == 'fatten'
                                        ? Colors.white70
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ── BUY / SELL FLOW ───────────────────────────────
                  if (_selectedPurpose == 'buy_sell') ...[
                    const SizedBox(height: 14),
                    _MeasurementGuideCard(animalType: _selectedAnimalType),
                    const SizedBox(height: 8),
                    Text(
                      _formulaHintText(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: currentWeightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText:
                            'Current weight (kg) / موجودہ وزن (کلو) - optional',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    TextField(
                      controller: girthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText:
                            'Heart girth (cm) / چھاتی گھیر - if weight unknown',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyLengthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText:
                            'Body length (cm) / جسم کی لمبائی - if weight unknown',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _calculateWeight,
                        icon: const Icon(Icons.calculate),
                        label: const Text(
                          'Get Price Estimate / قیمت کا اندازہ لگائیں',
                        ),
                      ),
                    ),
                    if (_weightError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _weightError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    if (_weightResult != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _weightResult!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (_selectedPurpose == 'fatten')
            _FatteningPlanCard(
              animalType: _selectedAnimalType,
              ageCategory: _selectedAgeCategory,
            ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialLanguage = 'English'});
  final String initialLanguage;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Fattening Plan Card
// ─────────────────────────────────────────────────────────────────────────────
class _FatteningPlanCard extends StatelessWidget {
  const _FatteningPlanCard({
    required this.animalType,
    required this.ageCategory,
  });
  final String animalType;
  final String ageCategory;

  bool get _isLarge => animalType == 'Cattle' || animalType == 'Buffalo';

  List<({String phase, String urduPhase, String feed, String urduFeed})>
  get _feedPlan {
    if (_isLarge) {
      return [
        (
          phase: 'Month 1–2 — Foundation',
          urduPhase: 'مہینہ 1–2 — ابتداء',
          feed:
              '• Hay / silage: ad lib\n• Concentrate mix: 1–2 kg/day\n• Mineral lick block: always available\n• Fresh clean water: always',
          urduFeed:
              '• گھاس / سائیلج: جتنا کھائے\n• کنسنٹریٹ: 1–2 کلو روزانہ\n• معدنی چٹان: ہمیشہ دستیاب\n• صاف پانی: ہمیشہ',
        ),
        (
          phase: 'Month 3–4 — Build-up',
          urduPhase: 'مہینہ 3–4 — اضافہ',
          feed:
              '• Green fodder: 15 kg/day\n• Dry hay: 5 kg/day\n• Concentrate: 3–4 kg/day\n• Urea–molasses lick: 500 g/day',
          urduFeed:
              '• ہری چارہ: 15 کلو روزانہ\n• خشک گھاس: 5 کلو روزانہ\n• کنسنٹریٹ: 3–4 کلو روزانہ\n• یوریا/گڑ چاٹ: 500 گرام روزانہ',
        ),
        (
          phase: 'Month 5–8 — Peak Fattening',
          urduPhase: 'مہینہ 5–8 — موٹاپے کا عروج',
          feed:
              '• Green fodder: 20 kg/day\n• Concentrate: 5–7 kg/day\n• Cottonseed meal: 1 kg/day\n• Molasses: 500 g/day\n• Vitamin–mineral premix: 50 g/day',
          urduFeed:
              '• ہری چارہ: 20 کلو روزانہ\n• کنسنٹریٹ: 5–7 کلو روزانہ\n• بنولہ کھل: 1 کلو روزانہ\n• گڑ: 500 گرام روزانہ\n• وٹامن–معدنی مکسچر: 50 گرام روزانہ',
        ),
        (
          phase: 'Month 9–12 — Finishing',
          urduPhase: 'مہینہ 9–12 — فنشنگ',
          feed:
              '• High-energy silage: 15 kg/day\n• Concentrate: 7–8 kg/day\n• Bypass fat supplement: 200 g/day\n• Limit exercise to reduce energy loss',
          urduFeed:
              '• اعلیٰ توانائی سائیلج: 15 کلو روزانہ\n• کنسنٹریٹ: 7–8 کلو روزانہ\n• بائی پاس فیٹ: 200 گرام روزانہ\n• چلنا پھرنا کم کریں',
        ),
      ];
    } else {
      return [
        (
          phase: 'Month 1–2 — Foundation',
          urduPhase: 'مہینہ 1–2 — ابتداء',
          feed:
              '• Hay: ad lib\n• Concentrate: 200–300 g/day\n• Mineral supplement: 10 g/day\n• Fresh water: always',
          urduFeed:
              '• گھاس: جتنا کھائے\n• کنسنٹریٹ: 200–300 گرام روزانہ\n• معدنی سپلیمنٹ: 10 گرام روزانہ\n• صاف پانی: ہمیشہ',
        ),
        (
          phase: 'Month 3–6 — Build-up',
          urduPhase: 'مہینہ 3–6 — اضافہ',
          feed:
              '• Green fodder: 2–3 kg/day\n• Concentrate: 400–500 g/day\n• Maize grain: 100 g/day\n• Mineral lick block',
          urduFeed:
              '• ہری چارہ: 2–3 کلو روزانہ\n• کنسنٹریٹ: 400–500 گرام روزانہ\n• مکئی دانہ: 100 گرام روزانہ\n• معدنی چٹان',
        ),
        (
          phase: 'Month 7–10 — Peak Fattening',
          urduPhase: 'مہینہ 7–10 — موٹاپے کا عروج',
          feed:
              '• Green fodder: 3–4 kg/day\n• Concentrate: 600–700 g/day\n• Soybean meal: 50 g/day\n• Molasses: 100 g/day',
          urduFeed:
              '• ہری چارہ: 3–4 کلو روزانہ\n• کنسنٹریٹ: 600–700 گرام روزانہ\n• سویابین کھل: 50 گرام روزانہ\n• گڑ: 100 گرام روزانہ',
        ),
        (
          phase: 'Month 11–12 — Finishing',
          urduPhase: 'مہینہ 11–12 — فنشنگ',
          feed:
              '• Concentrate: 700–800 g/day\n• Green fodder: 2 kg/day\n• Limit exercise for weight gain',
          urduFeed:
              '• کنسنٹریٹ: 700–800 گرام روزانہ\n• ہری چارہ: 2 کلو روزانہ\n• وزن بڑھانے کے لیے چلنا کم کریں',
        ),
      ];
    }
  }

  List<({String timing, String urduTiming, String vaccine, String urduVaccine})>
  get _vaccPlan {
    if (_isLarge) {
      return [
        (
          timing: 'Week 1–2',
          urduTiming: 'ہفتہ 1–2',
          vaccine:
              'Deworming — Albendazole 10 mg/kg oral OR Ivermectin 0.2 mg/kg injection',
          urduVaccine: 'کیڑے مار دوا — البینڈازول یا آئیورمیکٹن',
        ),
        (
          timing: 'Month 1',
          urduTiming: 'مہینہ 1',
          vaccine:
              'FMD vaccine (Foot & Mouth Disease)\nHS vaccine (Hemorrhagic Septicemia)\nVitamin ADE injection',
          urduVaccine:
              'منہ کھر کی ویکسین\nگلا گھونٹو ویکسین\nوٹامن ADE انجیکشن',
        ),
        (
          timing: 'Month 2',
          urduTiming: 'مہینہ 2',
          vaccine:
              'BQ vaccine (Black Quarter)\nLiver fluke treatment if needed',
          urduVaccine: 'کالی ٹانگ ویکسین\nجگر کے کیڑوں کا علاج',
        ),
        (
          timing: 'Month 3',
          urduTiming: 'مہینہ 3',
          vaccine:
              'Anthrax vaccine (if in risk area)\nB-complex vitamin injection',
          urduVaccine: 'جراثیمی بخار ویکسین (خطرناک علاقہ)\nوٹامن بی کمپلیکس',
        ),
        (
          timing: 'Month 6',
          urduTiming: 'مہینہ 6',
          vaccine: 'FMD booster dose\nRepeat deworming',
          urduVaccine: 'منہ کھر بوسٹر ڈوز\nدوبارہ کیڑے مار دوا',
        ),
        (
          timing: 'Month 12',
          urduTiming: 'مہینہ 12',
          vaccine:
              'Annual boosters: FMD, HS, BQ\nDeworming\nCheck weight — ready to sell',
          urduVaccine:
              'سالانہ بوسٹر: منہ کھر، گلا گھونٹو، کالی ٹانگ\nکیڑے مار دوا\nوزن چیک کریں — فروخت کے لیے تیار',
        ),
      ];
    } else {
      return [
        (
          timing: 'Week 1–2',
          urduTiming: 'ہفتہ 1–2',
          vaccine: 'Deworming — Albendazole 7.5 mg/kg oral',
          urduVaccine: 'کیڑے مار دوا — البینڈازول',
        ),
        (
          timing: 'Month 1',
          urduTiming: 'مہینہ 1',
          vaccine:
              'PPR vaccine (Peste des Petits Ruminants)\nFMD vaccine\nVitamin ADE injection',
          urduVaccine:
              'چھوٹے جانوروں کی طاعون ویکسین\nمنہ کھر ویکسین\nوٹامن ADE انجیکشن',
        ),
        (
          timing: 'Month 2',
          urduTiming: 'مہینہ 2',
          vaccine: 'Enterotoxemia (ET) vaccine\nB-complex injection',
          urduVaccine: 'آنتوں کا زہر ویکسین\nوٹامن بی کمپلیکس',
        ),
        (
          timing: 'Month 3',
          urduTiming: 'مہینہ 3',
          vaccine:
              '${animalType == 'Sheep' ? 'Sheep' : 'Goat'} Pox vaccine\nEctoparasite treatment (ticks/lice)',
          urduVaccine:
              '${animalType == 'Sheep' ? 'بھیڑ' : 'بکری'} چیچک ویکسین\nجوؤں/چیچڑوں کا علاج',
        ),
        (
          timing: 'Month 6',
          urduTiming: 'مہینہ 6',
          vaccine: 'PPR booster\nRepeat deworming',
          urduVaccine: 'پی پی آر بوسٹر\nدوبارہ کیڑے مار دوا',
        ),
        (
          timing: 'Month 12',
          urduTiming: 'مہینہ 12',
          vaccine:
              'Annual boosters: PPR, FMD, ET\nDeworming\nCheck weight — ready to sell',
          urduVaccine:
              'سالانہ بوسٹر: پی پی آر, منہ کھر, ای ٹی\nکیڑے مار دوا\nوزن چیک کریں — فروخت کے لیے تیار',
        ),
      ];
    }
  }

  Widget _sectionHeader(String text, String urdu, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            urdu,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.grass, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1-Year Fattening Plan — $animalType',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ایک سال کا موٹاپے کا پلان — $animalType ($ageCategory)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── FEED PLAN ──────────────────────────────────────────
            _sectionHeader('FEED PLAN', 'خوراک کا پلان', Colors.green.shade700),
            const SizedBox(height: 8),
            ..._feedPlan.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${p.phase}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '  ${p.urduPhase}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.feed, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            p.urduFeed,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── VACCINATION SCHEDULE ───────────────────────────────
            _sectionHeader(
              'VACCINATION & HEALTH SCHEDULE',
              'ویکسینیشن اور صحت کا شیڈول',
              Colors.blue.shade700,
            ),
            const SizedBox(height: 8),
            ..._vaccPlan.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text(
                            v.timing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            v.urduTiming,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.vaccine,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              v.urduVaccine,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                '⚠ Always consult your local veterinary doctor before giving vaccines or medicines.\n'
                '⚠ ویکسین یا دوائی دینے سے پہلے ہمیشہ اپنے مقامی جانوروں کے ڈاکٹر سے مشورہ کریں۔',
                style: TextStyle(fontSize: 12, color: Colors.brown),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementGuideCard extends StatelessWidget {
  const _MeasurementGuideCard({required this.animalType});

  final String animalType;

  String get _assetPath {
    switch (animalType) {
      case 'Buffalo':
        return 'assets/images/measurement_buffalo.svg';
      case 'Goat':
        return 'assets/images/measurement_goat.svg';
      case 'Sheep':
        return 'assets/images/measurement_sheep.svg';
      case 'Cattle':
      default:
        return 'assets/images/measurement_cattle.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to measure / ناپنے کا طریقہ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: const Color(0xFFF7FBF8),
              padding: const EdgeInsets.all(6),
              child: SvgPicture.asset(
                _assetPath,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Heart girth / چھاتی گھیر: Tape around chest just behind front legs.',
          ),
          const Text(
            'سامنے والی ٹانگوں کے پیچھے چھاتی کے گرد ٹیپ لپیٹیں۔',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Body length / جسم کی لمبائی: From shoulder point to pin bone (rump).',
          ),
          const Text(
            'کندھے کے نقطے سے کولہے کی ہڈی تک ناپیں۔',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
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
  String _selectedSeason = 'Kharif';
  String _selectedCrop = 'Maize';
  String _selectedCropCategory = 'Field Crops';
  String _selectedProvince = 'Punjab';
  bool _provinceAutoDetected = false;
  String _selectedLanguage = 'English';
  String _selectedWheatGrowthStage = 'crown_root_initiation';
  List<LatLng> _fieldPolygon = [];

  final latController = TextEditingController(
    text: defaultPakistanLat.toString(),
  );
  final lonController = TextEditingController(
    text: defaultPakistanLon.toString(),
  );
  final previousIrrigationsController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _selectedSeason = _seasonFromMonth(DateTime.now().month);
    _bootstrapLocationAwareWeather();
  }

  Future<void> _bootstrapLocationAwareWeather() async {
    try {
      final position = await _getCurrentPhonePosition();
      final detectedProvince = _inferProvinceFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      final autoSeason = _seasonFromMonth(DateTime.now().month);
      final autoSeasonCrops = _cropsForSeason(autoSeason);

      setState(() {
        latController.text = position.latitude.toStringAsFixed(5);
        lonController.text = position.longitude.toStringAsFixed(5);
        _selectedSeason = autoSeason;
        if (_selectedCropCategory == 'Field Crops' &&
            !autoSeasonCrops.contains(_selectedCrop)) {
          _selectedCrop = autoSeasonCrops.first;
        }
        if (detectedProvince != null) {
          _selectedProvince = detectedProvince;
          _provinceAutoDetected = true;
        }
      });
    } catch (_) {
      // Keep default coordinates if location is unavailable at startup.
    }

    if (!mounted) {
      return;
    }
    await _fetchWeather();
  }

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
      return const LatLng(defaultPakistanLat, defaultPakistanLon);
    }
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lon =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
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
      case 'Sugarcane':
        return 1.15;
      case 'Cotton':
        return 0.95;
      case 'Gram':
        return 0.70;
      case 'Mustard':
        return 0.75;
      case 'Bajra':
        return 0.80;
      case 'Barley':
        return 0.78;
      // Vegetables
      case 'Onion':
        return 0.85;
      case 'Tomato':
        return 1.05;
      case 'Chilli':
        return 0.90;
      case 'Brinjal':
        return 0.95;
      // Fruits
      case 'Mango':
        return 0.80;
      case 'Citrus':
        return 0.75;
      case 'Guava':
        return 0.70;
      case 'Banana':
        return 1.20;
      default:
        return 0.95;
    }
  }

  int _previousIrrigationsCount() {
    final parsed = int.tryParse(previousIrrigationsController.text.trim()) ?? 0;
    return parsed.clamp(0, 12);
  }

  static const List<Map<String, dynamic>> _wheatStageSequence = [
    {
      'key': 'pre_sowing',
      'labelKey': 'wheatStagePreSowing',
      'irrigationNumber': 0,
    },
    {
      'key': 'crown_root_initiation',
      'labelKey': 'wheatStageCri',
      'irrigationNumber': 1,
    },
    {
      'key': 'tillering',
      'labelKey': 'wheatStageTillering',
      'irrigationNumber': 2,
    },
    {
      'key': 'jointing',
      'labelKey': 'wheatStageJointing',
      'irrigationNumber': 3,
    },
    {
      'key': 'grain_filling',
      'labelKey': 'wheatStageGrainFilling',
      'irrigationNumber': 4,
    },
  ];

  Map<String, dynamic> _wheatStageDetails([String? stageKey]) {
    final key = stageKey ?? _selectedWheatGrowthStage;
    return _wheatStageSequence.firstWhere(
      (stage) => stage['key'] == key,
      orElse: () => _wheatStageSequence[1],
    );
  }

  String _wheatStageLabel([String? stageKey]) {
    final stage = _wheatStageDetails(stageKey);
    return _t(stage['labelKey'] as String);
  }

  String _buildWheatRecommendation(
    double precipitation7day,
    double referenceEt07day,
    double estimatedCropWaterNeed,
    double netWaterBalance,
  ) {
    final stage = _wheatStageDetails();
    final previousIrrigations = _previousIrrigationsCount();
    final targetIrrigationNumber = stage['irrigationNumber'] as int;
    final stageLabel = _t(stage['labelKey'] as String);
    final stageIndex = _wheatStageSequence.indexWhere(
      (item) => item['key'] == stage['key'],
    );
    final nextStageLabel =
        stageIndex >= 0 && stageIndex + 1 < _wheatStageSequence.length
        ? _t(_wheatStageSequence[stageIndex + 1]['labelKey'] as String)
        : null;
    final balanceText =
        '${_t('wheatDemandContext')} ${precipitation7day.toStringAsFixed(1)} mm ${_t('against')} ${estimatedCropWaterNeed.toStringAsFixed(1)} mm ${_t('withEt0Short')} ${referenceEt07day.toStringAsFixed(1)} mm, ${_t('leavingBalance')} ${netWaterBalance.toStringAsFixed(1)} mm.';

    if (targetIrrigationNumber == 0) {
      if (netWaterBalance <= -10) {
        return '${_t('wheatStagePrefix')} $stageLabel. ${_t('previousIrrigationsNote')} $previousIrrigations. ${_t('wheatPresowingNow')} $balanceText';
      }
      return '${_t('wheatStagePrefix')} $stageLabel. ${_t('previousIrrigationsNote')} $previousIrrigations. ${_t('wheatPresowingHold')} $balanceText';
    }

    if (previousIrrigations < targetIrrigationNumber) {
      String message;
      if (netWaterBalance <= -12) {
        message = '${_t('wheatIrrigationDueNow')} #$targetIrrigationNumber.';
      } else if (netWaterBalance <= 5) {
        message = '${_t('wheatIrrigationSoon')} #$targetIrrigationNumber.';
      } else {
        message = '${_t('wheatIrrigationDelay')} #$targetIrrigationNumber.';
      }
      final nextStageMessage = nextStageLabel == null
          ? ''
          : ' ${_t('wheatNextStage')} $nextStageLabel.';
      return '${_t('wheatStagePrefix')} $stageLabel. ${_t('previousIrrigationsNote')} $previousIrrigations. $message $balanceText$nextStageMessage';
    }

    if (previousIrrigations == targetIrrigationNumber) {
      final nextStageMessage = nextStageLabel == null
          ? ''
          : ' ${_t('wheatNextStagePlanned')} $nextStageLabel.';
      return '${_t('wheatStagePrefix')} $stageLabel. ${_t('wheatStageAlreadyCovered')} $previousIrrigations. $balanceText$nextStageMessage';
    }

    return '${_t('wheatStagePrefix')} $stageLabel. ${_t('wheatTooManyIrrigations')} $previousIrrigations ${_t('wheatForStageLimit')} $targetIrrigationNumber. $balanceText';
  }

  String _buildIrrigationAdvice(
    double precipitation7day,
    double referenceEt07day,
    double estimatedCropWaterNeed,
    double netWaterBalance,
  ) {
    if (_selectedCrop == 'Wheat') {
      return _buildWheatRecommendation(
        precipitation7day,
        referenceEt07day,
        estimatedCropWaterNeed,
        netWaterBalance,
      );
    }

    if (netWaterBalance > 12) {
      return '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('reduceIrrigationEtAdvice')}';
    }
    if (netWaterBalance < -12) {
      return '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('increaseIrrigationEtAdvice')}';
    }
    return '${_t('waterBalance')}: ${netWaterBalance.toStringAsFixed(1)} mm. ${_t('balancedIrrigationEtAdvice')}';
  }

  double _estimateDailyEt0Hargreaves(
    double latitude,
    DateTime day,
    double temperatureMax,
    double temperatureMin,
  ) {
    final dayOfYear = day.difference(DateTime(day.year, 1, 1)).inDays + 1;
    final latitudeRadians = latitude * math.pi / 180;
    final inverseRelativeDistance =
        1 + 0.033 * math.cos((2 * math.pi / 365) * dayOfYear);
    final solarDeclination =
        0.409 * math.sin((2 * math.pi / 365) * dayOfYear - 1.39);
    final acosInput = (-math.tan(latitudeRadians) * math.tan(solarDeclination))
        .clamp(-1.0, 1.0);
    final sunsetHourAngle = math.acos(acosInput);
    final extraterrestrialRadiation =
        (24 * 60 / math.pi) *
        0.0820 *
        inverseRelativeDistance *
        (sunsetHourAngle *
                math.sin(latitudeRadians) *
                math.sin(solarDeclination) +
            math.cos(latitudeRadians) *
                math.cos(solarDeclination) *
                math.sin(sunsetHourAngle));
    final temperatureMean = (temperatureMax + temperatureMin) / 2;
    final temperatureRange = math.max(temperatureMax - temperatureMin, 0.0);
    return math.max(
      0.0,
      0.0023 *
          extraterrestrialRadiation *
          (temperatureMean + 17.8) *
          math.sqrt(temperatureRange),
    );
  }

  Future<Position> _getCurrentPhonePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(_t('locationServicesDisabled'));
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(_t('locationPermissionDenied'));
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _useCurrentPhoneLocation() async {
    try {
      final position = await _getCurrentPhonePosition();
      final location = LatLng(position.latitude, position.longitude);
      final detectedProvince = _inferProvinceFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        latController.text = location.latitude.toStringAsFixed(5);
        lonController.text = location.longitude.toStringAsFixed(5);
        if (detectedProvince != null) {
          _selectedProvince = detectedProvince;
          _provinceAutoDetected = true;
        }
        _fieldPolygon = [];
      });
      await _fetchWeather();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openMapPicker() async {
    final currentLat =
        double.tryParse(latController.text) ?? defaultPakistanLat;
    final currentLon =
        double.tryParse(lonController.text) ?? defaultPakistanLon;
    LatLng pickedPoint = LatLng(currentLat, currentLon);
    LatLng? phoneLocation;
    double? phoneAccuracyMeters;
    final mapController = MapController();

    try {
      final position = await _getCurrentPhonePosition();
      pickedPoint = LatLng(position.latitude, position.longitude);
      phoneLocation = pickedPoint;
      phoneAccuracyMeters = position.accuracy;
    } catch (_) {
      // Fall back to the currently selected coordinates when device location is unavailable.
    }

    var drawBoundaryMode = false;
    var selectedLayer = 'osm';
    var eeTileUrl = '';
    var eeLoading = false;
    var locatingPhone = false;
    String? locationError;
    String? eeError;
    final boundaryPoints = List<LatLng>.from(_fieldPolygon);

    if (!mounted) {
      return;
    }

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

            Future<void> usePhoneLocationInMap() async {
              setDialogState(() {
                locatingPhone = true;
                locationError = null;
              });

              try {
                final position = await _getCurrentPhonePosition();
                final location = LatLng(position.latitude, position.longitude);
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  pickedPoint = location;
                  phoneLocation = location;
                  phoneAccuracyMeters = position.accuracy;
                });
                mapController.move(location, 16);
                if (selectedLayer != 'osm') {
                  await loadEeTiles(selectedLayer);
                }
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  locationError = error.toString();
                });
              } finally {
                if (context.mounted) {
                  setDialogState(() {
                    locatingPhone = false;
                  });
                }
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
                            child: Text(
                              drawBoundaryMode
                                  ? _t('pointMode')
                                  : _t('boundaryMode'),
                            ),
                          ),
                          TextButton(
                            onPressed: locatingPhone
                                ? null
                                : usePhoneLocationInMap,
                            child: Text(_t('usePhoneLocation')),
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
                          Text(
                            '${_t('layer')}:',
                            style: const TextStyle(fontSize: 12),
                          ),
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
                        child: Text(
                          _t('loadingEeTiles'),
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    if (locatingPhone)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _t('locatingPhone'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (locationError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          locationError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (eeError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          eeError!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (selectedLayer == 'ndvi')
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildLegendColor(
                                  const Color(0xFF8B0000),
                                  _t('low'),
                                ),
                                const SizedBox(width: 6),
                                _buildLegendColor(
                                  const Color(0xFFF4D03F),
                                  _t('sparse'),
                                ),
                                const SizedBox(width: 6),
                                _buildLegendColor(
                                  const Color(0xFF7FBF3F),
                                  _t('moderate'),
                                ),
                                const SizedBox(width: 6),
                                _buildLegendColor(
                                  const Color(0xFF006400),
                                  _t('high'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: pickedPoint,
                              initialZoom: 15,
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
                              if (selectedLayer != 'osm' &&
                                  eeTileUrl.isNotEmpty)
                                TileLayer(
                                  urlTemplate: eeTileUrl,
                                  userAgentPackageName: 'com.example.agri_app',
                                  maxZoom: 18,
                                ),
                              if (phoneLocation != null &&
                                  phoneAccuracyMeters != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: phoneLocation!,
                                      radius: math.max(phoneAccuracyMeters!, 8),
                                      useRadiusInMeter: true,
                                      color: const Color(
                                        0xFF1E88E5,
                                      ).withValues(alpha: 0.16),
                                      borderColor: const Color(
                                        0xFF1E88E5,
                                      ).withValues(alpha: 0.55),
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (phoneLocation != null)
                                    Marker(
                                      point: phoneLocation!,
                                      width: 24,
                                      height: 24,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E88E5),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
                                        if (boundaryPoints.length >= 3)
                                          boundaryPoints.first,
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
                                      color: Colors.deepOrange.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderColor: Colors.deepOrange,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: FloatingActionButton(
                                heroTag: 'recenter_map_picker',
                                mini: true,
                                onPressed: locatingPhone
                                    ? null
                                    : usePhoneLocationInMap,
                                tooltip: _t('recenterOnMyLocation'),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E88E5),
                                child: const Icon(Icons.my_location, size: 18),
                              ),
                            ),
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
                              if (drawBoundaryMode &&
                                  boundaryPoints.length >= 3) {
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
                              drawBoundaryMode
                                  ? _t('useBoundary')
                                  : _t('useThisPoint'),
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
      final detectedProvince = _inferProvinceFromCoordinates(
        point.latitude,
        point.longitude,
      );
      setState(() {
        latController.text = point.latitude.toStringAsFixed(5);
        lonController.text = point.longitude.toStringAsFixed(5);
        if (detectedProvince != null) {
          _selectedProvince = detectedProvince;
          _provinceAutoDetected = true;
        }
        _fieldPolygon = polygon;
      });
      _fetchWeather();
    }
  }

  final Map<String, Map<String, double>> _cropThresholds = {
    // Field Crops
    'Maize': {'low': 10, 'high': 30},
    'Wheat': {'low': 8, 'high': 25},
    'Rice': {'low': 20, 'high': 40},
    'Sugarcane': {'low': 22, 'high': 45},
    'Cotton': {'low': 10, 'high': 24},
    'Gram': {'low': 6, 'high': 18},
    'Mustard': {'low': 7, 'high': 20},
    'Bajra': {'low': 8, 'high': 22},
    'Barley': {'low': 7, 'high': 20},
    // Vegetables
    'Potato': {'low': 12, 'high': 28},
    'Onion': {'low': 10, 'high': 25},
    'Tomato': {'low': 12, 'high': 28},
    'Chilli': {'low': 10, 'high': 25},
    'Brinjal': {'low': 12, 'high': 30},
    // Fruits
    'Mango': {'low': 15, 'high': 35},
    'Citrus': {'low': 12, 'high': 30},
    'Guava': {'low': 10, 'high': 28},
    'Banana': {'low': 20, 'high': 40},
  };

  static const List<String> _seasons = ['Kharif', 'Rabi'];

  static const List<String> _provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Gilgit-Baltistan',
    'Azad Jammu and Kashmir',
  ];

  static const List<String> _cropCategories = [
    'Field Crops',
    'Vegetables',
    'Fruits',
  ];

  static const Map<String, List<String>> _categoryCrops = {
    'Field Crops': [
      'Wheat',
      'Maize',
      'Rice',
      'Sugarcane',
      'Cotton',
      'Gram',
      'Mustard',
      'Bajra',
      'Barley',
    ],
    'Vegetables': ['Potato', 'Onion', 'Tomato', 'Chilli', 'Brinjal'],
    'Fruits': ['Mango', 'Citrus', 'Guava', 'Banana'],
  };

  static const Map<String, List<String>> _seasonCrops = {
    'Kharif': ['Rice', 'Maize', 'Cotton', 'Sugarcane', 'Bajra'],
    'Rabi': ['Wheat', 'Gram', 'Mustard', 'Barley'],
  };

  String _seasonForCrop(String cropKey) {
    if (_seasonCrops['Rabi']!.contains(cropKey)) {
      return 'Rabi';
    }
    return 'Kharif';
  }

  String _seasonLabel(String season) {
    return season == 'Rabi' ? _t('rabiSeason') : _t('kharifSeason');
  }

  String _seasonFromMonth(int month) {
    // Pakistan crop calendar: Rabi is mainly Oct-Mar, Kharif is Apr-Sep.
    if (month >= 10 || month <= 3) {
      return 'Rabi';
    }
    return 'Kharif';
  }

  List<String> _cropsForSeason(String season) {
    final ordered = _seasonCrops[season] ?? const <String>[];
    final available = ordered.where(_cropThresholds.containsKey).toList();
    if (available.isNotEmpty) {
      return available;
    }
    return _cropThresholds.keys.toList();
  }

  List<String> _cropsForCategory() {
    if (_selectedCropCategory == 'Field Crops') {
      return _cropsForSeason(_selectedSeason);
    }
    return _categoryCrops[_selectedCropCategory] ?? const <String>[];
  }

  void _onCategoryChanged(String category) {
    final crops = category == 'Field Crops'
        ? _cropsForSeason(_selectedSeason)
        : (_categoryCrops[category] ?? const <String>[]);
    setState(() {
      _selectedCropCategory = category;
      if (crops.isNotEmpty && !crops.contains(_selectedCrop)) {
        _selectedCrop = crops.first;
      }
    });
  }

  void _onSeasonChanged(String season, {bool refreshWeather = false}) {
    final seasonCrops = _cropsForSeason(season);
    setState(() {
      _selectedSeason = season;
      if (_selectedCropCategory == 'Field Crops' &&
          !seasonCrops.contains(_selectedCrop)) {
        _selectedCrop = seasonCrops.first;
      }
    });
    if (refreshWeather && _forecastPrecip != null) {
      _fetchWeather();
    }
  }

  String _cropLabel(String cropKey) {
    return cropLabelsByLanguage[_selectedLanguage]?[cropKey] ?? cropKey;
  }

  String _provinceLabel(String provinceKey) {
    return provinceLabelsByLanguage[_selectedLanguage]?[provinceKey] ??
        provinceKey;
  }

  String? _inferProvinceFromCoordinates(double latitude, double longitude) {
    // Simple geo-fencing for Pakistan regions with centroid fallback.
    if (latitude < 23.0 ||
        latitude > 37.5 ||
        longitude < 60.5 ||
        longitude > 77.5) {
      return null;
    }

    if (latitude >= 33.0 &&
        latitude <= 36.2 &&
        longitude >= 73.0 &&
        longitude <= 75.6) {
      return 'Azad Jammu and Kashmir';
    }
    if (latitude >= 34.3 &&
        latitude <= 37.2 &&
        longitude >= 72.2 &&
        longitude <= 77.5) {
      return 'Gilgit-Baltistan';
    }
    if (latitude >= 23.4 &&
        latitude <= 28.9 &&
        longitude >= 66.2 &&
        longitude <= 71.4) {
      return 'Sindh';
    }
    if (latitude >= 24.0 &&
        latitude <= 32.6 &&
        longitude >= 60.5 &&
        longitude <= 70.6) {
      return 'Balochistan';
    }
    if (latitude >= 30.2 &&
        latitude <= 36.9 &&
        longitude >= 69.3 &&
        longitude <= 74.9) {
      return 'Khyber Pakhtunkhwa';
    }
    if (latitude >= 27.4 &&
        latitude <= 34.4 &&
        longitude >= 69.2 &&
        longitude <= 75.8) {
      return 'Punjab';
    }

    const provinceCentroids = <String, (double, double)>{
      'Punjab': (31.0, 72.3),
      'Sindh': (26.1, 68.4),
      'Khyber Pakhtunkhwa': (34.4, 71.8),
      'Balochistan': (28.5, 66.6),
      'Gilgit-Baltistan': (35.8, 74.6),
      'Azad Jammu and Kashmir': (34.3, 73.8),
    };

    String bestProvince = 'Punjab';
    var bestDistance = double.infinity;
    for (final entry in provinceCentroids.entries) {
      final centerLat = entry.value.$1;
      final centerLon = entry.value.$2;
      final distance =
          math.pow(latitude - centerLat, 2) +
          math.pow(longitude - centerLon, 2);
      if (distance < bestDistance) {
        bestDistance = distance.toDouble();
        bestProvince = entry.key;
      }
    }
    return bestProvince;
  }

  String _provinceAwareSectionContent(
    String cropKey,
    String sectionKey,
    String baseContent,
  ) {
    final provinceName = _provinceLabel(_selectedProvince);
    if (sectionKey == 'cultivation') {
      final season = _seasonForCrop(cropKey);
      final windowText =
          provinceSeasonWindowsByLanguage[_selectedLanguage]?[_selectedProvince]?[season] ??
          provinceSeasonWindowsByLanguage['English']?[_selectedProvince]?[season] ??
          '';
      if (windowText.isNotEmpty) {
        return '$baseContent\n\n${_t('regionalSowingWindowLabel')} ($provinceName): $windowText';
      }
    }

    if (sectionKey == 'pests' || sectionKey == 'diseases') {
      final advisoryText =
          provinceGeneralAdvisoryByLanguage[_selectedLanguage]?[_selectedProvince] ??
          provinceGeneralAdvisoryByLanguage['English']?[_selectedProvince] ??
          '';
      if (advisoryText.isNotEmpty) {
        return '$baseContent\n\n${_t('regionalAdvisoryLabel')} ($provinceName): $advisoryText';
      }
    }

    return baseContent;
  }

  List<Map<String, String>> _cropInstructionSections(String cropKey) {
    final sections =
        cropSectionsByLanguage[_selectedLanguage]?[cropKey] ??
        cropSectionsByLanguage['English']?[cropKey] ??
        const <String, String>{};

    String sectionValue(String key) {
      final value = sections[key];
      if (value == null || value.trim().isEmpty) {
        return _t('sectionPendingDetails');
      }
      return value;
    }

    final orderedSectionKeys = <String>[
      'cultivation',
      'fertilizer',
      'diseases',
      'pests',
      'weeds',
    ];

    return orderedSectionKeys.map((sectionKey) {
      final title = switch (sectionKey) {
        'cultivation' => _t('cultivationSection'),
        'fertilizer' => _t('fertilizerManagementSection'),
        'diseases' => _t('prevalentCropDiseasesSection'),
        'weeds' => _t('specificWeedsSection'),
        _ => _t('specificInsectPestsSection'),
      };
      final format = _sectionMiniFormat(sectionKey);
      return {
        'sectionKey': sectionKey,
        'title': title,
        'content': _provinceAwareSectionContent(
          cropKey,
          sectionKey,
          sectionValue(sectionKey),
        ),
        'timing': format['timing']!,
        'doseRate': format['doseRate']!,
        'monitoring': format['monitoring']!,
        'threshold': format['threshold']!,
      };
    }).toList();
  }

  Map<String, String> _sectionMiniFormat(String sectionKey) {
    switch (sectionKey) {
      case 'cultivation':
        return {
          'timing': _t('miniCultivationTiming'),
          'doseRate': _t('miniCultivationDoseRate'),
          'monitoring': _t('miniCultivationMonitoring'),
          'threshold': _t('miniCultivationThreshold'),
        };
      case 'fertilizer':
        return {
          'timing': _t('miniFertilizerTiming'),
          'doseRate': _t('miniFertilizerDoseRate'),
          'monitoring': _t('miniFertilizerMonitoring'),
          'threshold': _t('miniFertilizerThreshold'),
        };
      case 'diseases':
        return {
          'timing': _t('miniDiseaseTiming'),
          'doseRate': _t('miniDiseaseDoseRate'),
          'monitoring': _t('miniDiseaseMonitoring'),
          'threshold': _t('miniDiseaseThreshold'),
        };
      case 'weeds':
        return {
          'timing': _t('miniWeedTiming'),
          'doseRate': _t('miniWeedDoseRate'),
          'monitoring': _t('miniWeedMonitoring'),
          'threshold': _t('miniWeedThreshold'),
        };
      default:
        return {
          'timing': _t('miniPestTiming'),
          'doseRate': _t('miniPestDoseRate'),
          'monitoring': _t('miniPestMonitoring'),
          'threshold': _t('miniPestThreshold'),
        };
    }
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
  void dispose() {
    latController.dispose();
    lonController.dispose();
    previousIrrigationsController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    final latitude = double.tryParse(latController.text);
    final longitude = double.tryParse(lonController.text);
    final detectedProvince = latitude != null && longitude != null
        ? _inferProvinceFromCoordinates(latitude, longitude)
        : null;
    final autoSeason = _seasonFromMonth(DateTime.now().month);
    final autoSeasonCrops = _cropsForSeason(autoSeason);

    setState(() {
      _loadingWeather = true;
      _weatherError = null;
      _irrigationAdvice = null;
      _selectedSeason = autoSeason;
      if (_selectedCropCategory == 'Field Crops' &&
          !autoSeasonCrops.contains(_selectedCrop)) {
        _selectedCrop = autoSeasonCrops.first;
      }
      if (detectedProvince != null) {
        _selectedProvince = detectedProvince;
        _provinceAutoDetected = true;
      } else {
        _provinceAutoDetected = false;
      }
    });

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
        throw Exception(
          '${_t('unableToFetchWeather')} (${response.statusCode})',
        );
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
      final tempMax = (daily['temperature_2m_max'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final tempMin = (daily['temperature_2m_min'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final rawEt0 =
          (daily['et0_fao_evapotranspiration'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          <double>[];
      final et0 = List<double>.generate(dates.length, (index) {
        final apiEt0 = index < rawEt0.length ? rawEt0[index] : 0.0;
        if (apiEt0 > 0) {
          return apiEt0;
        }
        if (index >= tempMax.length || index >= tempMin.length) {
          return 0.0;
        }
        return _estimateDailyEt0Hargreaves(
          latitude,
          DateTime.parse(dates[index]),
          tempMax[index],
          tempMin[index],
        );
      });

      final total7 = precip.take(7).fold<double>(0, (a, b) => a + b);
      final et0Total7 = et0.take(7).fold<double>(0, (a, b) => a + b);
      final estimatedCropWaterNeed =
          et0Total7 * _cropCoefficient(_selectedCrop);
      final netWaterBalance = total7 - estimatedCropWaterNeed;
      final advice = _buildIrrigationAdvice(
        total7,
        et0Total7,
        estimatedCropWaterNeed,
        netWaterBalance,
      );

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
          'growth_stage': _selectedCrop == 'Wheat'
              ? _selectedWheatGrowthStage
              : null,
          'previous_irrigations_count': _selectedCrop == 'Wheat'
              ? _previousIrrigationsCount()
              : null,
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
            Text('${_t('selectedCrop')}: ${_cropLabel(_selectedCrop)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: _provinceAutoDetected
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _provinceAutoDetected
                        ? '${_t('autoDetectedProvince')}: ${_provinceLabel(_selectedProvince)}'
                        : '${_t('provinceLabel')}: ${_provinceLabel(_selectedProvince)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _provinceAutoDetected
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: _selectedCropCategory,
              isDense: true,
              items: _cropCategories
                  .map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat,
                      child: Text('${_t('cropCategoryLabel')}: $cat'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _onCategoryChanged(value);
              },
            ),
            if (_selectedCropCategory == 'Field Crops') ...[
              const SizedBox(height: 4),
              Text(
                '${_t('autoDetectedSeason')}: ${_seasonLabel(_selectedSeason)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: _selectedCrop,
              isDense: true,
              items: _cropsForCategory()
                  .map(
                    (crop) => DropdownMenuItem(
                      value: crop,
                      child: Text(_cropLabel(crop)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCrop = value;
                  });
                  if (_forecastPrecip != null) {
                    _fetchWeather();
                  }
                }
              },
            ),
            if (_selectedCrop == 'Wheat') ...[
              const SizedBox(height: 8),
              Text(
                _t('wheatGrowthStage'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: _selectedWheatGrowthStage,
                isDense: true,
                items: _wheatStageSequence
                    .map(
                      (stage) => DropdownMenuItem<String>(
                        value: stage['key'] as String,
                        child: Text(_t(stage['labelKey'] as String)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedWheatGrowthStage = value;
                  });
                  if (_forecastPrecip != null &&
                      _referenceEt0Total != null &&
                      _estimatedCropWaterNeedTotal != null &&
                      _netWaterBalanceTotal != null) {
                    setState(() {
                      _irrigationAdvice = _buildIrrigationAdvice(
                        _forecastPrecip!
                            .take(7)
                            .fold<double>(0, (a, b) => a + b),
                        _referenceEt0Total!,
                        _estimatedCropWaterNeedTotal!,
                        _netWaterBalanceTotal!,
                      );
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _t('previousIrrigationsCount'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: previousIrrigationsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: _t('previousIrrigationsHint'),
                ),
                onChanged: (_) {
                  if (_forecastPrecip != null &&
                      _referenceEt0Total != null &&
                      _estimatedCropWaterNeedTotal != null &&
                      _netWaterBalanceTotal != null) {
                    setState(() {
                      _irrigationAdvice = _buildIrrigationAdvice(
                        _forecastPrecip!
                            .take(7)
                            .fold<double>(0, (a, b) => a + b),
                        _referenceEt0Total!,
                        _estimatedCropWaterNeedTotal!,
                        _netWaterBalanceTotal!,
                      );
                    });
                  }
                },
              ),
              const SizedBox(height: 4),
              Text(
                '${_t('wheatStageSchedule')}: ${_wheatStageLabel(_selectedWheatGrowthStage)} -> #${(_wheatStageDetails()['irrigationNumber'] as int)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            if (_cropThresholds[_selectedCrop] != null) ...[
              Text(
                '${_t('irrigationThresholdsFor')} ${_cropLabel(_selectedCrop)}: ${_t('low')} ${_cropThresholds[_selectedCrop]!['low']} mm, ${_t('high')} ${_cropThresholds[_selectedCrop]!['high']} mm',
              ),
              const SizedBox(height: 6),
            ],
            if (_referenceEt0Total != null) ...[
              Text(
                '${_t('referenceEt0')}: ${_referenceEt0Total!.toStringAsFixed(1)} mm',
              ),
            ],
            if (_estimatedCropWaterNeedTotal != null) ...[
              Text(
                '${_t('cropWaterNeed')}: ${_estimatedCropWaterNeedTotal!.toStringAsFixed(1)} mm',
              ),
            ],
            if (_netWaterBalanceTotal != null) ...[
              Text(
                '${_t('waterBalance')}: ${_netWaterBalanceTotal!.toStringAsFixed(1)} mm',
              ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            date.split('-')[2], // Day only
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
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
                  earthEngineReady
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
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
                  color: earthEngineReady
                      ? Colors.black87
                      : Colors.orange.shade900,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text('${_t('detectedCrop')}: $detectedCrop'),
            Text(
              '${_t('confidence')}: ${(confidence as num).toStringAsFixed(2)}',
            ),
            if (ndvi != null) Text('NDVI: ${(ndvi as num).toStringAsFixed(3)}'),
            if (precipitation7day != null)
              Text(
                '7d Rainfall: ${(precipitation7day as num).toStringAsFixed(1)} mm',
              ),
            if (referenceEt07day != null)
              Text(
                '${_t('referenceEt0')}: ${(referenceEt07day as num).toStringAsFixed(1)} mm',
              ),
            if (cropWaterNeed7day != null)
              Text(
                '${_t('cropWaterNeed')}: ${(cropWaterNeed7day as num).toStringAsFixed(1)} mm',
              ),
            if (waterBalance7day != null)
              Text(
                '${_t('waterBalance')}: ${(waterBalance7day as num).toStringAsFixed(1)} mm',
              ),
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
      appBar: AppBar(title: Text(_t('cropInstructions'))),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _t('languageLabel'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'English',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(value: 'Urdu', child: Text('اردو')),
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
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
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
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _t('longitude'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _useCurrentPhoneLocation,
                icon: const Icon(Icons.my_location),
                label: Text(_t('usePhoneLocation')),
              ),
              const SizedBox(height: 8),
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _provinceAutoDetected
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _provinceAutoDetected
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFFFCC80),
                  ),
                ),
                child: Text(
                  _provinceAutoDetected
                      ? '${_t('autoDetectedProvince')}: ${_provinceLabel(_selectedProvince)}'
                      : '${_t('provinceLabel')}: ${_provinceLabel(_selectedProvince)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _provinceAutoDetected
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCropCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('cropCategoryLabel'),
                  border: const OutlineInputBorder(),
                ),
                items: _cropCategories
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _onCategoryChanged(value);
                },
              ),
              if (_selectedCropCategory == 'Field Crops') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Text(
                    '${_t('autoDetectedSeason')}: ${_seasonLabel(_selectedSeason)}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCrop,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('selectCropPrompt'),
                  border: const OutlineInputBorder(),
                ),
                items: _cropsForCategory()
                    .map(
                      (crop) => DropdownMenuItem<String>(
                        value: crop,
                        child: Text(_cropLabel(crop)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCrop = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CropInstructionsScreen.withData(
                      cropName: _cropInstructionsTitle(_selectedCrop),
                      cropKey: _selectedCrop,
                      sections: _cropInstructionSections(_selectedCrop),
                    ),
                  ),
                ),
                child: Text(_t('openSelectedCropGuide')),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CropPhotoRecommendationScreen(
                      selectedLanguage: _selectedLanguage,
                      selectedCrop: _selectedCrop,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _selectedLanguage == 'Urdu'
                      ? 'فصل کی تصویر سے سفارش حاصل کریں'
                      : 'Get recommendation from crop photo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropPhotoRecommendationScreen extends StatefulWidget {
  const CropPhotoRecommendationScreen({
    super.key,
    required this.selectedLanguage,
    required this.selectedCrop,
  });

  final String selectedLanguage;
  final String selectedCrop;

  @override
  State<CropPhotoRecommendationScreen> createState() =>
      _CropPhotoRecommendationScreenState();
}

class _CropPhotoRecommendationScreenState
    extends State<CropPhotoRecommendationScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _fertilizerHistoryController = TextEditingController();
  final TextEditingController _caseIdController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String _concernType = 'nutrient_deficiency';
  bool _submitting = false;
  bool _checkingReviewStatus = false;
  String? _error;
  Map<String, dynamic>? _recommendation;

  bool get _isUrdu => widget.selectedLanguage == 'Urdu';

  String _t(String en, String ur) => _isUrdu ? ur : en;

  @override
  void dispose() {
    _notesController.dispose();
    _fertilizerHistoryController.dispose();
    _caseIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _t(
          'Could not pick image. Please try again.',
          'تصویر منتخب نہیں ہو سکی، دوبارہ کوشش کریں۔',
        );
      });
    }
  }

  Future<void> _submitForRecommendation() async {
    if (_selectedImageBytes == null) {
      setState(() {
        _error = _t(
          'Please select a crop photo first.',
          'پہلے فصل کی تصویر منتخب کریں۔',
        );
      });
      return;
    }

    if (_fertilizerHistoryController.text.trim().length < 3) {
      setState(() {
        _error = _t(
          'Please tell what fertilizers were applied since sowing.',
          'براہ کرم بتائیں کہ بوائی کے بعد کون سی کھادیں استعمال کی گئیں۔',
        );
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _recommendation = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendBaseUrl/crop-photo-recommendation'),
      );
      request.fields['selected_crop'] = widget.selectedCrop;
      request.fields['concern_type'] = _concernType;
      request.fields['fertilizer_history'] = _fertilizerHistoryController.text.trim();
      request.fields['notes'] = _notesController.text.trim();
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          _selectedImageBytes!,
          filename: _selectedImageName ?? 'crop_photo.jpg',
        ),
      );

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception(responseBody);
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendation = decoded;
        final caseId = decoded['review_case_id']?.toString() ?? '';
        if (caseId.isNotEmpty) {
          _caseIdController.text = caseId;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _t(
          'Unable to get recommendation right now. Please try again later.',
          'فی الحال سفارش حاصل نہیں ہو سکی۔ براہ کرم بعد میں دوبارہ کوشش کریں۔',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _checkReviewStatus() async {
    final caseId = _caseIdController.text.trim();
    if (caseId.isEmpty) {
      setState(() {
        _error = _t(
          'Please enter a case ID first.',
          'براہ کرم پہلے کیس آئی ڈی درج کریں۔',
        );
      });
      return;
    }

    setState(() {
      _checkingReviewStatus = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '$backendBaseUrl/crop-photo-cases/${Uri.encodeComponent(caseId)}',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final statusData = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      setState(() {
        _recommendation ??= <String, dynamic>{};
        _recommendation!['review_case_id'] =
            statusData['review_case_id']?.toString() ?? caseId;
        _recommendation!['review_status'] =
            statusData['review_status']?.toString() ?? 'pending_review';
        _recommendation!['review_message'] =
            _recommendation!['review_status'] == 'reviewed'
            ? _t(
                'Expert review completed. Final recommendation updated.',
                'ماہر کا جائزہ مکمل ہو گیا۔ حتمی سفارش اپڈیٹ کر دی گئی ہے۔',
              )
            : _t(
                'Case is still in review queue.',
                'کیس ابھی جائزہ قطار میں ہے۔',
              );

        if ((statusData['recommendation']?.toString() ?? '').isNotEmpty) {
          _recommendation!['recommendation'] = statusData['recommendation'];
        }
        if ((statusData['reviewer_notes']?.toString() ?? '').isNotEmpty) {
          _recommendation!['confidence_note'] = statusData['reviewer_notes'];
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _t(
          'Unable to fetch review status right now.',
          'فی الحال جائزہ کی حالت حاصل نہیں ہو سکی۔',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingReviewStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('Crop Photo Recommendation', 'فصل کی تصویر سے سفارش'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'Selected crop: ${widget.selectedCrop}',
                      'منتخب فصل: ${widget.selectedCrop}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Upload a clear crop photo. You will get an instant preliminary recommendation and your case will also be sent for expert review.',
                      'فصل کی واضح تصویر اپ لوڈ کریں۔ آپ کو فوری ابتدائی سفارش ملے گی اور کیس ماہر کے جائزے کے لیے بھیجا جائے گا۔',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_t('Pick from gallery', 'گیلری سے منتخب کریں')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(_t('Use camera', 'کیمرہ استعمال کریں')),
                      ),
                    ],
                  ),
                  if (_selectedImageBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _selectedImageBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedImageName ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _caseIdController,
                    enabled: !_submitting && !_checkingReviewStatus,
                    decoration: InputDecoration(
                      labelText: _t('Case ID (for follow-up)', 'فالو اَپ کے لیے کیس آئی ڈی'),
                      hintText: _t('Paste your review case ID', 'اپنی ریویو کیس آئی ڈی یہاں درج کریں'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_submitting || _checkingReviewStatus)
                          ? null
                          : _checkReviewStatus,
                      icon: _checkingReviewStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _checkingReviewStatus
                            ? _t('Checking...', 'چیک ہو رہا ہے...')
                            : _t('Check review status', 'جائزہ کی حالت چیک کریں'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _concernType,
                    decoration: InputDecoration(
                      labelText: _t('Concern type', 'مسئلے کی قسم'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'nutrient_deficiency',
                        child: Text(_t('Nutrient deficiency', 'غذائی کمی')),
                      ),
                      DropdownMenuItem(
                        value: 'insect_pests',
                        child: Text(_t('Insect pests', 'کیڑے')),
                      ),
                      DropdownMenuItem(
                        value: 'disease',
                        child: Text(_t('Disease', 'بیماری')),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _concernType = value);
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fertilizerHistoryController,
                    minLines: 2,
                    maxLines: 4,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: _t(
                        'Fertilizers applied since sowing (required)',
                        'بوائی کے بعد استعمال شدہ کھادیں (ضروری)',
                      ),
                      hintText: _t(
                        'Example: 1 bag DAP at sowing, 1.5 bags urea at 25 days, potash spray once',
                        'مثال: بوائی پر 1 بوری ڈی اے پی، 25 دن بعد 1.5 بوری یوریا، ایک بار پوٹاش اسپرے',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      labelText: _t(
                        'Symptoms notes (optional)',
                        'علامات کی تفصیل (اختیاری)',
                      ),
                      hintText: _t(
                        'Example: yellow lower leaves, holes in leaves, slow growth',
                        'مثال: نچلے پتوں میں پیلاہٹ، پتوں میں سوراخ، سست بڑھوتری',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitForRecommendation,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _submitting
                            ? _t('Analyzing...', 'تجزیہ جاری ہے...')
                            : _t('Get recommendation', 'سفارش حاصل کریں'),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_recommendation != null)
            Card(
              color: const Color(0xFFF7FBF8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Preliminary recommendation', 'ابتدائی سفارش'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recommendation!['possible_issue']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'Review status: ${_recommendation!['review_status'] ?? 'pending_review'}',
                        'جائزہ کی حالت: ${_recommendation!['review_status'] ?? 'pending_review'}',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                    if ((_recommendation!['review_case_id']?.toString() ?? '').isNotEmpty)
                      Text(
                        _t(
                          'Case ID: ${_recommendation!['review_case_id']}',
                          'کیس آئی ڈی: ${_recommendation!['review_case_id']}',
                        ),
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    if ((_recommendation!['review_message']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _recommendation!['review_message']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'Model: ${_recommendation!['model_label'] ?? 'n/a'} (${((( _recommendation!['model_confidence'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(0)}%)',
                        'ماڈل: ${_recommendation!['model_label'] ?? 'n/a'} (${((( _recommendation!['model_confidence'] as num?)?.toDouble() ?? 0.0) * 100).toStringAsFixed(0)}%)',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_recommendation!['recommendation']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      _recommendation!['confidence_note']?.toString() ?? '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    ...((_recommendation!['next_steps'] as List<dynamic>? ?? [])
                        .map((step) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• ${step.toString()}'),
                            ))),
                    const SizedBox(height: 8),
                    Text(
                      _recommendation!['disclaimer']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CropInstructionsScreen extends StatefulWidget {
  const CropInstructionsScreen({super.key})
    : cropName = '',
      cropKey = 'Wheat',
      sections = const <Map<String, String>>[];

  const CropInstructionsScreen.withData({
    super.key,
    required this.cropName,
    required this.cropKey,
    required this.sections,
  });

  final String cropName;
  final String cropKey;
  final List<Map<String, String>> sections;

  @override
  State<CropInstructionsScreen> createState() => _CropInstructionsScreenState();
}

class _CropInstructionsScreenState extends State<CropInstructionsScreen> {
  String? _selectedSectionTitle;

  @override
  void initState() {
    super.initState();
    if (widget.sections.isNotEmpty) {
      _selectedSectionTitle = widget.sections.first['title'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(widget.cropName);
    final selectedEntry = widget.sections.firstWhere(
      (entry) => entry['title'] == _selectedSectionTitle,
      orElse: () => widget.sections.isNotEmpty
          ? widget.sections.first
          : const <String, String>{},
    );
    final formulaText = _formulaTextFor(
      widget.cropKey,
      selectedEntry['sectionKey'] ?? '',
      isUrdu,
    );
    final deficiencyText = _deficiencyTextFor(
      widget.cropKey,
      selectedEntry['sectionKey'] ?? '',
      isUrdu,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.cropName)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedSectionTitle,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _uiTextFor(widget.cropName, 'sectionLabel'),
              border: const OutlineInputBorder(),
            ),
            items: widget.sections
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry['title'],
                    child: Text(entry['title'] ?? ''),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedSectionTitle = value;
              });
            },
          ),
          const SizedBox(height: 12),
          if (selectedEntry.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedEntry['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedEntry['content'] ?? '',
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (deficiencyText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _uiTextFor(
                                widget.cropName,
                                'deficiencySymptomsTitle',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              deficiencyText,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _uiTextFor(
                                widget.cropName,
                                'deficiencyPhotosTitle',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 150,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _deficiencyPhotoCards(
                                  widget.cropKey,
                                ).length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final card = _deficiencyPhotoCards(
                                    widget.cropKey,
                                  )[index];
                                  final label = isUrdu
                                      ? _nutrientLabelUrdu(card['nutrient']!)
                                      : card['nutrient']!;
                                  final assetCandidates =
                                      _deficiencyPhotoAssetCandidates(
                                        widget.cropKey,
                                        card['nutrient']!,
                                      );
                                  return SizedBox(
                                    width: 190,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: _DeficiencyAssetImage(
                                              candidatePaths: assetCandidates,
                                              missingText: _uiTextFor(
                                                widget.cropName,
                                                'photoNotAddedYet',
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _uiTextFor(
                                widget.cropName,
                                'deficiencyPhotosNote',
                              ),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DeficiencyPhotoDebugScreen(
                                            cropName: widget.cropName,
                                            cropKey: widget.cropKey,
                                            isUrdu: isUrdu,
                                          ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.bug_report_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _uiTextFor(
                                    widget.cropName,
                                    'debugMissingPhotosButton',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (formulaText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _uiTextFor(
                                widget.cropName,
                                'formulaRecommendationsTitle',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formulaText,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uiTextFor(widget.cropName, 'miniFormatTitle'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_uiTextFor(widget.cropName, 'timingLabel')}: ${selectedEntry['timing'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_uiTextFor(widget.cropName, 'doseRateLabel')}: ${selectedEntry['doseRate'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_uiTextFor(widget.cropName, 'monitoringIntervalLabel')}: ${selectedEntry['monitoring'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_uiTextFor(widget.cropName, 'actionThresholdLabel')}: ${selectedEntry['threshold'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uiTextFor(widget.cropName, 'importantNoteTitle'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _uiTextFor(widget.cropName, 'importantNoteBody'),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _uiTextFor(String currentCropName, String key) {
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(currentCropName);
    return uiTextByLanguage[isUrdu ? 'Urdu' : 'English']?[key] ??
        uiTextByLanguage['English']![key] ??
        key;
  }

  String? _formulaTextFor(String cropKey, String sectionKey, bool isUrdu) {
    if (sectionKey == 'diseases') {
      final map = isUrdu
          ? diseaseFormulasByCropUrdu
          : diseaseFormulasByCropEnglish;
      return map[cropKey];
    }
    if (sectionKey == 'pests') {
      final map = isUrdu
          ? pesticideFormulasByCropUrdu
          : pesticideFormulasByCropEnglish;
      return map[cropKey];
    }
    if (sectionKey == 'weeds') {
      final map = isUrdu
          ? weedicideFormulasByCropUrdu
          : weedicideFormulasByCropEnglish;
      return map[cropKey];
    }
    return null;
  }

  String? _deficiencyTextFor(String cropKey, String sectionKey, bool isUrdu) {
    if (sectionKey != 'fertilizer') {
      return null;
    }
    final map = isUrdu
        ? deficiencySymptomsByCropUrdu
        : deficiencySymptomsByCropEnglish;
    return map[cropKey];
  }

  List<Map<String, String>> _deficiencyPhotoCards(String cropKey) {
    final nutrients =
        deficiencyNutrientsByCrop[cropKey] ??
        const <String>['Nitrogen', 'Phosphorus', 'Potassium'];
    return nutrients.map((nutrient) => {'nutrient': nutrient}).toList();
  }

  List<String> _deficiencyPhotoAssetCandidates(
    String cropKey,
    String nutrient,
  ) {
    final cropTag = cropKey.toLowerCase();
    final nutrientTag = nutrient.toLowerCase().replaceAll(' ', '_');
    return deficiencyImageExtensions
        .map((ext) => 'assets/images/deficiencies/$cropTag/$nutrientTag.$ext')
        .toList();
  }

  String _nutrientLabelUrdu(String nutrient) {
    switch (nutrient) {
      case 'Nitrogen':
        return 'نائٹروجن کی کمی';
      case 'Phosphorus':
        return 'فاسفورس کی کمی';
      case 'Potassium':
        return 'پوٹاش کی کمی';
      case 'Zinc':
        return 'زنک کی کمی';
      case 'Sulfur':
        return 'سلفر کی کمی';
      case 'Boron':
        return 'بوران کی کمی';
      case 'Magnesium':
        return 'میگنیشیم کی کمی';
      case 'Iron':
        return 'آئرن کی کمی';
      default:
        return '$nutrient کی کمی';
    }
  }
}

class _DeficiencyAssetImage extends StatefulWidget {
  const _DeficiencyAssetImage({
    required this.candidatePaths,
    required this.missingText,
  });

  final List<String> candidatePaths;
  final String missingText;

  @override
  State<_DeficiencyAssetImage> createState() => _DeficiencyAssetImageState();
}

class _DeficiencyAssetImageState extends State<_DeficiencyAssetImage> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.candidatePaths.isEmpty) {
      return _buildMissingCard();
    }

    final currentPath = widget.candidatePaths[_activeIndex];
    return Image.asset(
      currentPath,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        if (_activeIndex < widget.candidatePaths.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _activeIndex += 1;
            });
          });
          return const SizedBox.expand();
        }
        return _buildMissingCard();
      },
    );
  }

  Widget _buildMissingCard() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(
            widget.missingText,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class DeficiencyPhotoDebugScreen extends StatelessWidget {
  const DeficiencyPhotoDebugScreen({
    super.key,
    required this.cropName,
    required this.cropKey,
    required this.isUrdu,
  });

  final String cropName;
  final String cropKey;
  final bool isUrdu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isUrdu ? 'تصاویر ڈیبگ: $cropName' : 'Photo Debug: $cropName',
        ),
      ),
      body: FutureBuilder<List<_DeficiencyPhotoStatus>>(
        future: _loadStatus(cropKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isUrdu
                      ? 'AssetManifest پڑھنے میں مسئلہ آیا۔'
                      : 'Unable to read AssetManifest for photo debug.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rows = snapshot.data ?? const <_DeficiencyPhotoStatus>[];
          if (rows.isEmpty) {
            return Center(
              child: Text(
                isUrdu
                    ? 'اس فصل کے لیے کوئی فہرست نہیں ملی۔'
                    : 'No nutrient list found for this crop.',
              ),
            );
          }

          final missingCount = rows
              .where((row) => row.foundPath == null)
              .length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    isUrdu
                        ? 'کل ${rows.length} غذائی تصاویر، غائب: $missingCount'
                        : 'Total nutrient photos: ${rows.length}, missing: $missingCount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...rows.map((row) {
                final isFound = row.foundPath != null;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isFound
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: isFound ? Colors.green : Colors.orange,
                    ),
                    title: Text(
                      isUrdu
                          ? _nutrientLabelUrduStatic(row.nutrient)
                          : row.nutrient,
                    ),
                    subtitle: Text(
                      isFound
                          ? '${isUrdu ? 'ملا' : 'Found'}: ${row.foundPath}'
                          : '${isUrdu ? 'متوقع' : 'Expected'}: ${row.candidates.join(', ')}',
                    ),
                    isThreeLine: !isFound,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<List<_DeficiencyPhotoStatus>> _loadStatus(String key) async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(manifest) as Map<String, dynamic>;
    final manifestPaths = decoded.keys.toSet();

    final nutrients =
        deficiencyNutrientsByCrop[key] ??
        const <String>['Nitrogen', 'Phosphorus', 'Potassium'];
    return nutrients.map((nutrient) {
      final cropTag = key.toLowerCase();
      final nutrientTag = nutrient.toLowerCase().replaceAll(' ', '_');
      final candidates = deficiencyImageExtensions
          .map((ext) => 'assets/images/deficiencies/$cropTag/$nutrientTag.$ext')
          .toList();
      String? foundPath;
      for (final candidate in candidates) {
        if (manifestPaths.contains(candidate)) {
          foundPath = candidate;
          break;
        }
      }
      return _DeficiencyPhotoStatus(
        nutrient: nutrient,
        candidates: candidates,
        foundPath: foundPath,
      );
    }).toList();
  }

  static String _nutrientLabelUrduStatic(String nutrient) {
    switch (nutrient) {
      case 'Nitrogen':
        return 'نائٹروجن کی کمی';
      case 'Phosphorus':
        return 'فاسفورس کی کمی';
      case 'Potassium':
        return 'پوٹاش کی کمی';
      case 'Zinc':
        return 'زنک کی کمی';
      case 'Sulfur':
        return 'سلفر کی کمی';
      case 'Boron':
        return 'بوران کی کمی';
      case 'Magnesium':
        return 'میگنیشیم کی کمی';
      case 'Iron':
        return 'آئرن کی کمی';
      default:
        return '$nutrient کی کمی';
    }
  }
}

class _DeficiencyPhotoStatus {
  const _DeficiencyPhotoStatus({
    required this.nutrient,
    required this.candidates,
    required this.foundPath,
  });

  final String nutrient;
  final List<String> candidates;
  final String? foundPath;
}

const Map<String, Map<String, String>> uiTextByLanguage = {
  'English': {
    'instructions': 'Instructions',
    'cropInstructions': 'Crop Instructions',
    'sectionLabel': 'Section',
    'seasonLabel': 'Season',
    'cropCategoryLabel': 'Crop Category',
    'cultivationSection': 'Cultivation',
    'fertilizerManagementSection': 'Fertilizer Management',
    'prevalentCropDiseasesSection': 'Prevalent Crop Diseases',
    'specificInsectPestsSection': 'Specific Insect Pests',
    'specificWeedsSection': 'Specific Weeds to Control',
    'deficiencySymptomsTitle': 'Nutrient Deficiency Symptoms',
    'deficiencyPhotosTitle': 'Deficiency Photos',
    'deficiencyPhotosNote':
        'Add your own crop photos in assets/images/deficiencies/<crop>/<nutrient>.(jpg|jpeg|png) and verify diagnosis with multiple symptoms and field history.',
    'debugMissingPhotosButton': 'Debug missing photos',
    'photoNotAddedYet': 'Photo not added yet',
    'formulaRecommendationsTitle': 'Recommended Active Formulas (No Brand)',
    'miniFormatTitle': 'Quick Field Format',
    'timingLabel': 'Timing',
    'doseRateLabel': 'Dose/Rate',
    'monitoringIntervalLabel': 'Monitoring Interval',
    'actionThresholdLabel': 'Action Threshold',
    'miniCultivationTiming': 'Before sowing and at key growth stages.',
    'miniCultivationDoseRate':
        'Use recommended seed rate, spacing, and irrigation volume for your soil type.',
    'miniCultivationMonitoring':
        'Visit field every 5-7 days; increase frequency in stress weather.',
    'miniCultivationThreshold':
        'Act when plant stand, moisture, or visible stress goes below local advisory target.',
    'miniFertilizerTiming':
        'Basal application at sowing, then split top-dress at critical growth stages.',
    'miniFertilizerDoseRate':
        'Follow soil-test based dose and avoid one-time heavy nitrogen loading.',
    'miniFertilizerMonitoring':
        'Check crop color and growth every 7-10 days; verify moisture before top-dress.',
    'miniFertilizerThreshold':
        'Intervene when deficiency symptoms or soil-test indicators cross recommended limits.',
    'miniDiseaseTiming':
        'Begin preventive checks from early vegetative stage and continue to maturity.',
    'miniDiseaseDoseRate':
        'Use only label-approved fungicide/bactericide dose with correct interval.',
    'miniDiseaseMonitoring':
        'Scout at least weekly; increase to every 3-4 days in favorable disease weather.',
    'miniDiseaseThreshold':
        'Spray only after disease incidence/severity reaches district ETL or advisory trigger.',
    'miniPestTiming':
        'Start scouting from early crop establishment and continue through reproductive stage.',
    'miniPestDoseRate':
        'Use ETL-based, label-approved dose and rotate mode of action.',
    'miniPestMonitoring':
        'Inspect field every 5-7 days; use traps and hotspot scouting where applicable.',
    'miniPestThreshold':
        'Take action only when pest population crosses economic threshold level (ETL).',
    'miniWeedTiming':
        'Start weed control early (first 30-45 days), then repeat as needed by crop stage.',
    'miniWeedDoseRate':
        'Use recommended herbicide dose on label or timely manual/mechanical weeding.',
    'miniWeedMonitoring':
        'Check field every 5-7 days for fresh flushes, especially after irrigation/rain.',
    'miniWeedThreshold':
        'Act when weed density starts competing with crop stand or before weeds set seed.',
    'sectionPendingDetails': 'Details will be developed in this section.',
    'importantNoteTitle': 'Important Note',
    'importantNoteBody':
        'Use district agriculture advisory and label instructions before any spray. Confirm dose, re-entry interval, and pre-harvest interval. Consult a qualified agronomist for severe outbreaks.',
    'selectCropPrompt':
        'Select a crop to view farming instructions for your region:',
    'languageLabel': 'Language:',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'loadWeatherForLocation': 'Load weather for location',
    'pickLocationOnMap': 'Pick location on map',
    'usePhoneLocation': 'Use phone location',
    'recenterOnMyLocation': 'Recenter on my location',
    'boundarySelected': 'Boundary selected',
    'points': 'points',
    'analyzeFieldGis': 'Analyze Field (GIS)',
    'tapMapToSelect': 'Tap map to select location/boundary',
    'pointMode': 'Point mode',
    'boundaryMode': 'Boundary mode',
    'close': 'Close',
    'layer': 'Layer',
    'loadingEeTiles': 'Loading Earth Engine tiles...',
    'locatingPhone': 'Getting current phone location...',
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
    'locationServicesDisabled': 'Location services are disabled on this phone.',
    'locationPermissionDenied':
        'Location permission was denied. Please allow location access.',
    'unableToFetchWeather': 'Unable to fetch weather',
    'weatherDataMissing': 'Weather response missing required data',
    'highRainfallFor': 'High forecasted rainfall for',
    'lowRainfallFor': 'Low forecasted rainfall for',
    'moderateRainfallFor': 'Moderate rainfall for',
    'total': 'total',
    'reduceIrrigationAdvice':
        'Reduce irrigation and check soil before watering.',
    'increaseIrrigationAdvice':
        'Increase irrigation frequency and ensure sufficient moisture.',
    'standardIrrigationAdvice':
        'Keep standard irrigation schedule and monitor soil moisture.',
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
    'reduceIrrigationEtAdvice':
        'Forecast rainfall is above estimated crop demand. Reduce irrigation and avoid waterlogging.',
    'increaseIrrigationEtAdvice':
        'Forecast rainfall is below estimated crop demand. Increase irrigation in smaller, timely applications.',
    'balancedIrrigationEtAdvice':
        'Forecast rainfall is close to estimated crop demand. Keep moderate irrigation and confirm soil moisture.',
    'wheatGrowthStage': 'Wheat growth stage',
    'previousIrrigationsCount': 'Previous irrigations completed',
    'previousIrrigationsHint': 'Enter irrigation count, e.g. 1',
    'wheatStageSchedule': 'Stage irrigation number',
    'wheatStagePreSowing': 'Pre-sowing',
    'wheatStageCri': 'Crown root initiation',
    'wheatStageTillering': 'Tillering',
    'wheatStageJointing': 'Jointing / booting',
    'wheatStageGrainFilling': 'Grain filling',
    'wheatDemandContext': 'Forecast rainfall is',
    'against': 'against',
    'withEt0Short': 'with ET0',
    'leavingBalance': 'leaving a 7-day water balance of',
    'wheatStagePrefix': 'Wheat stage:',
    'previousIrrigationsNote': 'Previous irrigations:',
    'wheatPresowingNow':
        'Give pre-sowing irrigation now so the seedbed is uniformly moist before planting.',
    'wheatPresowingHold':
        'Hold pre-sowing irrigation for the moment if the seedbed is already workable and reassess after the next rainfall update.',
    'wheatIrrigationDueNow':
        'Irrigation is due now at this stage. Apply irrigation',
    'wheatIrrigationSoon':
        'Irrigation should be scheduled within 1-3 days. Prepare irrigation',
    'wheatIrrigationDelay':
        'This stage normally needs irrigation, but forecast rainfall can cover part of the demand. Delay irrigation',
    'wheatNextStage': 'Next key irrigation stage:',
    'wheatNextStagePlanned': 'Next planned irrigation stage:',
    'wheatStageAlreadyCovered':
        'The usual irrigation count for this stage is already completed. Reported count:',
    'wheatTooManyIrrigations':
        'Reported irrigations are already above the usual count for this stage. Reported count:',
    'wheatForStageLimit': 'usual stage limit:',
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
    'provinceLabel': 'Province / Region',
    'autoDetectedProvince': 'Auto-detected',
    'autoDetectedSeason': 'Auto-detected season',
    'regionalSowingWindowLabel': 'Regional sowing window',
    'regionalAdvisoryLabel': 'Regional advisory',
    'openSelectedCropGuide': 'Open selected crop guide',
    'kharifSeason': 'Kharif',
    'rabiSeason': 'Rabi',
  },
  'Urdu': {
    'instructions': 'ہدایات',
    'cropInstructions': 'فصل کی ہدایات',
    'sectionLabel': 'حصہ',
    'seasonLabel': 'موسم',
    'cropCategoryLabel': 'فصل کی قسم',
    'cultivationSection': 'کاشت',
    'fertilizerManagementSection': 'کھاد کا انتظام',
    'prevalentCropDiseasesSection': 'عام فصل بیماریاں',
    'specificInsectPestsSection': 'مخصوص کیڑے',
    'specificWeedsSection': 'قابلِ کنٹرول مخصوص جڑی بوٹیاں',
    'deficiencySymptomsTitle': 'غذائی کمی کی علامات',
    'deficiencyPhotosTitle': 'کمی کی تصاویر',
    'deficiencyPhotosNote':
        'اپنی تصاویر assets/images/deficiencies/<crop>/<nutrient>.(jpg|jpeg|png) میں شامل کریں اور حتمی تشخیص کے لیے متعدد علامات اور کھیت کی تاریخ دیکھیں۔',
    'debugMissingPhotosButton': 'غائب تصاویر چیک کریں',
    'photoNotAddedYet': 'تصویر ابھی شامل نہیں کی گئی',
    'formulaRecommendationsTitle': 'تجویز کردہ فعال فارمولے (بغیر برانڈ)',
    'miniFormatTitle': 'فوری فیلڈ فارمیٹ',
    'timingLabel': 'وقت',
    'doseRateLabel': 'مقدار/شرح',
    'monitoringIntervalLabel': 'نگرانی کا وقفہ',
    'actionThresholdLabel': 'کارروائی کی حد',
    'miniCultivationTiming': 'بوائی سے پہلے اور اہم بڑھوتری مراحل پر۔',
    'miniCultivationDoseRate':
        'اپنی زمین کے مطابق تجویز کردہ بیج شرح، فاصلہ اور آبپاشی مقدار اپنائیں۔',
    'miniCultivationMonitoring':
        'ہر 5 تا 7 دن بعد کھیت دیکھیں؛ موسمی دباؤ میں وقفہ کم کریں۔',
    'miniCultivationThreshold':
        'جب پودوں کی تعداد، نمی یا واضح دباؤ مقامی ہدف سے نیچے جائے تو فوری اقدام کریں۔',
    'miniFertilizerTiming':
        'بوائی پر بنیادی خوراک، پھر اہم مراحل پر تقسیم شدہ اوپری خوراک۔',
    'miniFertilizerDoseRate':
        'مٹی ٹیسٹ کے مطابق مقدار دیں اور نائٹروجن ایک بار میں زیادہ نہ ڈالیں۔',
    'miniFertilizerMonitoring':
        'ہر 7 تا 10 دن بعد رنگ اور بڑھوتری چیک کریں، اوپری خوراک سے پہلے نمی دیکھیں۔',
    'miniFertilizerThreshold':
        'جب کمی کی علامات یا مٹی ٹیسٹ مقررہ حد سے باہر ہو تو اصلاحی اقدام کریں۔',
    'miniDiseaseTiming':
        'ابتدائی سبز مرحلے سے حفاظتی نگرانی شروع کریں اور پختگی تک جاری رکھیں۔',
    'miniDiseaseDoseRate':
        'صرف لیبل کے مطابق منظور شدہ فنجی/بیکٹیری سائیڈ مقدار اور وقفہ استعمال کریں۔',
    'miniDiseaseMonitoring':
        'کم از کم ہفتہ وار نگرانی کریں؛ موزوں موسم میں ہر 3 تا 4 دن بعد کریں۔',
    'miniDiseaseThreshold':
        'بیماری کی شدت/پھیلاؤ ضلعی ETL یا ہدایت تک پہنچے تو ہی سپرے کریں۔',
    'miniPestTiming':
        'فصل کے ابتدائی قیام سے تولیدی مرحلے تک باقاعدہ نگرانی رکھیں۔',
    'miniPestDoseRate':
        'ETL کے مطابق لیبل منظور مقدار استعمال کریں اور موڈ آف ایکشن بدلتے رہیں۔',
    'miniPestMonitoring':
        'ہر 5 تا 7 دن بعد معائنہ کریں؛ جہاں ممکن ہو ٹریپ اور ہاٹ اسپاٹ نگرانی کریں۔',
    'miniPestThreshold':
        'صرف معاشی حدِ نقصان (ETL) عبور ہونے پر کارروائی کریں۔',
    'miniWeedTiming':
        'ابتدائی 30 تا 45 دن میں جڑی بوٹی کنٹرول شروع کریں، پھر ضرورت کے مطابق دہرائیں۔',
    'miniWeedDoseRate':
        'لیبل کے مطابق تجویز کردہ ہربی سائیڈ مقدار یا بروقت ہاتھ/مشینی گوڈی کریں۔',
    'miniWeedMonitoring':
        'ہر 5 تا 7 دن بعد نئی اگاؤ چیک کریں، خاص طور پر آبپاشی یا بارش کے بعد۔',
    'miniWeedThreshold':
        'جب جڑی بوٹیاں فصل سے مقابلہ شروع کریں یا بیج بنانے سے پہلے فوری کنٹرول کریں۔',
    'sectionPendingDetails': 'اس حصے کی تفصیل اگلے مرحلے میں تیار کی جائے گی۔',
    'importantNoteTitle': 'اہم نوٹ',
    'importantNoteBody':
        'کسی بھی سپرے سے پہلے ضلعی محکمہ زراعت کی ہدایات اور پروڈکٹ لیبل ضرور دیکھیں۔ مقدار، دوبارہ داخلہ وقفہ اور برداشت سے پہلے وقفہ لازماً چیک کریں۔ شدید حملے میں مستند ماہرِ زراعت سے مشورہ کریں۔',
    'selectCropPrompt':
        'اپنے علاقے کے لیے کاشتکاری ہدایات دیکھنے کے لیے فصل منتخب کریں:',
    'languageLabel': 'زبان:',
    'latitude': 'عرض بلد',
    'longitude': 'طول بلد',
    'loadWeatherForLocation': 'مقام کے لیے موسم لوڈ کریں',
    'pickLocationOnMap': 'نقشے سے مقام منتخب کریں',
    'usePhoneLocation': 'فون کی موجودہ لوکیشن استعمال کریں',
    'recenterOnMyLocation': 'میری لوکیشن پر نقشہ دوبارہ مرکز کریں',
    'boundarySelected': 'حد بندی منتخب',
    'points': 'نقاط',
    'analyzeFieldGis': 'کھیت کا تجزیہ (GIS)',
    'tapMapToSelect': 'مقام یا حد بندی منتخب کرنے کے لیے نقشے پر ٹیپ کریں',
    'pointMode': 'نقطہ موڈ',
    'boundaryMode': 'حد بندی موڈ',
    'close': 'بند کریں',
    'layer': 'لیئر',
    'loadingEeTiles': 'ارتھ انجن ٹائلز لوڈ ہو رہی ہیں...',
    'locatingPhone': 'فون کی موجودہ لوکیشن حاصل کی جا رہی ہے...',
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
    'locationServicesDisabled': 'فون میں لوکیشن سروس بند ہے۔',
    'locationPermissionDenied': 'لوکیشن کی اجازت نہیں ملی۔ براہ کرم اجازت دیں۔',
    'unableToFetchWeather': 'موسم حاصل نہیں ہو سکا',
    'weatherDataMissing': 'موسمی ڈیٹا نامکمل ہے',
    'highRainfallFor': 'زیادہ بارش کی پیشگوئی برائے',
    'lowRainfallFor': 'کم بارش کی پیشگوئی برائے',
    'moderateRainfallFor': 'درمیانی بارش برائے',
    'total': 'کل',
    'reduceIrrigationAdvice':
        'آبپاشی کم کریں اور پانی دینے سے پہلے زمین چیک کریں۔',
    'increaseIrrigationAdvice': 'آبپاشی بڑھائیں اور مناسب نمی یقینی بنائیں۔',
    'standardIrrigationAdvice':
        'معمول کی آبپاشی جاری رکھیں اور زمین کی نمی دیکھتے رہیں۔',
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
    'reduceIrrigationEtAdvice':
        'متوقع بارش فصل کی اندازہ شدہ ضرورت سے زیادہ ہے۔ آبپاشی کم کریں اور پانی کھڑا ہونے سے بچیں۔',
    'increaseIrrigationEtAdvice':
        'متوقع بارش فصل کی اندازہ شدہ ضرورت سے کم ہے۔ آبپاشی چھوٹے مگر بروقت وقفوں میں بڑھائیں۔',
    'balancedIrrigationEtAdvice':
        'متوقع بارش فصل کی اندازہ شدہ ضرورت کے قریب ہے۔ معتدل آبپاشی رکھیں اور مٹی کی نمی چیک کریں۔',
    'wheatGrowthStage': 'گندم کا بڑھوتری مرحلہ',
    'previousIrrigationsCount': 'پچھلی مکمل آبپاشیوں کی تعداد',
    'previousIrrigationsHint': 'آبپاشیوں کی تعداد درج کریں، مثلاً 1',
    'wheatStageSchedule': 'اس مرحلے کا آبپاشی نمبر',
    'wheatStagePreSowing': 'پیش از بوائی',
    'wheatStageCri': 'کراؤن روٹ انیشی ایشن',
    'wheatStageTillering': 'ٹیلرنگ',
    'wheatStageJointing': 'جوائنٹنگ / بوٹنگ',
    'wheatStageGrainFilling': 'دانہ بھراؤ',
    'wheatDemandContext': 'متوقع بارش',
    'against': 'کے مقابل',
    'withEt0Short': 'اور ای ٹی0',
    'leavingBalance': 'کے ساتھ 7 دن کا پانی توازن',
    'wheatStagePrefix': 'گندم کا مرحلہ:',
    'previousIrrigationsNote': 'پچھلی آبپاشیاں:',
    'wheatPresowingNow':
        'اب پیش از بوائی آبپاشی کریں تاکہ بیج بستر یکساں طور پر نم ہو جائے۔',
    'wheatPresowingHold':
        'اگر زمین قابلِ کاشت ہے تو فی الحال پیش از بوائی آبپاشی روکیں اور اگلی بارش کی تازہ کاری کے بعد دوبارہ دیکھیں۔',
    'wheatIrrigationDueNow': 'اس مرحلے پر آبپاشی ابھی ضروری ہے۔ آبپاشی کریں',
    'wheatIrrigationSoon': 'آبپاشی 1 تا 3 دن میں شیڈول کریں۔ آبپاشی تیار رکھیں',
    'wheatIrrigationDelay':
        'اس مرحلے پر عموماً آبپاشی درکار ہوتی ہے مگر متوقع بارش کچھ ضرورت پوری کر سکتی ہے۔ آبپاشی موخر کریں',
    'wheatNextStage': 'اگلا اہم آبپاشی مرحلہ:',
    'wheatNextStagePlanned': 'اگلا منصوبہ شدہ آبپاشی مرحلہ:',
    'wheatStageAlreadyCovered':
        'اس مرحلے کے لیے معمول کی آبپاشی تعداد پہلے ہی پوری ہو چکی ہے۔ درج تعداد:',
    'wheatTooManyIrrigations':
        'درج آبپاشیاں اس مرحلے کی معمول تعداد سے زیادہ ہیں۔ درج تعداد:',
    'wheatForStageLimit': 'اس مرحلے کی حد:',
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
    'provinceLabel': 'صوبہ / خطہ',
    'autoDetectedProvince': 'خودکار شناخت',
    'autoDetectedSeason': 'خودکار موسمی شناخت',
    'regionalSowingWindowLabel': 'علاقائی بوائی کا وقت',
    'regionalAdvisoryLabel': 'علاقائی مشورہ',
    'openSelectedCropGuide': 'منتخب فصل کی ہدایات کھولیں',
    'kharifSeason': 'خریف',
    'rabiSeason': 'ربیع',
  },
};

const Map<String, Map<String, String>> provinceLabelsByLanguage = {
  'English': {
    'Punjab': 'Punjab',
    'Sindh': 'Sindh',
    'Khyber Pakhtunkhwa': 'Khyber Pakhtunkhwa',
    'Balochistan': 'Balochistan',
    'Gilgit-Baltistan': 'Gilgit-Baltistan',
    'Azad Jammu and Kashmir': 'Azad Jammu and Kashmir',
  },
  'Urdu': {
    'Punjab': 'پنجاب',
    'Sindh': 'سندھ',
    'Khyber Pakhtunkhwa': 'خیبر پختونخوا',
    'Balochistan': 'بلوچستان',
    'Gilgit-Baltistan': 'گلگت بلتستان',
    'Azad Jammu and Kashmir': 'آزاد جموں و کشمیر',
  },
};

const Map<String, Map<String, Map<String, String>>>
provinceSeasonWindowsByLanguage = {
  'English': {
    'Punjab': {
      'Kharif':
          'Mostly Jun-Jul; in warmer belts some crops can start from late May with irrigation.',
      'Rabi':
          'Mostly Oct-Nov; in cooler belts wheat and barley can extend into early Dec.',
    },
    'Sindh': {
      'Kharif':
          'Mostly Apr-Jun due to early heat; cotton and rice calendars start earlier in lower Sindh.',
      'Rabi':
          'Mostly Oct-Dec with earlier vegetable/gram windows in upper Sindh where moisture allows.',
    },
    'Khyber Pakhtunkhwa': {
      'Kharif':
          'Mostly May-Jul; maize windows vary from plains to valleys with altitude.',
      'Rabi':
          'Mostly Oct-Nov in plains, with some high-elevation adjustments toward spring sowing.',
    },
    'Balochistan': {
      'Kharif':
          'Mostly Apr-Jun in irrigated valleys; rainfed windows depend strongly on local rainfall timing.',
      'Rabi':
          'Mostly Oct-Nov in valleys, while colder uplands may shift to later or spring-aligned windows.',
    },
    'Gilgit-Baltistan': {
      'Kharif': 'Mostly May-Jun in valleys after frost risk declines.',
      'Rabi':
          'Short and altitude-limited; many cereals are managed with local high-altitude calendars.',
    },
    'Azad Jammu and Kashmir': {
      'Kharif':
          'Mostly May-Jul depending on hill slope, rainfall onset, and elevation.',
      'Rabi':
          'Mostly Oct-Nov in lower belts, with delayed windows in colder zones.',
    },
  },
  'Urdu': {
    'Punjab': {
      'Kharif':
          'عموماً جون تا جولائی؛ گرم علاقوں میں کچھ فصلیں مئی کے آخر سے آبپاشی کے ساتھ شروع ہو سکتی ہیں۔',
      'Rabi':
          'عموماً اکتوبر تا نومبر؛ ٹھنڈے علاقوں میں گندم/جو کی بوائی دسمبر کے آغاز تک بڑھ سکتی ہے۔',
    },
    'Sindh': {
      'Kharif':
          'عموماً اپریل تا جون کیونکہ گرمی جلد شروع ہوتی ہے؛ زیریں سندھ میں کپاس/چاول کی کاشت عموماً پہلے شروع ہوتی ہے۔',
      'Rabi':
          'عموماً اکتوبر تا دسمبر؛ بالائی سندھ میں نمی کی دستیابی پر کچھ فصلیں جلد بھی لگ سکتی ہیں۔',
    },
    'Khyber Pakhtunkhwa': {
      'Kharif':
          'عموماً مئی تا جولائی؛ میدانی اور پہاڑی علاقوں میں بلندی کے مطابق اوقات مختلف ہوتے ہیں۔',
      'Rabi':
          'عموماً اکتوبر تا نومبر؛ بلند علاقوں میں کچھ فصلوں کے اوقات بہاری نظام کی طرف منتقل ہو سکتے ہیں۔',
    },
    'Balochistan': {
      'Kharif':
          'عموماً اپریل تا جون (آبپاش وادیوں میں)؛ بارانی علاقوں میں وقت مقامی بارش پر زیادہ منحصر ہوتا ہے۔',
      'Rabi':
          'عموماً اکتوبر تا نومبر؛ سرد بالائی علاقوں میں وقت کچھ تاخیر یا بہاری شیڈول کی طرف جا سکتا ہے۔',
    },
    'Gilgit-Baltistan': {
      'Kharif': 'وادیوں میں عموماً مئی تا جون، جب پالا کم ہو جائے۔',
      'Rabi':
          'مختصر اور بلندی سے متاثر؛ بہت سی فصلوں میں مقامی بلند علاقے کے شیڈول پر عمل کیا جاتا ہے۔',
    },
    'Azad Jammu and Kashmir': {
      'Kharif':
          'عموماً مئی تا جولائی؛ پہاڑی ڈھلان، بارش کے آغاز اور بلندی کے مطابق وقت بدلتا ہے۔',
      'Rabi':
          'عموماً اکتوبر تا نومبر؛ سرد علاقوں میں بوائی میں تاخیر ہو سکتی ہے۔',
    },
  },
};

const Map<String, Map<String, String>> provinceGeneralAdvisoryByLanguage = {
  'English': {
    'Punjab':
        'Canal-irrigated belts should prioritize irrigation scheduling by canal turn and avoid late heavy nitrogen before lodging-prone periods.',
    'Sindh':
        'High heat and salinity pockets require tighter irrigation-water quality checks and stronger whitefly/aphid vigilance in warm spells.',
    'Khyber Pakhtunkhwa':
        'Altitude and valley microclimates can shift pest/disease timing; scout fields frequently after sudden weather changes.',
    'Balochistan':
        'Water-scarce zones benefit from moisture conservation, mulching, and low-frequency deep irrigation rather than frequent light watering.',
    'Gilgit-Baltistan':
        'Short seasons require timely operations and frost-aware planning; prioritize early establishment and protected nurseries where needed.',
    'Azad Jammu and Kashmir':
        'High rainfall pockets increase foliar disease risk; improve drainage, spacing, and preventive scouting after wet periods.',
  },
  'Urdu': {
    'Punjab':
        'نہری آبپاشی علاقوں میں پانی کے ٹرن کے مطابق شیڈول بنائیں اور لیجنگ کے خطرے والے ادوار سے پہلے دیر سے زیادہ نائٹروجن سے گریز کریں۔',
    'Sindh':
        'زیادہ گرمی اور نمکیات والے علاقوں میں آبپاشی پانی کے معیار کی جانچ اور گرم موسم میں سفید مکھی/ایفڈ نگرانی مزید مضبوط رکھیں۔',
    'Khyber Pakhtunkhwa':
        'بلندی اور وادی کے خرد موسمی فرق سے کیڑے/بیماری کے اوقات بدل سکتے ہیں؛ اچانک موسمی تبدیلی کے بعد نگرانی بڑھائیں۔',
    'Balochistan':
        'پانی کی کمی والے علاقوں میں نمی محفوظ رکھنے، ملچ اور کم وقفے والی گہری آبپاشی کو ترجیح دیں۔',
    'Gilgit-Baltistan':
        'مختصر موسم میں بروقت زرعی سرگرمیاں اور پالا مدنظر منصوبہ بندی ضروری ہے؛ ابتدائی قیام کو ترجیح دیں۔',
    'Azad Jammu and Kashmir':
        'زیادہ بارش والے علاقوں میں پتوں کی بیماری کا خطرہ بڑھتا ہے؛ نکاس، پودا فاصلہ اور بارش کے بعد حفاظتی نگرانی بہتر رکھیں۔',
  },
};

const Map<String, Map<String, String>> cropLabelsByLanguage = {
  'English': {
    'Maize': 'Maize',
    'Wheat': 'Wheat',
    'Rice': 'Rice',
    'Potato': 'Potato',
    'Sugarcane': 'Sugarcane',
    'Cotton': 'Cotton',
    'Gram': 'Gram (Chickpea)',
    'Mustard': 'Mustard',
    'Bajra': 'Bajra (Pearl Millet)',
    'Barley': 'Barley',
    // Vegetables
    'Onion': 'Onion',
    'Tomato': 'Tomato',
    'Chilli': 'Chilli',
    'Brinjal': 'Brinjal (Eggplant)',
    // Fruits
    'Mango': 'Mango',
    'Citrus': 'Citrus (Kinnow)',
    'Guava': 'Guava',
    'Banana': 'Banana',
  },
  'Urdu': {
    'Maize': 'مکئی',
    'Wheat': 'گندم',
    'Rice': 'چاول',
    'Potato': 'آلو',
    'Sugarcane': 'گنا',
    'Cotton': 'کپاس',
    'Gram': 'چنا',
    'Mustard': 'سرسوں',
    'Bajra': 'باجرا',
    'Barley': 'جو',
    // سبزیاتیں
    'Onion': 'پیاز',
    'Tomato': 'ٹماٹر',
    'Chilli': 'مرچ',
    'Brinjal': 'بینگن',
    // پھل
    'Mango': 'آم',
    'Citrus': 'کنو/مالٹا',
    'Guava': 'امرود',
    'Banana': 'کیلا',
  },
};

const Map<String, Map<String, String>> cropInstructionsByLanguage = {
  'English': {
    'Maize': maizeInstructions,
    'Wheat': wheatInstructions,
    'Rice': riceInstructions,
    'Potato': potatoInstructions,
    'Sugarcane': sugarcaneInstructions,
    'Cotton': cottonInstructions,
    'Gram': gramInstructions,
    'Mustard': mustardInstructions,
    'Bajra': bajraInstructions,
    'Barley': barleyInstructions,
    // Vegetables
    'Onion': onionInstructions,
    'Tomato': tomatoInstructions,
    'Chilli': chilliInstructions,
    'Brinjal': brinjalInstructions,
    // Fruits
    'Mango': mangoInstructions,
    'Citrus': citrusInstructions,
    'Guava': guavaInstructions,
    'Banana': bananaInstructions,
  },
  'Urdu': {
    'Maize': maizeInstructionsUrdu,
    'Wheat': wheatInstructionsUrdu,
    'Rice': riceInstructionsUrdu,
    'Potato': potatoInstructionsUrdu,
    'Sugarcane': sugarcaneInstructionsUrdu,
    'Cotton': cottonInstructionsUrdu,
    'Gram': gramInstructionsUrdu,
    'Mustard': mustardInstructionsUrdu,
    'Bajra': bajraInstructionsUrdu,
    'Barley': barleyInstructionsUrdu,
    // Vegetables
    'Onion': onionInstructionsUrdu,
    'Tomato': tomatoInstructionsUrdu,
    'Chilli': chilliInstructionsUrdu,
    'Brinjal': brinjalInstructionsUrdu,
    // Fruits
    'Mango': mangoInstructionsUrdu,
    'Citrus': citrusInstructionsUrdu,
    'Guava': guavaInstructionsUrdu,
    'Banana': bananaInstructionsUrdu,
  },
};

const Map<String, Map<String, Map<String, String>>> cropSectionsByLanguage = {
  'English': {
    'Maize': {
      'cultivation':
          'Land preparation: well-drained, fine tilth seedbed with good leveling. Sowing windows in Pakistan vary by zone, commonly spring (Jan-Mar) and kharif (Jun-Jul). Seed rate: 8-10 kg/acre for hybrid grain maize. Row spacing: 60-75 cm with plant spacing adjusted by variety. Critical water stages: knee-high, tasseling, silking, and grain filling. Avoid prolonged moisture stress at tasseling/silking to protect yield.',
      'fertilizer':
          'Use soil-test guided fertilization. Typical target in irrigated fields is balanced NPK with nitrogen in 2-3 splits. Apply full phosphorus and potash at sowing; apply nitrogen split at early vegetative and pre-tasseling stages. In zinc-deficient soils, apply zinc sulfate as locally recommended. Avoid a single heavy nitrogen dose to reduce lodging and nutrient loss. Deficiency symptoms to watch: Nitrogen (uniform yellowing of older leaves), phosphorus (stunted growth, purplish tint), potassium (leaf-edge scorching), zinc (pale striping on young leaves). Adequate fertilization improves cob size, grain filling, stress tolerance, and final yield quality.',
      'diseases':
          'Major diseases include downy mildew, leaf blight, and stalk rot. Prevention: disease-tolerant hybrids, clean seed, crop rotation, and residue management. Ensure proper plant population and avoid prolonged leaf wetness where possible. Start scouting from early vegetative stage and remove heavily infected plants where practical.',
      'pests':
          'Key pests are stem borer and fall armyworm. Scout weekly, especially whorl stage onward. Use pheromone traps and field inspection (windowing, frass, damaged whorls). Conserve beneficial insects and apply control only after threshold-based confirmation from local advisory. Rotate insecticide mode of action to slow resistance.',
      'weeds':
          'Major maize weeds include Dhaman/Crabgrass (Digitaria sanguinalis), Itchgrass (Rottboellia), Bathu (Chenopodium album), and wild amaranths (Amaranthus spp.). Keep field clean during first 30-40 days after sowing. One early hand hoeing plus need-based herbicide program is effective. Remove escape weeds before flowering to reduce seed bank.',
    },
    'Wheat': {
      'cultivation':
          'Land preparation: fine, level seedbed with good drainage. Sowing window: 1 Nov-30 Nov (timely), up to mid-Dec for late sowing. Seed rate: 45-50 kg/acre (timely), 50-55 kg/acre (late). Row spacing: 22-25 cm. Irrigation plan: pre-sowing (if needed), then around crown root initiation (18-25 DAS), tillering (40-45 DAS), booting/jointing (70-80 DAS), and grain filling (95-105 DAS). Avoid water stress at CRI and grain filling stages.',
      'fertilizer':
          'Use soil-test based plan. General irrigated target: NPK about 48-24-16 kg/acre nutrient basis. Basal at sowing: full phosphorus + potash + 1/3 nitrogen. Top dress: 1/3 nitrogen at first irrigation (CRI) and 1/3 at second irrigation (tillering/jointing). In zinc-deficient soils, apply zinc sulfate as per local recommendation. Avoid late heavy nitrogen after heading to reduce lodging risk. Deficiency symptoms: Nitrogen (older leaves yellow, weak tillers), phosphorus (poor root growth, delayed maturity), potassium (leaf-tip burn), zinc (yellow bands/chlorosis). Adequate fertilization increases tiller survival, grain weight, and lodging resistance.',
      'diseases':
          'Major diseases: yellow/brown rust, loose smut, flag smut, and spot blotch. Prevention: resistant varieties, clean seed, balanced fertilizer (avoid excess N), and timely sowing. Seed treatment before sowing helps reduce seed-borne disease. For rust, scout weekly from tillering onward; if early pustules appear and weather favors spread, apply a recommended fungicide after local extension/vet-agri guidance.',
      'pests':
          'Key pests: aphids, armyworm/cutworm (local outbreaks), and termites in dry fields. IPM: field scouting every 5-7 days, conserve beneficial insects, avoid unnecessary broad-spectrum sprays, and control weeds on bunds. For aphids, focus checks from booting to milky stage; intervene only when infestation reaches economic threshold according to district advisory. For termites, ensure proper soil moisture and seed treatment in risk fields.',
      'weeds':
          'Common wheat weeds: Bathu (Chenopodium album), Wild oats/Jungli Jai (Avena fatua), Dumbi sitti (Phalaris minor), Krund (Convolvulus arvensis), and wild mustard (Sinapis arvensis). First 30-45 days are critical for control. Use clean seed, line sowing, and timely post-emergence control where needed. Remove surviving grassy weeds before seed setting.',
    },
    'Rice': {
      'cultivation':
          'Prepare puddled, level field with strong bunds to hold water. Nursery raising and transplanting should follow local calendar (typically Jun-Jul). Use healthy seedlings at recommended age and spacing. Keep shallow standing water after transplanting, then manage alternate wetting and drying where suitable. Avoid moisture stress at tillering and panicle initiation.',
      'fertilizer':
          'Apply full phosphorus and potash as basal at final puddling/transplanting. Nitrogen should be split: early establishment/tillering, active tillering, and panicle initiation based on crop color and growth. Zinc deficiency (bronzing/stunting) should be corrected through recommended zinc sulfate dose. Avoid excessive late nitrogen that increases lodging and pest pressure. Deficiency symptoms: Nitrogen (overall pale canopy), phosphorus (slow growth), potassium (leaf-margin drying), zinc (bronzing and stunted seedlings). Adequate fertilization improves tillering, panicle size, grain filling, and milling quality.',
      'diseases':
          'Major diseases: blast, bacterial leaf blight, and sheath blight. Use tolerant varieties, balanced nitrogen, and clean nursery practices. Avoid very dense canopy and prolonged high humidity pockets. Scout from tillering onward; remove severe hotspots and follow local fungicide guidance where disease crosses threshold.',
      'pests':
          'Important pests: stem borer, leaf folder, and planthoppers. Monitor dead-hearts/whiteheads for borers and folded leaves for leaf folder. For planthoppers, inspect lower canopy and avoid unnecessary pyrethroid use that can flare populations. Apply need-based control according to district advisories and ETL.',
      'weeds':
          'Major rice weeds include Jungle rice (Echinochloa colona), barnyard grass (Echinochloa crus-galli), sedges (Cyperus difformis), and broadleaf weeds like Monochoria. Keep nursery clean and maintain proper water depth after transplanting to suppress weeds. Early post-transplant weeding and stale seedbed practices reduce pressure significantly.',
    },
    'Potato': {
      'cultivation':
          'Select certified seed tubers and plant in well-prepared ridges in Oct-Nov window. Maintain proper seed spacing and ridge height for tuber expansion. Keep soil moist but never waterlogged; frequent light irrigation works best in many soils. Earthing-up should be timely to protect developing tubers from greening and pest exposure.',
      'fertilizer':
          'Apply balanced NPK based on soil status, with major share at planting and remaining nitrogen around earthing-up. Include organic manure before planting where available to improve soil structure. In deficient fields, add micronutrients based on diagnosis. Avoid heavy nitrogen late in season to reduce excessive vegetative growth and weak tuber quality. Deficiency symptoms: Nitrogen (pale foliage), phosphorus (slow canopy and root growth), potassium (leaf-edge burn, poor tuber bulking), boron/calcium issues (hollow heart/internal defects in sensitive fields). Adequate fertilization improves tuber size uniformity, dry matter, and storage quality.',
      'diseases':
          'Major diseases: late blight, early blight, and bacterial wilt (location dependent). Use clean seed, crop rotation, and disease-free irrigation sources. Begin preventive monitoring before canopy closure in cool/humid periods. Remove severely infected plants and use fungicide strategy based on weather risk and extension advice.',
      'pests':
          'Primary pests include aphids and potato tuber moth. Monitor aphid counts from early canopy stage; virus risk increases with aphid pressure. Keep ridges intact and avoid exposed tubers to reduce tuber moth attack. Use sanitation, timely haulm management, and threshold-based interventions.',
      'weeds':
          'Common potato weeds: Bathu (Chenopodium album), Lehli (Convolvulus arvensis), Poa annua, and pigweeds (Amaranthus spp.). Early-season weed control before canopy closure is most important. Combine pre-emergence herbicide (as recommended) with one or two intercultures/hand weedings. Keep ridges clean to protect tuber development.',
    },
    'Sugarcane': {
      'cultivation':
          'Use healthy, disease-free setts with proper bud viability. Plant in furrows/trenches with recommended row spacing and maintain good drainage. Ensure early establishment irrigation and weed-free field during initial 90-120 days. For ratoon crop, perform stubble shaving, gap filling, and early nutrient-water support.',
      'fertilizer':
          'Follow soil-test-based schedule with full phosphorus/potash at planting and nitrogen in multiple splits during active growth. Integrate organic manure/press mud where available for soil health. In ratoon, prioritize early nitrogen after first irrigation. Maintain balanced nutrition to support cane thickness and sugar recovery. Deficiency symptoms: Nitrogen (light green leaves, thin canes), phosphorus (poor rooting and slow growth), potassium (leaf drying from tip/edges), zinc/iron (chlorosis in young leaves). Adequate fertilization raises cane girth, tillering, juice quality, and sugar recovery.',
      'diseases':
          'Major diseases include red rot, smut, and wilt. Plant resistant varieties and use disease-free seed cane. Rogue out infected clumps promptly and avoid movement of infected setts. Maintain field sanitation and rotate with non-host crops when disease pressure is chronic.',
      'pests':
          'Key pests: early shoot borer and top borer. Monitor dead hearts and bore holes at regular intervals. Encourage biological control and avoid repeated use of same chemistry. Time interventions with pest stage and local advisory to improve effectiveness.',
      'weeds':
          'Important sugarcane weeds include doob grass (Cynodon dactylon), motha (Cyperus rotundus), Congress grass (Parthenium hysterophorus), and broadleaf annuals. First 90-120 days are critical for weed control. Use trash mulching, earthing-up, and integrated herbicide plus hoeing program. Keep inter-row area clean to avoid yield loss and pest shelter.',
    },
    'Cotton': {
      'cultivation':
          'Sow in recommended window (commonly May-Jun) with approved seed and proper plant stand. Maintain clean field borders and remove alternate host weeds. Irrigate by soil type and weather; avoid prolonged stress at square/flower/ball setting stages. Keep plant architecture balanced through good nutrition and timely interculture.',
      'fertilizer':
          'Base fertilizer on soil test. Apply phosphorus and potash largely at sowing with nitrogen split in 2-3 doses up to flowering/boll development. Monitor for potassium and boron-related deficiencies in high-yield fields. Avoid excessive nitrogen which can delay maturity and increase pest susceptibility. Deficiency symptoms: Nitrogen (pale leaves, weak growth), potassium (leaf scorching, poor boll filling), boron (flower/boll shedding, malformed bolls), magnesium (interveinal yellowing on older leaves). Adequate fertilization improves boll retention, lint quality, and earliness.',
      'diseases':
          'Major disease concern is cotton leaf curl virus; fungal spots/rots may occur with conducive weather. Use tolerant varieties and strict whitefly management to reduce virus spread. Remove severely affected plants early where practical and maintain balanced fertilization. Avoid overlap of old infected crop residues.',
      'pests':
          'Key pests are whitefly, jassid, thrips, and pink bollworm. Scout twice weekly during susceptible period and use pheromone traps for bollworm trend. Prioritize IPM and threshold-based sprays; rotate mode of action to reduce resistance. Destroy leftover bolls and crop residues post-harvest to suppress carryover populations.',
      'weeds':
          'Major cotton weeds: Trianthema (Itsit), horse purslane (Trianthema portulacastrum), doob grass, jungle booti, and pigweeds. Keep crop weed-free for first 45-60 days for better stand and nutrient use. Timely inter-row cultivation plus recommended pre/post-emergence herbicide gives best results. Remove weeds on bunds to reduce whitefly hosts.',
    },
    'Gram': {
      'cultivation':
          'Prefer well-drained loam/sandy loam and sow in Oct-Nov for rabi crop. Use seed treatment before sowing and maintain recommended row spacing. Gram usually needs limited irrigation; provide lifesaving irrigation at flowering/pod filling if drought develops. Keep early crop weed-free for better stand establishment.',
      'fertilizer':
          'Phosphorus is critical for root growth and nodulation; apply basal phosphorus as per soil test. Starter nitrogen in small dose may be used in low-fertility soils. Sulfur and micronutrients can be added where deficiencies are known. Avoid excessive nitrogen, which can reduce effective nodulation. Deficiency symptoms: phosphorus (poor root growth, weak nodules), sulfur (uniform yellowing in younger leaves), zinc/iron (chlorosis), boron (flower/pod issues). Adequate fertilization improves nodulation, pod setting, and seed weight.',
      'diseases':
          'Important diseases include Ascochyta blight and wilt complex. Use tolerant varieties and disease-free seed with fungicidal seed treatment. Avoid waterlogging and practice crop rotation with cereals. In favorable cool-humid weather, intensify scouting and follow advisory-based protection plan.',
      'pests':
          'Pod borer is the major pest. Start scouting at flowering and pod initiation, use pheromone traps, and monitor larval count. Conserve natural enemies and spray only at ETL. Prefer rotation of insecticide groups when repeated interventions are needed.',
      'weeds':
          'Common gram weeds include Bathu (Chenopodium album), wild oats (Avena spp.), and broadleaf winter weeds. Early competition reduces branching and pod set. One early hand weeding/interculture plus need-based herbicide can protect yield. Prevent seed set of persistent weeds to reduce next-season infestation.',
    },
    'Mustard': {
      'cultivation':
          'Sow in Oct-Nov on fine seedbed with proper line spacing for good aeration. Ensure timely thinning and weed control in early growth. Usually 1-2 irrigations are sufficient depending on rainfall and soil type, with critical stages at branching and flowering/pod filling. Avoid moisture stress during flowering for better seed set.',
      'fertilizer':
          'Apply balanced NPK based on soil test, with adequate sulfur support for oilseed quality. Use basal phosphorus/potash and split nitrogen if required by soil and irrigation conditions. Correct micronutrient deficiencies where identified. Balanced nutrition improves siliqua formation and seed filling. Deficiency symptoms: sulfur (pale younger leaves and low oil content), nitrogen (general chlorosis), boron (poor flowering/siliqua set), potassium (weak stems and poor grain filling). Adequate fertilization improves oil percentage, seed filling, and stand strength.',
      'diseases':
          'Common diseases include Alternaria blight and white rust. Preventive steps: tolerant varieties, crop residue management, and timely sowing. Avoid dense canopy and prolonged leaf wetness where possible. Monitor from vegetative stage onward and follow local disease-risk advisories.',
      'pests':
          'Mustard aphid is the principal pest; painted bug may appear in some areas. Monitor tender shoots and inflorescences regularly. Encourage natural enemies and avoid unnecessary early sprays. Intervene at threshold level with recommended chemistry and safe interval compliance.',
      'weeds':
          'Key mustard weeds: Bathu, Lehli (Convolvulus), wild oats, and wild mustard volunteers. First 30-40 days are critical for weed control. Timely hoeing/interculture and selective herbicide where required improve crop vigor. Keep field edges clean to avoid re-infestation.',
    },
    'Bajra': {
      'cultivation':
          'Bajra is suited to kharif and performs in light to medium soils with low rainfall risk. Sow at onset of monsoon with recommended spacing for airflow and root spread. Usually rainfed, but one lifesaving irrigation at flowering can protect yield in drought spells. Keep field weed-free in early growth to reduce competition.',
      'fertilizer':
          'Adopt balanced, low-input nutrition guided by soil fertility. Apply phosphorus at sowing and split nitrogen where moisture is adequate. In poor soils, organic manure before sowing improves moisture retention and nutrient efficiency. Avoid over-fertilization under moisture stress conditions. Deficiency symptoms: nitrogen (pale stunted plants), phosphorus (slow early growth), potassium (leaf-edge drying under stress), zinc (chlorotic striping in some soils). Adequate fertilization improves drought resilience, ear development, and grain test weight.',
      'diseases':
          'Major diseases are downy mildew and ergot in susceptible environments. Use resistant hybrids/varieties and clean seed. Remove heavily infected earheads and avoid saving seed from diseased fields. Crop rotation and field sanitation reduce inoculum pressure.',
      'pests':
          'Key pests include shoot fly and stem borer. Inspect seedling stage for dead-hearts and monitor tillering onward. Maintain timely sowing to escape peak pest windows where possible. Follow ETL-based interventions with local recommendations.',
      'weeds':
          'Common bajra weeds include doob grass, motha (Cyperus), and annual broadleaf species (Amaranthus, Trianthema). Early weed flush after first rains must be controlled quickly. One early interculture/hand weeding gives strong benefit under rainfed conditions. Prevent weeds from flowering to reduce seed bank buildup.',
    },
    'Barley': {
      'cultivation':
          'Sow timely in rabi season on well-prepared, well-drained field. Use recommended seed rate and maintain line sowing for better interculture. Barley generally needs fewer irrigations than wheat; prioritize tillering and grain-filling moisture. Avoid prolonged standing water to protect root health.',
      'fertilizer':
          'Use soil-test-based nutrient plan with basal phosphorus and staged nitrogen where needed. In low fertility soils, include organic sources for better soil condition. Excess late nitrogen can increase lodging and reduce grain quality. Keep nutrition balanced with expected yield target. Deficiency symptoms: nitrogen (older leaves pale), phosphorus (weak roots and slow tillering), potassium (leaf-tip burn), zinc (interveinal chlorosis). Adequate fertilization improves tiller vigor, grain plumpness, and quality stability.',
      'diseases':
          'Important diseases include loose smut, rusts, and leaf stripe. Use treated seed and resistant varieties where available. Follow rotation and residue management to reduce disease carryover. Scout regularly from early vegetative stage and respond as per advisory.',
      'pests':
          'Main insect concerns are aphids and occasional armyworm. Check undersides of leaves and ear emergence stage for aphid buildup. Encourage natural predators and avoid prophylactic spraying. Act at threshold with recommended products and interval compliance.',
      'weeds':
          'Barley weeds are similar to wheat: Phalaris minor, wild oats, Bathu, and broadleaf winter weeds. Early-stage competition is most damaging. Use line sowing, clean seed, and timely post-emergence control where needed. Rogue surviving weeds before seed shedding.',
    },
    'Onion': {
      'cultivation':
          'Deep, well-drained friable loam (pH 6.0–7.0). Nursery sowing Oct–Nov; transplant Dec–Jan (Rabi). Seed rate (direct): 3–4 kg/acre. Row spacing: 15×10 cm. Avoid waterlogging — causes neck rot. Critical irrigation during bulb initiation and development (90–120 DAS). Reduce irrigation 2 weeks before harvest to improve skin quality and storagability.',
      'fertilizer':
          'NPK ≈ 25-20-20 kg/acre nutrient basis. Sulfur 10–15 kg/acre improves bulb pungency and quality. Nitrogen in 3 splits (transplanting, 30 DAS, bulbing). Avoid excess nitrogen — delays maturity and reduces storageability. Deficiency symptoms: nitrogen (pale yellow thin leaves), sulfur (small bulbs, poor pungency), potassium (leaf-tip burn).',
      'diseases':
          'Purple blotch (Alternaria porri), downy mildew, basal rot (Fusarium). Measures: certified seed, proper spacing for airflow, avoid overhead irrigation at bulbing. Rotate fungicide modes if purple blotch observed.',
      'pests':
          'Thrips most damaging — silvery stippling on leaves, leading to top-down die-back in severe attacks. Scout weekly from transplanting. Onion fly maggot in seedbeds. Use sticky yellow traps; spray at threshold. Minimize pesticide use near harvest to protect quality.',
      'weeds':
          'Critical weed-free period: 0–45 DAS. Hand weeding plus pre-emergence pendimethalin effective. Mulch reduces soil moisture loss and weed emergence. Remove volunteer onion plants to reduce disease carry-over.',
    },
    'Tomato': {
      'cultivation':
          'Nursery Sept–Oct (Rabi) or Jan–Feb (spring/summer). Transplant at 25–30 DAE seedlings. Row spacing: 60×45 cm. Support stakes/strings for indeterminate varieties. Drip or furrow irrigation; avoid overhead wetting of foliage to limit disease. Fruiting delayed by extreme heat (>38°C) or cold (<10°C).',
      'fertilizer':
          'NPK ≈ 35-25-30 kg/acre nutrient basis. High potassium critical for fruit quality and shelf life. Calcium applications (gypsum or foliar calcium) prevent blossom end rot. Micronutrients (B, Zn) improve fruit set. Nitrogen in 4 splits (transplanting, flowering, early fruiting, mid-fruiting).',
      'diseases':
          'Early blight (Alternaria), late blight (Phytophthora), bacterial wilt, tomato leaf curl virus. IPM: resistant varieties, remove diseased plants promptly, rotate fungicide modes, manage whitefly vectors for virus prevention.',
      'pests':
          'Whitefly (virus vector), fruit borer (Helicoverpa), spider mites, aphids. Scout twice weekly. Pheromone traps for fruit borer. Reflective mulch reduces whitefly colonization. Avoid over-application of broad-spectrum insecticides.',
      'weeds':
          'Black polyethylene mulch highly effective: suppresses weeds and conserves moisture. Without mulch, use pre-emergence herbicide + 2 hand hoeings. Keep soil loosened between rows.',
    },
    'Chilli': {
      'cultivation':
          'Nursery Sept–Oct (Rabi). Transplant Nov–Dec. Row spacing: 45×30–45 cm. Heat and humidity cause flower/fruit drop. Protect from frost. Adequate soil drainage reduces Phytophthora risk. Harvest starts 60–90 days after transplanting and continues over multiple picks.',
      'fertilizer':
          'NPK ≈ 20-20-15 kg/acre nutrient basis. Boron foliar at flowering improves fruit set. Avoid excess nitrogen (delays fruiting, increases disease susceptibility).',
      'diseases':
          'Chilli leaf curl virus (CLCuV, whitefly-transmitted), anthracnose (Colletotrichum), damping-off in nursery. Key prevention: healthy certified seed, insect-proof nursery nets, promptly uproot virus-affected plants.',
      'pests':
          'Thrips, spider mites, whitefly (virus vector). IPM critical: sticky traps, reflective mulch, threshold-based sprays only, avoid broad-spectrum insecticides near harvest.',
      'weeds':
          'Mulch film highly effective. Pre-emergence pendimethalin followed by 1–2 manual hoeings. Keep inter-row area weed-free for first 40 days.',
    },
    'Brinjal': {
      'cultivation':
          'Transplant Sept–Oct (Rabi) or Feb–Mar (spring). Row spacing: 60–75×45–60 cm. Can be grown year-round in mild climates. Light pruning of older branches extends productive crop life. Avoid waterlogging — causes root and crown rot.',
      'fertilizer':
          'NPK ≈ 30-20-15 kg/acre nutrient basis. Nitrogen in 3 splits. Potassium especially important during fruiting. Mulch reduces soil-borne disease pressure.',
      'diseases':
          'Phomopsis blight, bacterial wilt, little leaf disease (phytoplasma). Remove infected plants promptly. Use healthy transplants from disease-free nursery. Crop rotation reduces soil pathogen buildup.',
      'pests':
          'Brinjal shoot and fruit borer (BSFB) — most critical pest. Pheromone trap monitoring essential. IPM: remove and destroy infested shoots/fruits, targeted sprays at threshold. Spider mites in hot dry weather.',
      'weeds':
          'Straw or polyethylene mulch reduces weed pressure significantly. Shallow inter-row cultivation and 1–2 hand hoeings during first 30 DAS.',
    },
    // Fruits
    'Mango': {
      'cultivation':
          'Orchard planting spacing: 8×8 to 10×10 m (high density 5×5 m). Major varieties: Sindhri, Chaunsa, Anwar Ratol, Fajri, Langra. Flowering Jan–Feb; fruit maturity May–July. Critical irrigation: panicle emergence, fruit set, and fruit development (Jan–May). Pre-harvest drip irrigation improves fruit uniformity and size.',
      'fertilizer':
          'Per bearing tree/year: N-P₂O₅-K₂O ≈ 750-300-500 g, split Jan, Apr, Aug. Zinc foliar (ZnSO₄ 0.5%) and boron at panicle emergence improve fruit set and quality. Organic manure incorporation improves soil structure. Foliar micronutrients post-harvest replenish tree reserves.',
      'diseases':
          'Powdery mildew (Oidium) at panicle stage; anthracnose on fruits; sooty mould secondary to insect honeydew. Spray wettable sulfur or myclobutanil at early panicle stage; copper fungicide before monsoon onset.',
      'pests':
          'Mango hopper (Amritodus/Idioscopus), mealybug, fruit fly (Bactrocera dorsalis), leaf webber. Spray copper/sulfur at panicle emergence. Bait stations for fruit fly around orchard. Mealybug: winter oil spray plus neem-based products.',
      'weeds':
          'Mulching under canopy reduces weeds and conserves moisture. Shallow tillage in inter-rows. Green cover crop in inter-rows reduces erosion and improves soil health.',
    },
    'Citrus': {
      'cultivation':
          'Major varieties: Kinnow mandarin, Musammi (sweet orange), Grapefruit. Spacing: 6×6 m standard or 4×5 m semi-dense. Flowering Feb–Mar; main harvest Dec–Feb. Irrigation: monthly in summer, every 6–8 weeks in winter. Avoid water stress at fruit development and pre-harvest.',
      'fertilizer':
          'Per bearing tree/year: N-P₂O₅-K₂O ≈ 400-200-300 g. Zinc, iron (chelated), and boron foliar sprays improve fruit size and quality. Fertilizer in 3 doses (Feb, May, Aug). Avoid excess nitrogen in August — reduces the following year\'s flowering.',
      'diseases':
          'Citrus canker (Xanthomonas), greasy spot, gummosis (Phytophthora). Copper-based sprays at 60-day intervals; maintain field drainage; avoid bark injuries. HLB (Huanglongbing/greening) — no cure; strict psylla vector management is the only prevention.',
      'pests':
          'Citrus psylla (key HLB vector), red spider mite, mealybug, leaf miner. Psylla management critical: systemic insecticide plus foliar where permitted, timed to new flush. Mite miticide spray in hot dry periods. Record and monitor to time interventions accurately.',
      'weeds':
          'Clean circle (±1 m radius) under each tree. Mulch or herbicide under canopy; controlled low vegetation in inter-rows. Avoid deep cultivation near fibrous citrus roots.',
    },
    'Guava': {
      'cultivation':
          'Main varieties: Safeda (Lahori), Gola, Surahi. Spacing: 6×6 m. Two fruiting seasons: winter (heavy, Oct–Jan) and summer (Jun–Aug). Light pruning after each harvest promotes new fruiting wood. Irrigation: every 7–10 days in summer, every 15–20 days in winter.',
      'fertilizer':
          'Per tree/year: N-P₂O₅-K₂O ≈ 500-250-400 g. FYM 20–30 kg/tree/year improves fruit size and quality. Zinc and boron foliar sprays improve fruit development. Fertilizer in 2–3 splits (post-harvest + pre-flowering).',
      'diseases':
          'Wilt (Fusarium/Pythium), anthracnose on fruits, algal spot. Remove infected trees; maintain drainage; copper fungicide at fruiting. Mulch under canopy to reduce soil moisture extremes.',
      'pests':
          'Fruit fly (Bactrocera), mealybug, guava whitefly, bark eating caterpillar. Fruit fly: bait stations; bag fruits for fresh market. Bark caterpillar: inject dichlorvos in bore hole and seal entry points.',
      'weeds':
          'Shallow cultivation under canopy; mulch conserves moisture. Herbicide on orchard floor bunds to reduce weed seed reservoir.',
    },
    'Banana': {
      'cultivation':
          'Main varieties: Basrai dwarf (Sindh), Lacatan, Robusta. Plant Feb–Mar or Sept–Oct. Use sword suckers; remove excess suckers. Spacing: 1.8×1.8 m high-density. Weekly irrigation in summer. Harvest 9–12 months from planting; bunch weight 20–35 kg depending on management.',
      'fertilizer':
          'High nutrient demand. NPK ≈ 100-30-200 g/plant/year N-P-K. Nitrogen in 4–5 monthly splits. Potassium is the yield-determining nutrient. Boron critical for bunch development. Organic matter incorporation essential for root health. Deficiency symptoms: palest youngest leaves (N), purpling (P), leaf-margin scorch (K).',
      'diseases':
          'Panama wilt (Fusarium oxysporum f.sp. cubense) — no cure; plant resistant varieties, do not move soil from infected areas. Sigatoka leaf spot: remove old leaves, apply copper or fungicide. Bunchy top virus (BBTV): aphid-transmitted; remove infected plants; use certified planting material only.',
      'pests':
          'Banana stem weevil (Cosmopolites sordidus): cut pseudostem after harvest, trap adults. Nematodes (Radopholus, Pratylenchus): cause root damage; nematicide at planting in high-risk soils. Thrips on fruit skin (cosmetic): bagging improves market quality.',
      'weeds':
          'Dense canopy after 3–4 months reduces weed pressure naturally. Mulch with dry leaves or straw during establishment. Manual weeding in inter-rows for first 2 months.',
    },
  },
  'Urdu': {
    'Maize': {
      'cultivation':
          'زمین کی تیاری: اچھی نکاس والی، بھربھری اور ہموار بیج بستر تیار کریں۔ پاکستان میں کاشت کے اہم اوقات علاقے کے لحاظ سے بہاری (جنوری تا مارچ) اور خریف (جون تا جولائی) ہو سکتے ہیں۔ ہائبرڈ مکئی کے لیے بیج کی شرح عموماً 8 تا 10 کلو فی ایکڑ اور قطاروں کا فاصلہ 60 تا 75 سینٹی میٹر رکھا جاتا ہے۔ اہم آبپاشی مراحل: گھٹنے کی اونچائی، ٹیسلنگ، سلکنگ اور دانہ بھرنا۔ ٹیسلنگ/سلکنگ پر پانی کی کمی سے پیداوار شدید متاثر ہوتی ہے۔',
      'fertilizer':
          'کھاد کا منصوبہ مٹی کے تجزیے کے مطابق بنائیں۔ عمومی طور پر متوازن این پی کے کے ساتھ نائٹروجن 2 تا 3 قسطوں میں دیں۔ فاسفورس اور پوٹاش کی مکمل مقدار بوائی کے وقت، جبکہ نائٹروجن سبز بڑھوتری اور ٹیسلنگ سے پہلے تقسیم کر کے دیں۔ زنک کی کمی والی زمین میں مقامی سفارش کے مطابق زنک سلفیٹ استعمال کریں۔ نائٹروجن ایک بار زیادہ مقدار میں دینے سے لیجنگ اور ضیاع کا خطرہ بڑھتا ہے۔ کمی کی علامات: نائٹروجن میں پرانے پتے پیلے، فاسفورس میں بڑھوتری کم اور جامنی جھلک، پوٹاش میں پتی کنارے جلنا، زنک میں نئی پتیاں ہلکی دھاری دار۔ مناسب کھاد سے بھٹے کا سائز، دانہ بھراؤ، تناؤ برداشت اور پیداوار بہتر ہوتی ہے۔',
      'diseases':
          'اہم بیماریاں: ڈاؤنی ملی ڈیو، لیف بلائٹ اور اسٹاک راٹ۔ بچاؤ کے لیے برداشت رکھنے والی اقسام، صاف بیج، فصلوں کی گردش اور باقیات کا مناسب انتظام کریں۔ پودوں کی مناسب تعداد اور ہوا کی آمدورفت برقرار رکھیں۔ ابتدائی سبز مرحلے سے باقاعدہ نگرانی کریں اور زیادہ متاثر پودے ممکن ہو تو نکال دیں۔',
      'pests':
          'اہم کیڑے: سٹیم بورر اور فال آرمی ورم۔ ہفتہ وار نگرانی کریں، خاص طور پر وہرل مرحلے سے۔ فیرومون ٹریپ اور پتوں کے نقصان/فرَس کی جانچ مفید ہے۔ مفید کیڑوں کو محفوظ رکھیں اور صرف معاشی حدِ نقصان پر کارروائی کریں۔ بار بار ایک ہی گروپ کی دوا کے بجائے موڈ آف ایکشن تبدیل کریں تاکہ مزاحمت کم ہو۔',
      'weeds':
          'مکئی میں اہم جڑی بوٹیاں: دھامن/کریب گراس (Digitaria)، اِچ گراس، باتھو، اور جنگلی امرانتھس ہیں۔ بوائی کے بعد پہلے 30 تا 40 دن جڑی بوٹی کنٹرول بہت اہم ہے۔ ابتدائی گوڈی کے ساتھ ضرورت کے مطابق ہربی سائیڈ مؤثر رہتی ہے۔ بچ جانے والی جڑی بوٹیوں کو پھول سے پہلے ختم کریں تاکہ بیج بینک نہ بڑھے۔',
    },
    'Wheat': {
      'cultivation':
          'زمین کی تیاری: بھربھری، ہموار اور نکاس والی بیج بستر تیار کریں۔ بوائی کا وقت: یکم نومبر تا 30 نومبر (بروقت)، تاخیر کی صورت میں دسمبر کے وسط تک۔ بیج کی شرح: بروقت کاشت میں 45 تا 50 کلو فی ایکڑ، تاخیر میں 50 تا 55 کلو فی ایکڑ۔ قطاروں کا فاصلہ: 22 تا 25 سینٹی میٹر۔ آبپاشی شیڈول: ضرورت ہو تو پری سوئنگ، پھر CRI (18 تا 25 دن)، ٹیلرنگ (40 تا 45 دن)، جوائنٹنگ/بوٹنگ (70 تا 80 دن)، اور دانہ بھرنے کے وقت (95 تا 105 دن)۔ CRI اور دانہ بھرنے کے مرحلے پر پانی کی کمی نہ آنے دیں۔',
      'fertilizer':
          'کھاد ہمیشہ مٹی کے تجزیے کے مطابق دیں۔ عمومی آبپاش علاقوں میں NPK تقریباً 48-24-16 کلو فی ایکڑ (غذائی اجزاء کی بنیاد پر) رکھا جا سکتا ہے۔ بوائی کے وقت: مکمل فاسفورس اور پوٹاش + نائٹروجن کا 1/3 حصہ۔ اوپری خوراک: پہلی آبپاشی (CRI) پر نائٹروجن کا 1/3 اور دوسری آبپاشی (ٹیلرنگ/جوائنٹنگ) پر باقی 1/3۔ زنک کی کمی والی زمین میں مقامی سفارش کے مطابق زنک سلفیٹ دیں۔ بالیوں کے بعد زیادہ نائٹروجن سے لیجنگ کا خطرہ بڑھتا ہے، اس سے بچیں۔ کمی کی علامات: نائٹروجن میں پرانے پتے پیلے اور ٹیلرز کم، فاسفورس میں جڑ کمزور، پوٹاش میں پتی نوک جلنا، زنک میں کلوروسس۔ مناسب کھاد سے ٹیلر بقا، دانہ وزن اور لیجنگ مزاحمت بہتر ہوتی ہے۔',
      'diseases':
          'اہم بیماریاں: ییلو/براؤن رسٹ، لوز سمٹ، فلیگ سمٹ اور اسپاٹ بلاچ۔ بچاؤ: مزاحم اقسام، صاف بیج، متوازن کھاد (زیادہ نائٹروجن سے گریز)، اور بروقت بوائی۔ بوائی سے پہلے بیج ٹریٹمنٹ سے بیج سے پھیلنے والی بیماری کم ہوتی ہے۔ رسٹ کے لیے ٹیلرنگ کے بعد ہفتہ وار نگرانی کریں؛ ابتدائی نشانیاں اور موافق موسم میں محکمہ زراعت کی سفارش کے مطابق مناسب فنجی سائیڈ استعمال کریں۔',
      'pests':
          'اہم کیڑے: ایفڈ، آرمی ورم/کٹ ورم (مقامی حملے)، اور خشک زمین میں دیمک۔ IPM کے تحت ہر 5 تا 7 دن بعد کھیت کا معائنہ کریں، مفید کیڑوں کو محفوظ رکھیں، غیر ضروری تیز اثر اسپرے سے بچیں، اور کھیت کے کناروں کی جڑی بوٹیاں کنٹرول کریں۔ ایفڈ کے لیے بوٹنگ سے دودھیے دانے تک خاص نگرانی کریں؛ صرف معاشی حدِ نقصان پر ضلعی سفارش کے مطابق کارروائی کریں۔ دیمک کے خطرے والے علاقوں میں مناسب نمی اور بیج ٹریٹمنٹ مفید ہے۔',
      'weeds':
          'گندم میں عام جڑی بوٹیاں: باتھو، جنگلی جئی (Avena fatua)، دمبی سٹّی (Phalaris minor)، لہلی، اور جنگلی سرسوں۔ پہلے 30 تا 45 دن کنٹرول کے لیے نہایت اہم ہیں۔ صاف بیج، لائنوں میں کاشت اور بروقت پوسٹ ایمرجنس کنٹرول اپنائیں۔ بچ جانے والی گھاس نما جڑی بوٹیوں کو بیج بنانے سے پہلے ختم کریں۔',
    },
    'Rice': {
      'cultivation':
          'کھیت کو اچھی طرح لیول کر کے پڈلنگ کریں اور مضبوط بند بنائیں۔ نرسری اور منتقلی مقامی کیلنڈر (عموماً جون تا جولائی) کے مطابق کریں۔ صحت مند پنیری مناسب عمر میں مناسب فاصلے پر لگائیں۔ منتقلی کے بعد ابتدائی کم گہرائی والا پانی رکھیں اور جہاں ممکن ہو متبادل گیلا-خشک طریقہ اپنائیں۔ ٹیلرنگ اور پینیکل مرحلے پر نمی کی کمی نہ ہونے دیں۔',
      'fertilizer':
          'فاسفورس اور پوٹاش کی مکمل مقدار ابتدائی طور پر دیں۔ نائٹروجن کو قسطوں میں دیں: ابتدائی قیام، فعال ٹیلرنگ اور پینیکل انیشی ایشن پر۔ زنک کی کمی (پتوں کا برونز ہونا/کم بڑھوتری) میں زنک سلفیٹ مقامی سفارش کے مطابق استعمال کریں۔ دیر سے زیادہ نائٹروجن لیجنگ اور کیڑوں کا دباؤ بڑھا سکتی ہے۔ کمی کی علامات: نائٹروجن میں ہلکی سبز فصل، پوٹاش میں پتی کنارے سوکھنا، زنک میں برونزنگ/سٹنٹنگ۔ مناسب کھاد سے ٹیلرنگ، پینیکل سائز، دانہ بھراؤ اور ملنگ معیار بہتر ہوتا ہے۔',
      'diseases':
          'اہم بیماریاں: بلاسٹ، بیکٹیریل لیف بلائٹ اور شیتھ بلائٹ۔ برداشت رکھنے والی اقسام، متوازن نائٹروجن اور صاف نرسری طریقہ اپنائیں۔ بہت گھنی فصل اور زیادہ نمی والے حالات بیماری بڑھاتے ہیں۔ ٹیلرنگ سے نگرانی بڑھائیں اور بیماری حد سے بڑھے تو ضلعی سفارش کے مطابق تحفظی اقدام کریں۔',
      'pests':
          'اہم کیڑے: سٹیم بورر، لیف فولڈر اور پلانٹ ہوپر۔ بورر کے لیے ڈیڈ ہارٹ/وائٹ ہیڈ، لیف فولڈر کے لیے مڑے پتے اور پلانٹ ہوپر کے لیے نچلی چھتری چیک کریں۔ غیر ضروری اسپرے سے پلانٹ ہوپر بڑھ سکتا ہے، اس لیے ضرورت کے مطابق ETL پر کارروائی کریں۔',
      'weeds':
          'دھان میں اہم جڑی بوٹیاں: جنگلی چاولی گھاس (Echinochloa)، سیجز (Cyperus) اور کچھ چوڑی پتی والی جڑی بوٹیاں ہیں۔ نرسری اور کھیت کو ابتدا سے صاف رکھیں اور منتقلی کے بعد مناسب پانی کی سطح برقرار رکھیں۔ ابتدائی گوڈی اور اسٹیل سیڈ بیڈ طریقہ دباؤ کم کرتا ہے۔',
    },
    'Potato': {
      'cultivation':
          'اکتوبر تا نومبر میں تصدیق شدہ بیج آلو مناسب فاصلہ اور کھیلیوں میں لگائیں۔ رِج کی اونچائی اور مٹی چڑھائی بروقت کریں تاکہ گانٹھیں محفوظ رہیں۔ ہلکی مگر باقاعدہ آبپاشی بہتر رہتی ہے، پانی کھڑا نہ ہونے دیں۔ گانٹھ بننے کے دوران نمی میں اچانک کمی یا زیادتی سے معیار متاثر ہوتا ہے۔',
      'fertilizer':
          'کھاد مٹی ٹیسٹ کی بنیاد پر دیں۔ زیادہ حصہ کاشت کے وقت اور باقی نائٹروجن مٹی چڑھائی کے وقت دیں۔ نامیاتی مادہ (گوبر کھاد وغیرہ) زمین کی ساخت بہتر بناتا ہے۔ کمی کی صورت میں خورد عناصر مناسب تشخیص کے بعد شامل کریں۔ بہت دیر سے زیادہ نائٹروجن گانٹھ کے معیار کو متاثر کر سکتی ہے۔ کمی کی علامات: نائٹروجن میں پتے ہلکے، پوٹاش میں کنارے جلنا اور ٹیوبر بھراؤ کم، بوران/کیلشیم کمی میں اندرونی نقص۔ مناسب کھاد سے ٹیوبر سائز یکسانیت، ذخیرہ معیار اور مارکیٹ ویلیو بہتر ہوتی ہے۔',
      'diseases':
          'اہم بیماریاں: لیٹ بلائٹ، ارلی بلائٹ اور بعض علاقوں میں بیکٹیریل ولٹ۔ صاف بیج، فصلوں کی گردش اور بیماری سے پاک پانی استعمال کریں۔ ٹھنڈے اور مرطوب موسم میں حفاظتی نگرانی جلد شروع کریں۔ شدید متاثر پودے نکالیں اور موسمی خطرے کے مطابق حفاظتی پروگرام اپنائیں۔',
      'pests':
          'اہم کیڑے: ایفڈ اور پوٹیٹو ٹیوبر مَتھ۔ ایفڈ نگرانی ابتدائی چھتری سے شروع کریں کیونکہ وائرس کا خطرہ بڑھتا ہے۔ رِج برقرار رکھیں تاکہ گانٹھیں باہر نہ آئیں اور مَتھ کا حملہ کم ہو۔ صفائی، بروقت کٹائی اور ذخیرہ سے پہلے چھانٹی ضروری ہے۔',
      'weeds':
          'آلو میں عام جڑی بوٹیاں: باتھو، لہلی، پوآ اور امرانتھس۔ چھتری بند ہونے سے پہلے ابتدائی کنٹرول سب سے مؤثر رہتا ہے۔ پری ایمرجنس ہربی سائیڈ (سفارش کے مطابق) کے ساتھ 1 تا 2 گوڈیاں بہتر نتائج دیتی ہیں۔ کھیلیاں صاف رکھیں تاکہ گانٹھ کی بڑھوتری متاثر نہ ہو۔',
    },
    'Sugarcane': {
      'cultivation':
          'صحت مند اور بیماری سے پاک گنڈی استعمال کریں۔ قطار/خندق میں مناسب فاصلے سے کاشت کریں اور نکاس کا خاص خیال رکھیں۔ ابتدائی 90 تا 120 دن جڑی بوٹی کنٹرول اور مناسب نمی برقرار رکھیں۔ ریٹون فصل میں اسٹبل شیوِنگ، گیپ فلنگ اور ابتدائی آبپاشی/غذائیت اہم ہے۔',
      'fertilizer':
          'مٹی کے تجزیے کے مطابق کھاد دیں۔ فاسفورس/پوٹاش کا بڑا حصہ ابتدا میں اور نائٹروجن فعال بڑھوتری میں قسطوں سے دیں۔ جہاں دستیاب ہو نامیاتی مادہ شامل کریں تاکہ زمین بہتر رہے۔ ریٹون میں پہلی آبپاشی کے ساتھ ابتدائی نائٹروجن خصوصی اہمیت رکھتی ہے۔ کمی کی علامات: نائٹروجن میں ہلکے پتے اور باریک گنا، پوٹاش میں نوک سے سوکھاؤ، زنک/آئرن میں پیلاہٹ۔ مناسب کھاد سے گنے کی موٹائی، ٹیلرنگ، رس معیار اور شوگر ریکوری بہتر ہوتی ہے۔',
      'diseases':
          'اہم بیماریاں: ریڈ راٹ، سمٹ اور ولٹ۔ مزاحم اقسام، صحت مند بیج اور متاثرہ گنڈی سے گریز بنیادی بچاؤ ہے۔ متاثرہ گچھے فوری الگ کریں اور بیمار کھیت سے بیج منتقل نہ کریں۔ مسلسل دباؤ والے علاقوں میں فصلوں کی گردش مفید رہتی ہے۔',
      'pests':
          'اہم کیڑے: ارلی شوٹ بورر اور ٹاپ بورر۔ ڈیڈ ہارٹ اور بورنگ علامات کی باقاعدہ نگرانی کریں۔ حیاتیاتی کنٹرول اور موزوں وقت پر کارروائی بہتر نتائج دیتی ہے۔ ایک ہی دوا بار بار استعمال نہ کریں۔',
      'weeds':
          'گنے میں اہم جڑی بوٹیاں: دوب گھاس، موتھا (Cyperus)، کانگریس گھاس اور دیگر چوڑی پتی سالانہ جڑی بوٹیاں۔ پہلے 90 تا 120 دن کنٹرول کے لیے فیصلہ کن ہیں۔ ٹرش ملچ، مٹی چڑھائی اور مربوط ہربی سائیڈ + گوڈی پروگرام اپنائیں۔ قطاروں کے درمیان صفائی رکھیں۔',
    },
    'Cotton': {
      'cultivation':
          'بوائی تجویز کردہ وقت (عموماً مئی تا جون) میں منظور شدہ بیج سے کریں اور پودوں کی مناسب تعداد برقرار رکھیں۔ کھیت کے کناروں کی صفائی اور متبادل میزبان جڑی بوٹیوں کا خاتمہ کریں۔ اسکوائر/پھول/بول مرحلے پر پانی کی کمی سے بچائیں۔ بروقت گوڈی اور متوازن بڑھوتری فصل کی صحت بہتر کرتی ہے۔',
      'fertilizer':
          'کھاد مٹی ٹیسٹ کی بنیاد پر دیں۔ فاسفورس/پوٹاش زیادہ تر بوائی پر اور نائٹروجن 2 تا 3 قسطوں میں پھول/بول مرحلے تک دیں۔ زیادہ پیداواری کھیتوں میں پوٹاش اور بوران کی کمی پر نظر رکھیں۔ زیادہ نائٹروجن سے فصل ضرورت سے زیادہ نرم ہو کر کیڑوں کے لیے حساس ہو سکتی ہے۔ کمی کی علامات: نائٹروجن میں کمزور بڑھوتری، پوٹاش میں پتی کنارے جلنا اور کم بول فلنگ، بوران میں پھول/بول گرنا۔ مناسب کھاد سے بول رٹنشن، فائبر معیار اور بروقت پکائی بہتر ہوتی ہے۔',
      'diseases':
          'اہم مسئلہ کاٹن لیف کرل وائرس ہے، جبکہ سازگار موسم میں فنگسی دھبے/سڑن بھی آ سکتی ہے۔ وائرس کے لیے برداشت رکھنے والی اقسام اور سفید مکھی کنٹرول بنیادی حکمتِ عملی ہے۔ بہت متاثر پودے ابتدائی مرحلے میں الگ کرنا مفید رہتا ہے۔ متوازن کھاد اور صفائی سے بیماری کا دباؤ کم ہوتا ہے۔',
      'pests':
          'اہم کیڑے: سفید مکھی، جیسڈ، تھرپس اور گلابی سنڈی۔ حساس مدت میں ہفتے میں دو بار نگرانی کریں اور گلابی سنڈی کے لیے فیرومون ٹریپ لگائیں۔ IPM اپنائیں اور صرف ETL پر سپرے کریں۔ ایک ہی گروپ کی دوا کے مسلسل استعمال سے مزاحمت بڑھتی ہے، اس لیے روٹیشن کریں۔',
      'weeds':
          'کپاس میں اہم جڑی بوٹیاں: اِٹسِٹ/ٹری اینتھیما، دوب گھاس، جنگلی بوٹیاں اور امرانتھس۔ پہلے 45 تا 60 دن فصل کو جڑی بوٹیوں سے پاک رکھنا ضروری ہے۔ بروقت بین السطری گوڈی اور مناسب پری/پوسٹ ایمرجنس ہربی سائیڈ بہترین رہتے ہیں۔ کناروں کی جڑی بوٹیاں ختم کریں تاکہ سفید مکھی کے میزبان کم ہوں۔',
    },
    'Gram': {
      'cultivation':
          'چنے کی کاشت ربیع میں اکتوبر تا نومبر مناسب ہے۔ اچھے نکاس والی میرا/ریتلی میرا زمین بہتر رہتی ہے۔ بیج ٹریٹمنٹ اور مناسب قطار فاصلہ فصل کے قیام میں مدد دیتا ہے۔ عام طور پر محدود آبپاشی کافی ہے، مگر خشک سالی میں پھول اور پھلی مرحلے پر ایک بچاؤ آبپاشی فائدہ دیتی ہے۔',
      'fertilizer':
          'چنے میں فاسفورس جڑ اور گانٹھ بننے کے لیے بہت اہم ہے، اس لیے بیسل خوراک مٹی ٹیسٹ کے مطابق دیں۔ کم زرخیز زمین میں ابتدائی کم نائٹروجن مفید ہو سکتی ہے۔ سلفر/خرد عناصر کمی کی صورت میں شامل کریں۔ زیادہ نائٹروجن سے موثر گانٹھ بننا متاثر ہو سکتا ہے۔ کمی کی علامات: فاسفورس میں کمزور جڑ اور گانٹھیں، سلفر میں نئی پتیاں پیلی، زنک/آئرن میں کلوروسس۔ مناسب کھاد سے گانٹھ بناؤ، پھلی سیٹ اور دانہ وزن بہتر ہوتا ہے۔',
      'diseases':
          'اہم بیماریاں: ایسکوکائٹا بلائٹ اور ولٹ کمپلیکس۔ مزاحم اقسام، صاف بیج اور بیج ٹریٹمنٹ بنیادی بچاؤ ہیں۔ پانی کھڑا ہونے سے بچیں اور اناج کے ساتھ فصل گردش اپنائیں۔ ٹھنڈے مرطوب حالات میں نگرانی بڑھا کر مقامی ہدایات کے مطابق تحفظ کریں۔',
      'pests':
          'اہم کیڑا پوڈ بورر ہے۔ پھول سے پھلی بننے کے مرحلے میں باقاعدہ اسکاؤٹنگ اور فیرومون ٹریپ مفید ہیں۔ قدرتی دشمنوں کو محفوظ رکھیں اور ETL پر ہی سپرے کریں۔ بار بار مداخلت کی صورت میں مختلف گروپ کی دوا استعمال کریں۔',
      'weeds':
          'چنے میں عام جڑی بوٹیاں: باتھو، جنگلی جئی اور ربیع کی چوڑی پتی جڑی بوٹیاں۔ ابتدائی مقابلہ شاخ بندی اور پھلی سیٹ کو کم کرتا ہے۔ ایک ابتدائی گوڈی/انٹرکلچر کے ساتھ ضرورت کے مطابق ہربی سائیڈ پیداوار بچاتی ہے۔ مستقل جڑی بوٹیوں کو بیج بنانے نہ دیں۔',
    },
    'Mustard': {
      'cultivation':
          'سرسوں کی بوائی اکتوبر تا نومبر میں نرم اور ہموار بیج بستر پر کریں۔ مناسب قطار فاصلہ اور ابتدائی جڑی بوٹی کنٹرول ضروری ہے۔ عموماً 1 تا 2 آبپاشیاں کافی رہتی ہیں، خاص طور پر شاخ اور پھول/پھلی مراحل پر۔ پھول کے وقت نمی کی کمی بیج سیٹ کو متاثر کرتی ہے۔',
      'fertilizer':
          'متوازن این پی کے کے ساتھ سلفر سرسوں میں خاص اہمیت رکھتا ہے۔ بیسل فاسفورس/پوٹاش اور ضرورت کے مطابق تقسیم شدہ نائٹروجن دیں۔ شناخت شدہ کمی پر خورد عناصر شامل کریں۔ مناسب غذائیت سے پھلیوں کی تشکیل اور دانہ بھراؤ بہتر ہوتا ہے۔ کمی کی علامات: سلفر میں نئی پتیاں ہلکی اور آئل کم، نائٹروجن میں عمومی پیلاہٹ، بوران میں پھول/پھلی مسئلہ۔ مناسب کھاد سے آئل فیصد، سیڈ فلنگ اور پودوں کی طاقت بڑھتی ہے۔',
      'diseases':
          'اہم بیماریاں: الٹرنیریا بلائٹ اور وائٹ رسٹ۔ برداشت رکھنے والی اقسام، باقیات کا مناسب انتظام اور بروقت بوائی سے دباؤ کم ہوتا ہے۔ بہت گھنی فصل اور زیادہ دیر پتوں پر نمی بیماری بڑھاتی ہے۔ باقاعدہ نگرانی اور خطرے کی صورت میں محکمہ زراعت کی سفارش پر عمل کریں۔',
      'pests':
          'سرسوں میں ایفڈ بنیادی کیڑا ہے؛ بعض علاقوں میں پینٹڈ بگ بھی آتا ہے۔ نرم شاخوں اور پھولوں کی باقاعدہ جانچ کریں۔ مفید کیڑوں کے تحفظ کے ساتھ ضرورت پر ہی کارروائی کریں۔ معاشی حدِ نقصان پر مناسب دوا اور حفاظتی وقفے کی پابندی کریں۔',
      'weeds':
          'سرسوں میں اہم جڑی بوٹیاں: باتھو، لہلی، جنگلی جئی اور رضاکار جنگلی سرسوں۔ پہلے 30 تا 40 دن کنٹرول کے لیے اہم ہیں۔ بروقت گوڈی اور ضرورت پر منتخب ہربی سائیڈ فصل کو مضبوط کرتی ہے۔ کھیت کے کنارے صاف رکھیں تاکہ دوبارہ پھیلاؤ نہ ہو۔',
    },
    'Bajra': {
      'cultivation':
          'باجرہ خریف فصل ہے اور ہلکی تا درمیانی زمین میں بہتر رہتا ہے۔ بارش شروع ہوتے ہی مناسب فاصلے سے بوائی کریں تاکہ جڑیں اور ہوا کی آمدورفت بہتر رہے۔ عام طور پر بارانی حالت میں کامیاب رہتا ہے، مگر خشک سالی میں پھول کے وقت ایک بچاؤ آبپاشی مفید ہے۔ ابتدائی مرحلے میں جڑی بوٹی کنٹرول ضروری ہے۔',
      'fertilizer':
          'کم لاگت مگر متوازن غذائیت اپنائیں، مٹی کی زرخیزی کے مطابق فاسفورس بوائی پر اور نائٹروجن مناسب نمی میں قسطوں سے دیں۔ کمزور زمین میں نامیاتی مادہ شامل کرنے سے نمی اور غذائیت کا استعمال بہتر ہوتا ہے۔ نمی کی کمی میں زیادہ کھاد سے گریز کریں۔ کمی کی علامات: نائٹروجن میں پودے پیلے اور کمزور، فاسفورس میں ابتدائی بڑھوتری سست، پوٹاش میں کنارے سوکھنا۔ مناسب کھاد سے خشک سالی برداشت، بالی بناؤ اور دانہ وزن بہتر ہوتا ہے۔',
      'diseases':
          'اہم بیماریاں: ڈاؤنی ملی ڈیو اور ارگٹ۔ مزاحم اقسام، صاف بیج اور بیمار بالیوں کو ہٹانا مفید ہے۔ بیمار کھیت کا بیج اگلے سال استعمال نہ کریں۔ فصل گردش اور صفائی سے بیماری کا منبع کم ہوتا ہے۔',
      'pests':
          'اہم کیڑے: شوٹ فلائی اور سٹیم بورر۔ ننھے پودوں میں ڈیڈ ہارٹ علامات دیکھیں اور ٹیلرنگ کے بعد نگرانی جاری رکھیں۔ بروقت بوائی سے کئی بار شدید حملہ کم ہو جاتا ہے۔ ETL کے مطابق ضلعی سفارش پر کارروائی کریں۔',
      'weeds':
          'باجرہ میں عام جڑی بوٹیاں: دوب گھاس، موتھا اور امرانتھس/ٹری اینتھیما جیسی سالانہ چوڑی پتی جڑی بوٹیاں۔ پہلی بارش کے بعد اگاؤ کو جلد کنٹرول کرنا ضروری ہے۔ بارانی حالات میں ایک ابتدائی گوڈی بہت فائدہ دیتی ہے۔ جڑی بوٹیوں کو پھولنے سے پہلے ختم کریں۔',
    },
    'Barley': {
      'cultivation':
          'جو کی بروقت ربیع بوائی اچھی پیداوار دیتی ہے۔ اچھی طرح تیار اور نکاس والی زمین میں قطاروں سے بوائی کریں۔ جو کو عموماً گندم سے کم آبپاشی درکار ہوتی ہے، مگر ٹیلرنگ اور دانہ بھرنے کے مرحلے پر نمی اہم ہے۔ کھیت میں پانی کھڑا نہ ہونے دیں۔',
      'fertilizer':
          'کھاد مٹی ٹیسٹ کے مطابق دیں؛ بیسل فاسفورس اور ضرورت کے مطابق نائٹروجن قسطوں میں دیں۔ کمزور زمین میں نامیاتی مادہ شامل کرنا مفید ہے۔ بہت دیر سے زیادہ نائٹروجن لیجنگ اور معیار میں کمی کا باعث بن سکتی ہے۔ ہدف پیداوار کے مطابق متوازن غذائیت رکھیں۔ کمی کی علامات: نائٹروجن میں پرانے پتے پیلے، فاسفورس میں جڑ کمزور، پوٹاش میں پتی نوک جلنا، زنک میں کلوروسس۔ مناسب کھاد سے ٹیلر طاقت، دانے کی بھرپوریت اور معیار مستحکم رہتا ہے۔',
      'diseases':
          'اہم بیماریاں: لوز سمٹ، رسٹ اور لیف اسٹرائپ۔ بیج ٹریٹمنٹ اور مزاحم اقسام بنیادی حکمتِ عملی ہیں۔ فصل گردش اور باقیات مینجمنٹ سے بیماری کم ہوتی ہے۔ ابتدائی سبز مرحلے سے نگرانی کریں اور ضرورت پر مقامی سفارشات پر عمل کریں۔',
      'pests':
          'اہم کیڑے: ایفڈ اور بعض علاقوں میں آرمی ورم۔ پتوں کی نچلی سطح اور بالی نکلنے کے وقت خاص نگرانی کریں۔ قدرتی دشمنوں کا تحفظ کریں اور غیر ضروری اسپرے سے بچیں۔ ETL پر کارروائی کرتے وقت حفاظتی وقفوں کی پابندی کریں۔',
      'weeds':
          'جو میں جڑی بوٹیاں عموماً گندم جیسی ہوتی ہیں: فیلیریس مائنر، جنگلی جئی، باتھو اور دیگر ربیع جڑی بوٹیاں۔ ابتدائی مرحلے کا مقابلہ سب سے زیادہ نقصان دہ ہوتا ہے۔ لائنوں میں کاشت، صاف بیج اور بروقت پوسٹ ایمرجنس کنٹرول اپنائیں۔ بچ جانے والی جڑی بوٹیاں بیج جھڑنے سے پہلے نکالیں۔',
    },
    'Onion': {
      'cultivation':
          'گہری، اچھی نکاسی والی میرا زمین (پی ایچ 6.0-7.0)۔ نرسری اکتوبر-نومبر، منتقلی دسمبر-جنوری (ربیع)۔ قطار وقفہ 15×10 سینٹی میٹر۔ پیاز بننے کے وقت آبپاشی اہم۔ کٹائی سے 2 ہفتے پہلے آبپاشی کم کریں تاکہ چھلکا اور ذخیرہ کاری بہتر ہو۔',
      'fertilizer':
          'این پی کے تقریباً 25-20-20 فی ایکڑ۔ سلفر 10-15 کلو فی ایکڑ سے پیاز کا ذائقہ اور معیار بہتر ہوتا ہے۔ نائٹروجن تین قسطوں میں دیں (منتقلی، 30 دن، پیاز بننے پر)۔ زیادہ نائٹروجن پختگی دیر کرتی ہے۔',
      'diseases':
          'پرپل بلاچ، ڈاؤنی ملی ڈیو، بیسل راٹ۔ مناسب فاصلہ رکھیں، اوپر سے پانی نہ دیں، موڈ تبدیل کر کے فنجی سائیڈ استعمال کریں۔',
      'pests':
          'تھرپس سب سے زیادہ نقصاندہ — پتوں پر چاندی رنگ کے نشانات۔ ہفتہ وار نگرانی کریں۔ پیلے چپچپے ٹریپ لگائیں اور ETL پر سپرے کریں۔',
      'weeds':
          'پہلے 45 دن کلین کلچر اہم۔ پنڈی میتھالِن (پری ایمرجنس) اور ہاتھ گوڈی مؤثر ہے۔ ملچ نمی برقرار رکھتا اور جڑی بوٹیاں کم کرتا ہے۔',
    },
    'Tomato': {
      'cultivation':
          'نرسری ستمبر-اکتوبر (ربیع) یا جنوری-فروری (بہاری)۔ 25-30 دن کی پنیری منتقل کریں۔ قطار وقفہ 60×45 سینٹی میٹر۔ غیر محدود اقسام کو سہارا دیں۔ ڈرپ یا کھال آبپاشی بہتر؛ پتوں پر پانی نہ دیں۔ شدید گرمی (38+ ڈگری) یا سردی پھل لگانے میں رکاوٹ بنتی ہے۔',
      'fertilizer':
          'این پی کے تقریباً 35-25-30 فی ایکڑ۔ پوٹاشیم پھل کے معیار کے لیے ضروری۔ کیلشیم (جپسم یا فولیئر) بلسم اینڈ راٹ روکتا ہے۔ نائٹروجن 4 قسطوں میں (منتقلی، پھول، ابتدائی پھل، درمیانی پھل)۔',
      'diseases':
          'ارلی بلائٹ، لیٹ بلائٹ، بیکٹیریل ولٹ، لیف کرل وائرس۔ مزاحم اقسام، متاثرہ پودے فوری ہٹائیں، فنجی سائیڈ کا چکر بدلیں، سفید مکھی وائرس پھیلاؤ روکیں۔',
      'pests':
          'سفید مکھی (وائرس محرک)، پھل بیدھنے والا کیڑا، مکڑی، ایفڈ۔ ہفتہ میں دو بار نگرانی۔ فیرومون ٹریپ، ریفلیکٹو ملچ، صرف ETL پر سپرے۔',
      'weeds':
          'کالی پلاسٹک ملچ انتہائی مؤثر — جڑی بوٹیاں دباتی اور نمی بچاتی ہے۔ بغیر ملچ: پری ایمرجنس ہربی سائیڈ اور 2 ہاتھ گوڈیاں۔ قطاروں کے درمیان زمین ڈھیلی رکھیں۔',
    },
    'Chilli': {
      'cultivation':
          'نرسری ستمبر-اکتوبر، منتقلی نومبر-دسمبر۔ قطار وقفہ 45×30-45 سینٹی میٹر۔ گرمی اور نمی پھول گراتی ہے؛ پالے سے بچائیں۔ اچھی نکاسی Phytophthora کا خطرہ کم کرتی ہے۔ پہلی توڑائی 60-90 دن بعد؛ کئی مرتبہ توڑائی ہوتی ہے۔',
      'fertilizer':
          'این پی کے تقریباً 20-20-15 فی ایکڑ۔ پھول پر بورون فولیئر فائدہ مند۔ نائٹروجن زیادہ نہ دیں — پھل دیر سے آتا اور بیماری بڑھتی ہے۔',
      'diseases':
          'لیف کرل وائرس (سفید مکھی سے)، اینتھراکنوز، ڈیمپنگ آف۔ مستند بیج، جال دار نرسری، وائرس لگے پودے فوری اکھاڑیں۔',
      'pests':
          'تھرپس، مکڑی، سفید مکھی (وائرس محرک)۔ چپچپے ٹریپ، ریفلیکٹو ملچ، صرف ETL پر سپرے۔',
      'weeds':
          'ملچ فلم انتہائی مؤثر۔ پنڈی میتھالِن اور 1-2 ہاتھ گوڈیاں۔ پہلے 40 دن کی کلین کلچر ضروری۔',
    },
    'Brinjal': {
      'cultivation':
          'منتقلی ستمبر-اکتوبر یا فروری-مارچ۔ قطار وقفہ 60-75×45-60 سینٹی میٹر۔ معتدل موسم میں سال بھر کاشت ہو سکتی ہے۔ پرانی شاخیں ہلکی کاٹنے سے فصل کی عمر بڑھتی ہے۔ پانی کھڑا نہ ہونے دیں۔',
      'fertilizer':
          'این پی کے تقریباً 30-20-15 فی ایکڑ۔ نائٹروجن 3 قسطوں میں۔ پھل مرحلے پر پوٹاشیم اہم۔ ملچ بیماریوں کا دباؤ کم کرتا ہے۔',
      'diseases':
          'فوموپسس بلائٹ، بیکٹیریل ولٹ، لِٹل لیف (فائٹوپلازما)۔ متاثرہ پودے فوری ہٹائیں؛ صحت مند پنیری استعمال کریں، فصل تبدیل کریں۔',
      'pests':
          'بینگن کی ٹہنی اور پھل بیدھنے والا کیڑا (BSFB) — اہم ترین کیڑا۔ فیرومون ٹریپ ضروری۔ متاثرہ ٹہنیاں/پھل نکالیں، ETL پر سپرے۔ گرم خشک موسم میں مکڑی۔',
      'weeds':
          'تنکے یا پلاسٹک ملچ سے جڑی بوٹیاں خاصی کم ہوتی ہیں۔ پہلے 30 دن میں 1-2 ہاتھ گوڈیاں کافی ہیں۔',
    },
    // پھل
    'Mango': {
      'cultivation':
          'باغ لگانے کا فاصلہ 8-10×10 میٹر۔ مشہور اقسام: سندھڑی، چونسہ، انور ریٹول، فجری، لنگڑا۔ پھول جنوری-فروری، پھل مئی-جولائی۔ کلیاں نکلنے، پھل لگنے اور بڑھوتری کے وقت (جنوری-مئی) آبپاشی اہم۔',
      'fertilizer':
          'بالغ درخت فی سال: N-P₂O₅-K₂O 750-300-500 گرام، جنوری، اپریل، اگست میں دیں۔ زنک فولیئر (ZnSO₄ 0.5%) اور بورون کلیوں پر پھل بہتر کریں۔ کھاد کے ساتھ گوبر کھاد بھی دیں۔',
      'diseases':
          'پھول پر پاؤڈری ملی ڈیو؛ پھل پر اینتھراکنوز؛ کیڑوں کے شہد سے سوٹی مولڈ۔ ابتدائی کلیوں پر وطابل سلفر یا مائیکلو بیوٹینِل؛ مانسون سے پہلے کاپر فنگی سائیڈ۔',
      'pests':
          'آم کا ہاپر، میلی بگ، پھل مکھی (Bactrocera)، پتی لپیٹنے والا کیڑا۔ پھول پر اسپرے؛ باغ میں بیتھر اسٹیشن؛ میلی بگ کے لیے سردیوں میں تیل والا اسپرے۔',
      'weeds':
          'چھتری تلے ملچ سے نمی اور جڑی بوٹیاں دونوں قابو رہتی ہیں۔ قطاروں میں کم جوتائی۔',
    },
    'Citrus': {
      'cultivation':
          'کنو، مالٹا، گریپ فروٹ۔ فاصلہ 6×6 میٹر۔ پھول فروری-مارچ، پھل دسمبر-فروری۔ موسم گرما میں ماہانہ اور سردی میں 6-8 ہفتے بعد آبپاشی۔ پھل بڑھوتری اور کٹائی سے پہلے پانی کی کمی نہ ہو۔',
      'fertilizer':
          'بالغ درخت فی سال: N-P₂O₅-K₂O 400-200-300 گرام، فروری، مئی، اگست میں۔ زنک، آئرن (کیلیٹ) اور بورون فولیئر اسپرے پھل معیار بہتر کریں۔ اگست میں زیادہ نائٹروجن نہ دیں — اگلے سال کے پھول کم ہوتے ہیں۔',
      'diseases':
          'سٹرس کینکر، گریسی اسپاٹ، گموسِس۔ کاپر اسپرے 60 دن بعد؛ نکاسی اور چھال کی حفاظت۔ HLB (سبزیاؤ/گرینِنگ) لاعلاج — سِیلا کیڑے کو سختی سے قابو رکھیں۔',
      'pests':
          'سٹرس سِیلا (HLB محرک)، ریڈ اسپائیڈر مائٹ، میلی بگ، لیف مائنر۔ سِیلا کا قابو لازمی۔ گرم خشک موسم میں مائٹ کی دوا۔',
      'weeds':
          'ہر درخت کے نیچے 1 میٹر وقت صاف۔ ملچ یا ہربی سائیڈ؛ قطاروں میں کنٹرولڈ گھاس۔ سطحی جڑوں کے قریب گہری جوتائی نہ کریں۔',
    },
    'Guava': {
      'cultivation':
          'صفیدہ، گولا، سراحی اقسام۔ فاصلہ 6×6 میٹر۔ سال میں دو موسم: سردی (اکتوبر-جنوری) اور گرمی (جون-اگست)۔ برداشت کے بعد ہلکی کانٹ چھانٹ نئی پیداوار والی ٹہنیاں پیدا کرتی ہے۔ گرمی میں 7-10 دن اور سردی میں 15-20 دن بعد آبپاشی۔',
      'fertilizer':
          'درخت فی سال: N-P₂O₅-K₂O 500-250-400 گرام، 2-3 قسطوں میں۔ گوبر کھاد 20-30 کلوگرام فی درخت پھل معیار بہتر کرتی ہے۔ زنک اور بورون فولیئر فائدہ مند۔',
      'diseases':
          'مرجھاؤ (فوزیریم)، اینتھراکنوز، الجل اسپاٹ۔ متاثرہ درخت کاٹیں؛ نکاسی بہتر کریں؛ پھل پر کاپر فنگی سائیڈ۔',
      'pests':
          'پھل مکھی، میلی بگ، گواوا وائٹ فلائی، چھال کھانے والا کیڑا۔ بیتھر اسٹیشن؛ تازہ مارکیٹ کے لیے پھل تھیلوں میں بند کریں؛ چھال کیڑے میں سوراخ میں دوا ڈالیں۔',
      'weeds':
          'درخت کے نیچے ملچ؛ قطاروں میں کم گہری جوتائی۔ باغ کے منڈوں پر ہربی سائیڈ۔',
    },
    'Banana': {
      'cultivation':
          'بصرائی بونی (سندھ)، لکاتان، روبسٹا۔ فروری-مارچ یا ستمبر-اکتوبر کاشت کریں۔ تلواری پنیری استعمال کریں؛ اضافی پنیریاں نکالیں۔ فاصلہ 1.8×1.8 میٹر۔ گرمی میں ہفتہ وار آبپاشی۔ بوائی کے 9-12 ماہ بعد برداشت؛ گچھا وزن 20-35 کلوگرام۔',
      'fertilizer':
          'زیادہ غذائی ضروریات۔ N-P-K تقریباً 100-30-200 گرام فی پودا فی سال۔ نائٹروجن 4-5 ماہانہ قسطوں میں۔ پوٹاشیم پیداوار کا اہم عنصر ہے۔ گچھے کے معیار کے لیے بورون ضروری۔ نئے پتے پیلے (N)، جامنی (P)، پتی کنارے جلنا (K) — کمی کی علامات۔',
      'diseases':
          'پاناما ولٹ (لاعلاج؛ مزاحم اقسام کاشت کریں)۔ سیگاٹوکا: پرانے پتے ہٹائیں اور کاپر سپرے کریں۔ بنچی ٹاپ وائرس: متاثرہ پودے فوری اکھاڑیں؛ صرف مستند پنیری استعمال کریں۔',
      'pests':
          'کیلے کا بیدھنی کیڑا: تنہ کاٹیں اور پھندے لگائیں۔ نیماٹوڈ جڑ خراب کرتے ہیں — خطرناک زمین میں نیماٹی سائیڈ دیں۔ تھرپس پھل پر کاسمیٹک نقصان — بیگنگ سے بازار معیار بہتر ہوتا ہے۔',
      'weeds':
          'تین چار ماہ بعد سایہ جڑی بوٹیاں کم کرتا ہے۔ قیام کے دوران ملچ اور ہاتھ گوڈی پہلے 2 ماہ ضروری ہے۔',
    },
  },
};

const Map<String, String> pesticideFormulasByCropEnglish = {
  'Maize':
      'Stem borer/Fall armyworm: Chlorantraniliprole 18.5 SC, Emamectin benzoate 5 SG, Spinetoram 11.7 SC. Sucking pests where present: Imidacloprid 17.8 SL.',
  'Wheat':
      'Aphids: Imidacloprid 17.8 SL or Thiamethoxam 25 WG. Armyworm/Cutworm outbreaks: Emamectin benzoate 5 SG or Lambda-cyhalothrin 2.5 EC.',
  'Rice':
      'Stem borer/Leaf folder: Chlorantraniliprole 18.5 SC or Flubendiamide 20 WG. Planthoppers: Buprofezin 25 SC or Pymetrozine 50 WG.',
  'Potato':
      'Aphids: Imidacloprid 17.8 SL. Tuber moth/caterpillars: Emamectin benzoate 5 SG or Chlorantraniliprole 18.5 SC.',
  'Sugarcane':
      'Borers: Chlorantraniliprole 18.5 SC or Fipronil 5 SC. Early shoot borer windows: Cartap hydrochloride 50 SP (as locally advised).',
  'Cotton':
      'Whitefly/Jassid/Thrips: Imidacloprid 17.8 SL, Acetamiprid 20 SP, or Thiamethoxam 25 WG. Pink bollworm: Emamectin benzoate 5 SG or Chlorantraniliprole 18.5 SC.',
  'Gram':
      'Pod borer: Emamectin benzoate 5 SG, Chlorantraniliprole 18.5 SC, or Spinosad 45 SC.',
  'Mustard':
      'Aphids: Thiamethoxam 25 WG, Imidacloprid 17.8 SL, or Acetamiprid 20 SP.',
  'Bajra':
      'Shoot fly/Stem borer: Emamectin benzoate 5 SG, Chlorantraniliprole 18.5 SC, or Lambda-cyhalothrin 2.5 EC.',
  'Barley':
      'Aphids/armyworm risk: Thiamethoxam 25 WG or Imidacloprid 17.8 SL; caterpillar outbreaks: Emamectin benzoate 5 SG.',
};

const Map<String, String> deficiencySymptomsByCropEnglish = {
  'Maize':
      'N: older leaves yellow; P: stunting with purplish tinge; K: leaf-edge scorching; Zn: pale striping in young leaves.',
  'Wheat':
      'N: pale older leaves and weak tillers; P: poor root growth and delayed maturity; K: tip/margin burn; Zn: chlorotic bands.',
  'Rice':
      'N: overall pale green canopy; P: slow growth; K: marginal drying; Zn: bronzing/stunting in young plants.',
  'Potato':
      'N: pale foliage; P: weak canopy growth; K: margin scorch and poor bulking; B/Ca: internal defects in tubers.',
  'Sugarcane':
      'N: light green leaves and thin canes; P: slow establishment; K: tip burn/dry margins; Zn/Fe: chlorosis in young leaves.',
  'Cotton':
      'N: weak pale growth; K: edge scorch and poor boll fill; B: shedding/malformed bolls; Mg: interveinal yellowing on older leaves.',
  'Gram':
      'P: weak roots and poor nodulation; S: yellow younger leaves; Zn/Fe: chlorosis; B: flower/pod setting issues.',
  'Mustard':
      'S: pale young leaves and reduced oil quality; N: general chlorosis; B: poor siliqua formation; K: weak stems.',
  'Bajra':
      'N: stunted pale plants; P: slow early growth; K: edge drying under stress; Zn: chlorotic striping where deficient.',
  'Barley':
      'N: yellowing older leaves; P: weak roots/tillering; K: tip burn; Zn: interveinal chlorosis.',
};

const Map<String, String> diseaseFormulasByCropEnglish = {
  'Maize':
      'Preventive: Mancozeb 75 WP; seed/early protection with Metalaxyl + Mancozeb 72 WP in downy mildew-prone fields. Curative/active spread: Azoxystrobin 23 SC or Propiconazole 25 EC based on diagnosis and stage.',
  'Wheat':
      'Preventive: Carboxin + Thiram seed treatment (smut), early rust watch with Propiconazole 25 EC in risk weather. Curative/active spread: Tebuconazole 25 EC or Azoxystrobin + Difenoconazole premix at first visible rust/foliar symptoms.',
  'Rice':
      'Preventive: Tricyclazole 75 WP (blast-prone windows) and balanced nitrogen; keep Validamycin 3 L plan for sheath blight risk. Curative/active spread: Tricyclazole 75 WP (blast), Validamycin 3 L (sheath blight), Copper hydroxide 77 WP for bacterial pressure as advised.',
  'Potato':
      'Preventive: Mancozeb 75 WP before blight weather; start early under cool-humid forecast. Curative/active spread: Cymoxanil + Mancozeb or Metalaxyl + Mancozeb when lesions are detected and disease pressure rises.',
  'Sugarcane':
      'Preventive: Carbendazim 50 WP sett treatment and strict sanitation for red rot/smut-prone fields. Curative/active spread: Copper oxychloride 50 WP for localized lesion management, integrated with rogueing and clean seed strategy.',
  'Cotton':
      'Preventive: Copper oxychloride 50 WP or Carbendazim 50 WP for fungal leaf spot risk where weather favors disease. Curative/active spread: Azoxystrobin 23 SC or Carbendazim + protectant mix based on symptom profile. Note: viral complex control is vector-focused, not curative fungicide spray.',
  'Gram':
      'Preventive: Thiram/Carbendazim seed treatment and early Chlorothalonil 75 WP in blight-conducive weather. Curative/active spread: Carbendazim + Mancozeb mix or Chlorothalonil 75 WP as per disease intensity and local advisory.',
  'Mustard':
      'Preventive: Mancozeb 75 WP in Alternaria/white rust-prone conditions. Curative/active spread: Metalaxyl + Mancozeb 72 WP (white rust pressure) or Propiconazole 25 EC (Alternaria-led symptoms).',
  'Bajra':
      'Preventive: Metalaxyl + Mancozeb 72 WP and systemic fungicidal seed treatment in downy mildew-prone zones. Curative/active spread: follow Metalaxyl + Mancozeb program at first signs with local extension schedule.',
  'Barley':
      'Preventive: Carboxin + Thiram seed treatment and early rust surveillance. Curative/active spread: Propiconazole 25 EC or Tebuconazole 25 EC for foliar rust/stripe symptoms as per advisory.',
};

const Map<String, String> weedicideFormulasByCropEnglish = {
  'Maize':
      'Pre-emergence: Atrazine 50 WP. Post-emergence grass weeds: Tembotrione 34.4 SC (with recommended adjuvant).',
  'Wheat':
      'Narrow-leaf weeds: Clodinafop-propargyl 15 WP or Pinoxaden 5 EC. Broadleaf weeds: Metsulfuron-methyl 20 WG or Carfentrazone-ethyl + Metsulfuron mix.',
  'Rice':
      'Pre-emergence: Pretilachlor 50 EC or Pendimethalin 30 EC. Post-emergence options: Bispyribac-sodium 10 SC (as per crop stage).',
  'Potato':
      'Pre-emergence: Metribuzin 70 WP (variety-sensitive; follow local guidance). Non-selective pre-plant burndown: Glyphosate 41 SL on emerged weeds only before crop emergence.',
  'Sugarcane':
      'Pre-emergence: Atrazine 50 WP. Directed inter-row management: 2,4-D amine salt 58 SL or Metribuzin 70 WP where suitable.',
  'Cotton':
      'Pre-plant/pre-emergence: Pendimethalin 30 EC. Directed post-emergence in tolerant systems only as advised: Glyphosate 41 SL (avoid crop contact).',
  'Gram':
      'Pre-emergence: Pendimethalin 30 EC. Early post broadleaf pressure: Imazethapyr 10 SL (where locally approved).',
  'Mustard':
      'Pre-emergence: Pendimethalin 30 EC. Grass weed pressure in post stage: Quizalofop-ethyl 5 EC where label allows.',
  'Bajra':
      'Early weed flush: Atrazine 50 WP pre-emergence where recommended; otherwise timely interculture plus hand weeding.',
  'Barley':
      'Broadleaf weeds: Metsulfuron-methyl 20 WG. Grass weeds in mixed pressure areas: Pinoxaden 5 EC where locally recommended.',
};

const Map<String, String> pesticideFormulasByCropUrdu = {
  'Maize':
      'سٹیم بورر/فال آرمی ورم: Chlorantraniliprole 18.5 SC، Emamectin benzoate 5 SG، Spinetoram 11.7 SC۔ چوسنے والے کیڑوں کے لیے: Imidacloprid 17.8 SL۔',
  'Wheat':
      'ایفڈ: Imidacloprid 17.8 SL یا Thiamethoxam 25 WG۔ آرمی ورم/کٹ ورم میں: Emamectin benzoate 5 SG یا Lambda-cyhalothrin 2.5 EC۔',
  'Rice':
      'سٹیم بورر/لیف فولڈر: Chlorantraniliprole 18.5 SC یا Flubendiamide 20 WG۔ پلانٹ ہوپر: Buprofezin 25 SC یا Pymetrozine 50 WG۔',
  'Potato':
      'ایفڈ: Imidacloprid 17.8 SL۔ ٹیوبر مَتھ/سنڈی: Emamectin benzoate 5 SG یا Chlorantraniliprole 18.5 SC۔',
  'Sugarcane':
      'بوررز: Chlorantraniliprole 18.5 SC یا Fipronil 5 SC۔ ارلی شوٹ بورر دورانیہ میں: Cartap hydrochloride 50 SP (مقامی ہدایت کے مطابق)۔',
  'Cotton':
      'سفید مکھی/جیسڈ/تھرپس: Imidacloprid 17.8 SL، Acetamiprid 20 SP، یا Thiamethoxam 25 WG۔ گلابی سنڈی: Emamectin benzoate 5 SG یا Chlorantraniliprole 18.5 SC۔',
  'Gram':
      'پوڈ بورر: Emamectin benzoate 5 SG، Chlorantraniliprole 18.5 SC، یا Spinosad 45 SC۔',
  'Mustard':
      'ایفڈ: Thiamethoxam 25 WG، Imidacloprid 17.8 SL، یا Acetamiprid 20 SP۔',
  'Bajra':
      'شوٹ فلائی/سٹیم بورر: Emamectin benzoate 5 SG، Chlorantraniliprole 18.5 SC، یا Lambda-cyhalothrin 2.5 EC۔',
  'Barley':
      'ایفڈ/آرمی ورم خطرہ: Thiamethoxam 25 WG یا Imidacloprid 17.8 SL؛ سنڈی حملہ میں Emamectin benzoate 5 SG۔',
};

const Map<String, String> deficiencySymptomsByCropUrdu = {
  'Maize':
      'نائٹروجن: پرانے پتے پیلے؛ فاسفورس: بڑھوتری کم اور جامنی جھلک؛ پوٹاش: کناروں کا جلنا؛ زنک: نئی پتّیوں میں ہلکی دھاریاں۔',
  'Wheat':
      'نائٹروجن: پرانے پتے پیلے اور ٹیلرز کمزور؛ فاسفورس: جڑ کمزور، پکنے میں تاخیر؛ پوٹاش: نوک/کنارہ جلنا؛ زنک: پیلی دھاریاں۔',
  'Rice':
      'نائٹروجن: پوری فصل ہلکی سبز؛ فاسفورس: سست بڑھوتری؛ پوٹاش: کناروں کا سوکھاؤ؛ زنک: برونزنگ اور سٹنٹنگ۔',
  'Potato':
      'نائٹروجن: پتّے ہلکے؛ فاسفورس: چھتری کمزور؛ پوٹاش: کنارے جلنا اور ٹیوبر بھراؤ کم؛ بوران/کیلشیم: اندرونی نقائص۔',
  'Sugarcane':
      'نائٹروجن: ہلکے پتے اور باریک گنا؛ فاسفورس: ابتدائی بڑھوتری کم؛ پوٹاش: نوک سے سوکھاؤ؛ زنک/آئرن: نئی پتّیوں میں پیلاہٹ۔',
  'Cotton':
      'نائٹروجن: کمزور اور ہلکی بڑھوتری؛ پوٹاش: کنارے جلنا، بول بھراؤ کم؛ بوران: بول گرنا/بگڑنا؛ میگنیشیم: پرانی پتّیوں میں بین العروقی پیلاہٹ۔',
  'Gram':
      'فاسفورس: جڑ اور گانٹھ کمزور؛ سلفر: نئی پتّیاں پیلی؛ زنک/آئرن: کلوروسس؛ بوران: پھول/پھلی سیٹ مسئلہ۔',
  'Mustard':
      'سلفر: نئی پتّیاں ہلکی اور تیل کم؛ نائٹروجن: عمومی پیلاہٹ؛ بوران: پھلی بناؤ کم؛ پوٹاش: تنا کمزور۔',
  'Bajra':
      'نائٹروجن: پودے پیلے اور کمزور؛ فاسفورس: ابتدائی بڑھوتری سست؛ پوٹاش: تناؤ میں کنارے سوکھنا؛ زنک: دھاری دار پیلاہٹ۔',
  'Barley':
      'نائٹروجن: پرانے پتے پیلے؛ فاسفورس: جڑ/ٹیلرنگ کمزور؛ پوٹاش: نوک جلنا؛ زنک: بین العروقی کلوروسس۔',
};

const Map<String, List<String>> deficiencyNutrientsByCrop = {
  'Maize': ['Nitrogen', 'Phosphorus', 'Potassium', 'Zinc'],
  'Wheat': ['Nitrogen', 'Phosphorus', 'Potassium', 'Zinc'],
  'Rice': ['Nitrogen', 'Phosphorus', 'Potassium', 'Zinc'],
  'Potato': ['Nitrogen', 'Phosphorus', 'Potassium', 'Boron'],
  'Sugarcane': ['Nitrogen', 'Phosphorus', 'Potassium', 'Iron'],
  'Cotton': ['Nitrogen', 'Potassium', 'Boron', 'Magnesium'],
  'Gram': ['Phosphorus', 'Sulfur', 'Zinc', 'Iron'],
  'Mustard': ['Nitrogen', 'Sulfur', 'Boron', 'Potassium'],
  'Bajra': ['Nitrogen', 'Phosphorus', 'Potassium', 'Zinc'],
  'Barley': ['Nitrogen', 'Phosphorus', 'Potassium', 'Zinc'],
};

const Map<String, String> diseaseFormulasByCropUrdu = {
  'Maize':
      'حفاظتی: Mancozeb 75 WP؛ ڈاؤنی ملی ڈیو والے علاقوں میں آغاز میں Metalaxyl + Mancozeb 72 WP۔ علاجی/بڑھتے حملے میں: Azoxystrobin 23 SC یا Propiconazole 25 EC علامات اور مرحلے کے مطابق۔',
  'Wheat':
      'حفاظتی: Carboxin + Thiram بیج ٹریٹمنٹ (سمٹ)، رسٹ کے خطرے میں ابتدائی Propiconazole 25 EC۔ علاجی/بڑھتے حملے میں: Tebuconazole 25 EC یا Azoxystrobin + Difenoconazole پری مکس پہلی واضح علامات پر۔',
  'Rice':
      'حفاظتی: بلاسٹ کے خطرے میں Tricyclazole 75 WP اور شیتھ بلائٹ رسک میں Validamycin 3 L کی منصوبہ بندی۔ علاجی/بڑھتے حملے میں: Tricyclazole 75 WP (بلاسٹ)، Validamycin 3 L (شیتھ بلائٹ)، Copper hydroxide 77 WP (بیکٹیریل دباؤ) مقامی ہدایت کے مطابق۔',
  'Potato':
      'حفاظتی: بلائٹ موسم سے پہلے Mancozeb 75 WP شروع کریں۔ علاجی/بڑھتے حملے میں: Cymoxanil + Mancozeb یا Metalaxyl + Mancozeb جب دھبے ظاہر ہوں اور دباؤ بڑھے۔',
  'Sugarcane':
      'حفاظتی: Carbendazim 50 WP گنڈی ٹریٹمنٹ اور سخت صفائی۔ علاجی/مقامی پھیلاؤ میں: Copper oxychloride 50 WP کو روگنگ اور صاف بیج حکمتِ عملی کے ساتھ استعمال کریں۔',
  'Cotton':
      'حفاظتی: فنگسی دھبوں کے خطرے میں Copper oxychloride 50 WP یا Carbendazim 50 WP۔ علاجی/بڑھتے حملے میں: Azoxystrobin 23 SC یا Carbendazim + protectant مکس علامات کے مطابق۔ نوٹ: وائرسی مسئلے میں بنیادی کنٹرول کیڑے کے ذریعے ہوتا ہے، فنجی سائیڈ علاجی حل نہیں۔',
  'Gram':
      'حفاظتی: Thiram/Carbendazim بیج ٹریٹمنٹ اور بلائٹ موسم میں ابتدائی Chlorothalonil 75 WP۔ علاجی/بڑھتے حملے میں: Carbendazim + Mancozeb مکس یا Chlorothalonil 75 WP بیماری کی شدت کے مطابق۔',
  'Mustard':
      'حفاظتی: Alternaria/white rust خطرے میں Mancozeb 75 WP۔ علاجی/بڑھتے حملے میں: Metalaxyl + Mancozeb 72 WP (وائٹ رسٹ) یا Propiconazole 25 EC (الٹرنیریا غالب علامات)۔',
  'Bajra':
      'حفاظتی: ڈاؤنی ملی ڈیو والے علاقوں میں Metalaxyl + Mancozeb 72 WP اور سسٹمک بیج ٹریٹمنٹ۔ علاجی/بڑھتے حملے میں: پہلی علامات پر مقامی شیڈول کے مطابق Metalaxyl + Mancozeb پروگرام جاری کریں۔',
  'Barley':
      'حفاظتی: Carboxin + Thiram بیج ٹریٹمنٹ اور ابتدائی رسٹ نگرانی۔ علاجی/بڑھتے حملے میں: Propiconazole 25 EC یا Tebuconazole 25 EC پتوں کی علامات پر مقامی ہدایت کے مطابق۔',
};

const Map<String, String> weedicideFormulasByCropUrdu = {
  'Maize':
      'پری ایمرجنس: Atrazine 50 WP۔ پوسٹ ایمرجنس گھاس کے لیے: Tembotrione 34.4 SC (تجویز کردہ ایڈجوانٹ کے ساتھ)۔',
  'Wheat':
      'باریک پتی جڑی بوٹیاں: Clodinafop-propargyl 15 WP یا Pinoxaden 5 EC۔ چوڑی پتی کے لیے: Metsulfuron-methyl 20 WG یا Carfentrazone-ethyl + Metsulfuron مکس۔',
  'Rice':
      'پری ایمرجنس: Pretilachlor 50 EC یا Pendimethalin 30 EC۔ پوسٹ ایمرجنس: Bispyribac-sodium 10 SC (فصل کے مرحلے کے مطابق)۔',
  'Potato':
      'پری ایمرجنس: Metribuzin 70 WP (اقسام میں حساسیت ممکن؛ مقامی ہدایت لیں)۔ پری پلانٹ برن ڈاؤن: Glyphosate 41 SL صرف ابھری جڑی بوٹیوں پر، فصل نکلنے سے پہلے۔',
  'Sugarcane':
      'پری ایمرجنس: Atrazine 50 WP۔ ڈائریکٹڈ انٹررو استعمال: 2,4-D amine salt 58 SL یا Metribuzin 70 WP جہاں موزوں ہو۔',
  'Cotton':
      'پری پلانٹ/پری ایمرجنس: Pendimethalin 30 EC۔ برداشت رکھنے والے نظام میں ڈائریکٹڈ پوسٹ استعمال: Glyphosate 41 SL (فصل سے رابطہ نہ ہو)۔',
  'Gram':
      'پری ایمرجنس: Pendimethalin 30 EC۔ ابتدائی پوسٹ چوڑی پتی دباؤ میں: Imazethapyr 10 SL (جہاں مقامی طور پر منظور ہو)۔',
  'Mustard':
      'پری ایمرجنس: Pendimethalin 30 EC۔ پوسٹ مرحلے میں گھاس کے دباؤ پر: Quizalofop-ethyl 5 EC (لیبل اجازت کے مطابق)۔',
  'Bajra':
      'ابتدائی جڑی بوٹی اگاؤ: Atrazine 50 WP پری ایمرجنس جہاں سفارش ہو؛ ورنہ بروقت گوڈی اور ہاتھ سے صفائی۔',
  'Barley':
      'چوڑی پتی جڑی بوٹیاں: Metsulfuron-methyl 20 WG۔ گھاس کے دباؤ میں: Pinoxaden 5 EC جہاں مقامی سفارش موجود ہو۔',
};

// Placeholder instructions - will be replaced with researched data
const String maizeInstructions = '''
Soil Preparation:
- Prepare well-drained loamy soil
- pH: 6.0-7.0
- Deep plowing and harrowing

Seed Selection and Sowing:
- Use certified hybrid seeds
- Sowing time: Spring (January-March) and Kharif (June-July)
- Seed rate: 8.1-10.1 kg/acre
- Row spacing: 60-75 cm

Recommended modern cultivars (Pakistan):
- DK-6714: medium maturity (about 105-115 days), high yield under irrigated management.
- P-1543: stable grain performance, good standability, suitable for spring and kharif windows.
- YH-1898: vigorous hybrid, better tolerance to heat spells during tasseling.
- FH-1046: dual-purpose grain/fodder suitability, performs well with balanced nitrogen.

Irrigation:
- Spring sowing: first irrigation at 18-22 days after sowing, then every 7-9 days in hot, dry weather.
- Kharif sowing: first irrigation at 15-20 days after sowing, then every 10-12 days based on rainfall.
- Keep soil moisture steady at knee-high, tasseling, silking, and grain filling stages.
- Total irrigations: usually 6-8 in spring and 4-6 in kharif.

Fertilizer:
- NPK: 48.6-24.3-16.2 kg/acre
- Apply in splits

Pest Management:
- Monitor for stem borers, aphids
- Use integrated pest management

Harvesting:
- Harvest when grains are hard
- Yield: 1.6-2.4 tons/acre
''';

const String wheatInstructions = '''
Soil Preparation:
- Fine tilth soil
- pH: 6.5-7.5
- Ploughing and leveling

Seed Selection and Sowing:
- Use improved varieties
- Sowing time: November-December
- Seed rate: 40.5-50.6 kg/acre
- Row spacing: 20-25 cm

Recommended modern cultivars (Pakistan):
- Akbar-2019: high yield potential, strong rust tolerance, broadly adapted across major wheat zones.
- Ghazi-2019: better stability under late sowing and terminal heat stress.
- Subhani-2021: improved grain quality with good standability in fertile irrigated fields.
- Dilkash-2021: vigorous tillering and strong performance under timely sowing.

Irrigation:
- Pre-sowing irrigation
- Crown root initiation, tillering, jointing, grain filling
- Total 4-5 irrigations

Fertilizer:
- NPK: 48.6-24.3-16.2 kg/acre
- Apply urea in splits

Disease Management:
- Rust, smut diseases
- Use resistant varieties

Harvesting:
- Harvest when grains are hard
- Yield: 1.2-2.0 tons/acre
''';

const String riceInstructions = '''
Soil Preparation:
- Puddled soil
- pH: 6.0-7.0
- Bunds and leveling

Seed Selection and Sowing:
- Use high-yielding varieties
- Sowing time: June-July
- Seed rate: 16.2-20.2 kg/acre
- Transplanting after 25-30 days

Recommended modern cultivars (Pakistan):
- Basmati-515: premium aromatic type, medium duration, good grain quality.
- PK-1121 Aromatic: extra-long grain, export-oriented quality, needs careful water management.
- KSK-133: non-basmati, high yield potential in irrigated belts.
- Super Basmati: widely grown aromatic type with strong market acceptance.

Irrigation:
- Continuous flooding
- Keep 5-10 cm water

Fertilizer:
- NPK: 40.5-20.2-20.2 kg/acre
- Apply in splits

Pest Management:
- Stem borers, leafhoppers
- Use pesticides judiciously

Harvesting:
- Harvest when 80% grains are straw-colored
- Yield: 1.6-2.4 tons/acre
''';

const String potatoInstructions = '''
Soil Preparation:
- Loose, well-drained soil
- pH: 5.5-6.5
- Ridging

Seed Selection and Sowing:
- Use certified seed tubers
- Sowing time: October-November
- Seed rate: 0.8-1.2 tons/acre
- Spacing: 60x20 cm

Recommended modern cultivars (Pakistan):
- Sante: medium maturity, strong foliage, good table potato performance.
- Lady Rosetta: early-medium, preferred for chips processing.
- Hermes: suitable for processing, better dry matter for crisps.
- Faisalabad White: adaptable local table variety with consistent tuber set.

Irrigation:
- Light and frequent
- Avoid waterlogging

Fertilizer:
- NPK: 60.7-40.5-40.5 kg/acre
- Apply at planting and earthing up

Disease Management:
- Late blight, bacterial wilt
- Use fungicides

Harvesting:
- Harvest 90-100 days after planting
- Yield: 8.1-12.1 tons/acre
''';

const String sugarcaneInstructions = '''
Soil Preparation:
- Deep, fertile loam with good drainage
- pH: 6.0-7.5

Planting:
- Plant healthy setts in February-March or September
- Keep row spacing around 4 to 4.5 feet

Irrigation:
- Keep moisture steady after planting
- Irrigate every 10-14 days in summer and 20-25 days in cool months

Fertilizer:
- Apply farmyard manure before planting
- Split nitrogen into 3 applications

Harvesting:
- Harvest at full maturity (about 10-12 months)
''';

const String cottonInstructions = '''
Soil Preparation:
- Well-drained medium to heavy loam
- pH: 6.0-8.0

Sowing:
- Sowing window in Pakistan is generally May-June in most cotton-growing zones
- Use approved Bt/non-Bt seed as per local guidance

Irrigation:
- First irrigation after establishment
- Then irrigate at 12-18 day intervals based on heat and soil type

Crop Care:
- Monitor whitefly, jassid, and pink bollworm regularly
- Remove alternate weed hosts around the field

Harvesting:
- Pick clean kapas in multiple pickings
''';

const String gramInstructions = '''
Soil Preparation:
- Well-drained loam or sandy loam
- Avoid waterlogged fields

Sowing:
- Sowing time: October-November
- Use certified seed and seed treatment before sowing

Irrigation:
- Usually 1-2 irrigations are enough in dry spells
- Critical stages: flowering and pod formation

Fertilizer:
- Basal phosphorus improves root and pod development

Harvesting:
- Harvest when most pods turn brown and dry
''';

const String mustardInstructions = '''
Soil Preparation:
- Fine seedbed in well-drained loam

Sowing:
- Sowing time: October-November
- Keep line spacing around 45 cm

Irrigation:
- First irrigation at branching stage
- Second irrigation at flowering or pod filling if needed

Crop Care:
- Watch for aphids and alternaria blight
- Keep field weed free in early growth

Harvesting:
- Harvest when 70-80% siliquae turn yellow
''';

const String bajraInstructions = '''
Soil Preparation:
- Performs well in light to medium soils

Sowing:
- Sowing time: June-July (rainfed/kharif)
- Use suitable drought-tolerant varieties

Irrigation:
- Mostly rainfed; provide 1-2 lifesaving irrigations in drought
- Critical stage: flowering

Fertilizer:
- Balanced nitrogen and phosphorus at sowing/split

Harvesting:
- Harvest when earheads mature and grains harden
''';

const String barleyInstructions = '''
Soil Preparation:
- Well-drained loam with good tilth

Sowing:
- Sowing time: November
- Use recommended seed rate for your district

Irrigation:
- 2-3 irrigations are often enough
- Critical stages: tillering and grain filling

Fertilizer:
- Apply nitrogen in split doses and phosphorus at sowing

Harvesting:
- Harvest when spikes and straw turn golden
''';

const String onionInstructions = '''
Soil Preparation:
- Deep, friable well-drained loam

Sowing/Transplanting:
- Nursery in Oct-Nov, transplant in Dec-Jan

Irrigation:
- Keep moisture steady during bulb formation

Fertilizer:
- Balanced NPK with sulfur is important

Harvesting:
- Stop irrigation before harvest for better curing
''';

const String tomatoInstructions = '''
Soil Preparation:
- Well-drained fertile loam

Transplanting:
- Transplant healthy seedlings at proper spacing

Irrigation:
- Irrigate regularly but avoid prolonged leaf wetness

Fertilizer:
- Split nitrogen and maintain potassium for fruit quality

Crop Care:
- Monitor whitefly, fruit borer, and blights regularly
''';

const String chilliInstructions = '''
Soil Preparation:
- Well-drained fertile soil with good aeration

Transplanting:
- Use healthy nursery seedlings

Irrigation:
- Keep moisture uniform and avoid waterlogging

Fertilizer:
- Use balanced fertilization; avoid excess nitrogen

Crop Care:
- Monitor thrips, mites, and leaf curl pressure
''';

const String brinjalInstructions = '''
Soil Preparation:
- Fine, well-drained loam with organic matter

Transplanting:
- Transplant vigorous seedlings at proper row spacing

Irrigation:
- Irrigate regularly without standing water

Fertilizer:
- Split nitrogen and maintain potassium during fruiting

Crop Care:
- Monitor shoot and fruit borer closely
''';

const String mangoInstructions = '''
Orchard Setup:
- Plant healthy grafted trees at recommended spacing

Seasonal Care:
- Irrigate at flowering, fruit set, and fruit development

Nutrition:
- Apply annual manure and split fertilizers by season

Protection:
- Monitor hopper, mealybug, mildew, and anthracnose

Harvesting:
- Harvest mature fruits carefully to avoid sap burn
''';

const String citrusInstructions = '''
Orchard Setup:
- Maintain healthy orchard spacing and drainage

Seasonal Care:
- Avoid moisture stress during fruit development

Nutrition:
- Apply split fertilizers with zinc and boron as needed

Protection:
- Monitor psylla, canker, mites, and gummosis

Harvesting:
- Harvest at mature color and desired sweetness
''';

const String guavaInstructions = '''
Orchard Setup:
- Plant in well-drained soil with balanced canopy management

Seasonal Care:
- Irrigate more often in summer and prune after harvest

Nutrition:
- Apply FYM and split fertilizers annually

Protection:
- Monitor fruit fly, wilt, and anthracnose

Harvesting:
- Pick fruits at proper maturity for market purpose
''';

const String bananaInstructions = '''
Field Preparation:
- Use healthy suckers in fertile, well-drained soil

Planting:
- Plant in suitable season with proper spacing

Irrigation:
- Maintain regular irrigation, especially in hot weather

Fertilizer:
- High potassium and split nitrogen are critical

Crop Care:
- Manage weevil, nematodes, and leaf diseases early
''';

const String maizeInstructionsUrdu = '''
زمین کی تیاری:
- بھربھری اور نکاسی والی زمین رکھیں
- پی ایچ 6.0 تا 7.0 مناسب ہے

بوائی:
- معیاری بیج استعمال کریں
- وقت: بہار (جنوری تا مارچ) اور خریف (جون تا جولائی)

پاکستان کے لیے تجویز کردہ جدید اقسام:
- DK-6714: درمیانی مدت (تقریباً 105 تا 115 دن)، آبپاش علاقوں میں بلند پیداوار۔
- P-1543: مستحکم پیداوار، پودے کھڑے رہتے ہیں، بہاری اور خریف دونوں اوقات میں موزوں۔
- YH-1898: طاقتور ہائبرڈ، پھول آنے کے وقت گرمی کو نسبتاً بہتر برداشت کرتی ہے۔
- FH-1046: دانہ اور چارہ دونوں کے لیے موزوں، متوازن نائٹروجن پر بہتر نتیجہ۔

آبپاشی:
- بہاری کاشت: پہلی آبپاشی بوائی کے 18 تا 22 دن بعد، پھر گرم اور خشک موسم میں ہر 7 تا 9 دن بعد۔
- خریف کاشت: پہلی آبپاشی بوائی کے 15 تا 20 دن بعد، پھر بارش کے مطابق ہر 10 تا 12 دن بعد۔
- گھٹنے کی اونچائی، ٹیسلنگ، سلکنگ اور دانہ بھرنے کے مراحل پر نمی برقرار رکھیں۔
- کل آبپاشیاں: بہار میں عموماً 6 تا 8 اور خریف میں 4 تا 6۔

کھاد:
- این پی کے 48.6-24.3-16.2 کلوگرام فی ایکڑ
''';

const String wheatInstructionsUrdu = '''
زمین کی تیاری:
- ہموار اور نرم زمین رکھیں
- پی ایچ 6.5 تا 7.5 بہتر ہے

بوائی:
- بہتر اقسام کا بیج لیں
- وقت: نومبر تا دسمبر

پاکستان کے لیے تجویز کردہ جدید اقسام:
- Akbar-2019: زیادہ ممکنہ پیداوار، رسٹ کے خلاف بہتر تحفظ، پاکستان کے اہم گندم علاقوں میں اچھی موافقت۔
- Ghazi-2019: دیر سے کاشت اور آخری گرمی کے دباؤ میں نسبتاً بہتر استحکام۔
- Subhani-2021: بہتر دانے کا معیار اور زرخیز آبپاش زمین میں بہتر کھڑے رہنے کی صلاحیت۔
- Dilkash-2021: مضبوط ٹیلرنگ اور بروقت کاشت میں اچھی کارکردگی۔

آبپاشی:
- اہم مراحل پر 4 تا 5 آبپاشیاں

کھاد:
- این پی کے 48.6-24.3-16.2 کلوگرام فی ایکڑ
''';

const String riceInstructionsUrdu = '''
زمین کی تیاری:
- پانی روکنے والی ہموار زمین تیار کریں

بوائی/منتقلی:
- وقت: جون تا جولائی
- 25 تا 30 دن کی پنیری منتقل کریں

پاکستان کے لیے تجویز کردہ جدید اقسام:
- Basmati-515: خوشبودار، درمیانی مدت، بہتر دانے کا معیار۔
- PK-1121 Aromatic: لمبا دانہ، برآمدی معیار، پانی کا محتاط انتظام ضروری۔
- KSK-133: غیر باسمتی، آبپاش علاقوں میں زیادہ پیداوار کی صلاحیت۔
- Super Basmati: مقبول خوشبودار قسم، مارکیٹ میں اچھی طلب۔

آبپاشی:
- کھیت میں 5 تا 10 سینٹی میٹر پانی برقرار رکھیں

کھاد:
- این پی کے 40.5-20.2-20.2 کلوگرام فی ایکڑ
''';

const String potatoInstructionsUrdu = '''
زمین کی تیاری:
- نرم اور اچھی نکاسی والی زمین منتخب کریں

بوائی:
- معیاری بیج آلو استعمال کریں
- وقت: اکتوبر تا نومبر

پاکستان کے لیے تجویز کردہ جدید اقسام:
- Sante: درمیانی مدت، اچھی بڑھوتری، ٹیبل آلو کے لیے موزوں۔
- Lady Rosetta: ابتدائی تا درمیانی مدت، چپس انڈسٹری کے لیے پسندیدہ۔
- Hermes: پروسیسنگ کے لیے موزوں، کرسپس کے لیے بہتر خشک مادہ۔
- Faisalabad White: مقامی طور پر موزوں، یکساں گانٹھ بنانے والی قسم۔

آبپاشی:
- ہلکی مگر بار بار آبپاشی کریں

کھاد:
- این پی کے 60.7-40.5-40.5 کلوگرام فی ایکڑ
''';

const String sugarcaneInstructionsUrdu = '''
زمین کی تیاری:
- گہری اور زرخیز میرا زمین بہتر ہے

کاشت:
- فروری تا مارچ یا ستمبر میں صحت مند گنڈی لگائیں

آبپاشی:
- گرمی میں 10 تا 14 دن اور سردی میں 20 تا 25 دن کے وقفے سے

کٹائی:
- مکمل پختگی پر 10 تا 12 ماہ بعد کٹائی کریں
''';

const String cottonInstructionsUrdu = '''
زمین کی تیاری:
- اچھی نکاسی والی میرا تا بھاری زمین موزوں ہے

بوائی:
- پاکستان کے بیشتر کپاس کاشت علاقوں میں عمومی وقت مئی تا جون

آبپاشی:
- جڑ پکڑنے کے بعد پہلی آبپاشی، پھر موسم کے مطابق 12 تا 18 دن بعد

فصل کی حفاظت:
- سفید مکھی، جیسڈ اور گلابی سنڈی کی باقاعدہ نگرانی کریں
''';

const String gramInstructionsUrdu = '''
زمین کی تیاری:
- میرا یا ریتیلی میرا زمین بہتر ہے، پانی کھڑا نہ ہو

بوائی:
- اکتوبر تا نومبر میں کاشت کریں

آبپاشی:
- خشک موسم میں عموماً 1 تا 2 آبپاشیاں کافی رہتی ہیں

کٹائی:
- جب زیادہ تر پھلیاں بھوری اور خشک ہو جائیں
''';

const String mustardInstructionsUrdu = '''
زمین کی تیاری:
- نرم اور ہموار بیج بستر تیار کریں

بوائی:
- اکتوبر تا نومبر

آبپاشی:
- پہلی آبپاشی شاخیں نکلنے پر، دوسری پھول یا پھلی مرحلے پر حسبِ ضرورت

فصل کی حفاظت:
- ایفڈ اور الٹرنیریا بلائٹ کی نگرانی کریں
''';

const String bajraInstructionsUrdu = '''
زمین کی تیاری:
- ہلکی تا درمیانی زمین میں اچھی پیداوار دیتی ہے

بوائی:
- جون تا جولائی (خریف)

آبپاشی:
- عموماً بارانی فصل ہے، خشک سالی میں 1 تا 2 بچاؤ آبپاشیاں دیں

کٹائی:
- بالیاں پکنے اور دانہ سخت ہونے پر کٹائی کریں
''';

const String barleyInstructionsUrdu = '''
زمین کی تیاری:
- اچھی نکاسی والی میرا زمین مناسب ہے

بوائی:
- نومبر میں کاشت کریں

آبپاشی:
- عموماً 2 تا 3 آبپاشیاں کافی رہتی ہیں

کٹائی:
- بالیاں اور تنکے سنہری ہونے پر کٹائی کریں
''';

const String onionInstructionsUrdu = '''
زمین کی تیاری:
- گہری، نرم اور اچھی نکاسی والی میرا زمین

بوائی/منتقلی:
- نرسری اکتوبر-نومبر، منتقلی دسمبر-جنوری

آبپاشی:
- پیاز بننے کے دوران مناسب نمی برقرار رکھیں

کھاد:
- متوازن این پی کے کے ساتھ سلفر مفید ہے

کٹائی:
- بہتر خشکائی کے لیے برداشت سے پہلے آبپاشی کم کریں
''';

const String tomatoInstructionsUrdu = '''
زمین کی تیاری:
- زرخیز اور اچھی نکاسی والی میرا زمین

منتقلی:
- صحت مند پنیری مناسب فاصلے پر لگائیں

آبپاشی:
- باقاعدہ آبپاشی کریں مگر پتوں کو زیادہ دیر گیلا نہ رکھیں

کھاد:
- نائٹروجن قسطوں میں اور پوٹاش مناسب مقدار میں دیں

فصل کی حفاظت:
- سفید مکھی، فروٹ بورر اور بلائٹ کی نگرانی کریں
''';

const String chilliInstructionsUrdu = '''
زمین کی تیاری:
- اچھی نکاسی اور ہوا دار زرخیز زمین

منتقلی:
- صحت مند نرسری پودے استعمال کریں

آبپاشی:
- یکساں نمی رکھیں، پانی کھڑا نہ ہونے دیں

کھاد:
- متوازن کھاد دیں؛ زیادہ نائٹروجن سے بچیں

فصل کی حفاظت:
- تھرپس، مکڑی اور لیف کرل کی نگرانی کریں
''';

const String brinjalInstructionsUrdu = '''
زمین کی تیاری:
- نامیاتی مادہ والی اچھی نکاسی کی میرا زمین

منتقلی:
- توانا پنیری کو مناسب فاصلے پر لگائیں

آبپاشی:
- باقاعدہ آبپاشی کریں مگر پانی کھڑا نہ ہو

کھاد:
- نائٹروجن قسطوں میں اور پھل کے وقت پوٹاش بڑھائیں

فصل کی حفاظت:
- ٹہنی اور پھل بیدھنے والے کیڑے پر خاص نظر رکھیں
''';

const String mangoInstructionsUrdu = '''
باغ کی تیاری:
- صحت مند قلمی پودے مناسب فاصلے پر لگائیں

موسمی دیکھ بھال:
- پھول، پھل لگنے اور بڑھوتری کے وقت آبپاشی کریں

غذائیت:
- سالانہ گوبر کھاد اور قسطوں میں کھاد دیں

تحفظ:
- ہاپر، میلی بگ، ملی ڈیو اور اینتھراکنوز کی نگرانی کریں

کٹائی:
- پکے پھل احتیاط سے توڑیں تاکہ رس کا داغ نہ پڑے
''';

const String citrusInstructionsUrdu = '''
باغ کی تیاری:
- مناسب فاصلہ اور اچھی نکاسی برقرار رکھیں

موسمی دیکھ بھال:
- پھل بڑھنے کے دوران پانی کی کمی نہ آنے دیں

غذائیت:
- کھاد قسطوں میں دیں، ضرورت پر زنک اور بورون دیں

تحفظ:
- سِیلا، کینکر، مائٹ اور گموسِس کی نگرانی کریں

کٹائی:
- رنگ اور مٹھاس مکمل ہونے پر برداشت کریں
''';

const String guavaInstructionsUrdu = '''
باغ کی تیاری:
- اچھی نکاسی والی زمین اور مناسب کانٹ چھانٹ رکھیں

موسمی دیکھ بھال:
- گرمی میں زیادہ آبپاشی اور برداشت کے بعد کانٹ چھانٹ کریں

غذائیت:
- گوبر کھاد اور سالانہ کھاد قسطوں میں دیں

تحفظ:
- پھل مکھی، مرجھاؤ اور اینتھراکنوز کی نگرانی کریں

کٹائی:
- مارکیٹ مقصد کے مطابق مناسب پختگی پر توڑیں
''';

const String bananaInstructionsUrdu = '''
زمین کی تیاری:
- زرخیز اور اچھی نکاسی والی زمین میں صحت مند پنیری لگائیں

کاشت:
- مناسب موسم اور فاصلے پر کاشت کریں

آبپاشی:
- خاص طور پر گرمی میں باقاعدہ آبپاشی کریں

کھاد:
- پوٹاش زیادہ اور نائٹروجن قسطوں میں دیں

فصل کی حفاظت:
- ویول، نیماٹوڈ اور پتوں کی بیماریوں کو شروع سے کنٹرول کریں
''';
