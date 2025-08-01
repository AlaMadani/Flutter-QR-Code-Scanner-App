import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:clipboard/clipboard.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

// Class to represent a scan entry with QR code and timestamp
class ScanEntry {
  final String code;
  final DateTime timestamp;

  ScanEntry(this.code, this.timestamp);

  Map<String, dynamic> toJson() => {
        'code': code,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ScanEntry.fromJson(Map<String, dynamic> json) => ScanEntry(
        json['code'] as String,
        DateTime.parse(json['timestamp'] as String),
      );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QRScannerApp());
}

class QRScannerApp extends StatefulWidget {
  const QRScannerApp({super.key});

  @override
  State<QRScannerApp> createState() => _QRScannerAppState();
}

class _QRScannerAppState extends State<QRScannerApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<bool> _initializeFirebase() async {
    try {
      print('Attempting Firebase initialization...');
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
      return true;
    } catch (e) {
      print('Firebase initialization failed: $e');
      return false;
    }
  }

  void _showFirebaseErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF06292),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Firebase Connection Failed',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'NotoSansArabic',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Failed to connect to Firebase. Please check your network and try again.\nError: $error',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontFamily: 'NotoSansArabic',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE91E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {});
            },
            child: Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              SystemNavigator.pop();
            },
            child: Text(
              'Close',
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00897B),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00897B),
          secondary: Color(0xFF5C6BC0),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFF06292),
          onPrimary: Colors.white,
          onSecondary: Color(0xFF1A237E),
          onSurface: Color(0xFF1C2526),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00897B),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          titleSpacing: 16.0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF00897B),
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFFB0BEC5),
          selectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic', fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic'),
          elevation: 8,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Color(0xFF1C2526),
            fontFamily: 'NotoSansArabic',
            fontSize: 16,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'NotoSansArabic',
            fontSize: 20,
          ),
          bodySmall: TextStyle(
            color: Color(0xFF1C2526),
            fontFamily: 'NotoSansArabic',
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF00897B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            elevation: 3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.black12,
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF26A69A),
        scaffoldBackgroundColor: const Color(0xFF1C2526),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF26A69A),
          secondary: Color(0xFF7986CB),
          surface: Color(0xFF2A3439),
          error: Color(0xFFF06292),
          onPrimary: Colors.white,
          onSecondary: Color(0xFFE8EAF6),
          onSurface: Color(0xFFE8ECEF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A3439),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black54,
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          titleSpacing: 16.0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2A3439),
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFFB0BEC5),
          selectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic', fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic'),
          elevation: 8,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Color(0xFFE8ECEF),
            fontFamily: 'NotoSansArabic',
            fontSize: 16,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'NotoSansArabic',
            fontSize: 20,
          ),
          bodySmall: TextStyle(
            color: Color(0xFFE8ECEF),
            fontFamily: 'NotoSansArabic',
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF26A69A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            elevation: 3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: Colors.black54,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: FutureBuilder<bool>(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: _isDarkMode ? Color(0xFF1C2526) : Color(0xFFF8FAFC),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00897B),
                ),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.data!) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showFirebaseErrorDialog(context, snapshot.error?.toString() ?? 'Unknown error');
            });
            return Container(
              color: _isDarkMode ? Color(0xFF1C2526) : Color(0xFFF8FAFC),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00897B),
                ),
              ),
            );
          }
          return const SplashScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  List<ScanEntry> _scanHistory = [];
  String _deviceId = 'Loading...';
  String _userName = '';
  String _userRole = '';
  String? _videoUrl;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadScanHistory();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('scanHistory') ?? [];
    setState(() {
      _scanHistory = historyJson
          .map((json) => ScanEntry.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _saveScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = _scanHistory.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList('scanHistory', historyJson);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_selectedIndex == 0 && _videoUrl != null) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      if (isLandscape != _isFullScreen) {
        setState(() {
          _isFullScreen = isLandscape;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final id = await getDeviceId();
    setState(() {
      _deviceId = id;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _userName = data?['name'] ?? 'Unknown';
          _userRole = data?['role'] ?? 'Unknown';
        });
      } else {
        setState(() {
          _userName = 'Unknown';
          _userRole = 'Visitor';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No Internet Connection, Check your connection and refresh Profile',
            style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
          ),
          backgroundColor: Color.fromARGB(255, 255, 11, 11),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _videoUrl = null;
      _isFullScreen = false;
    });
  }

  void _addToHistory(String code) {
    setState(() {
      _scanHistory.insert(0, ScanEntry(code, DateTime.now()));
    });
    _saveScanHistory();
    _fetchVideoForScan(code);
  }

  void _onFullScreenChanged(bool isFullScreen) {
    setState(() {
      _isFullScreen = isFullScreen;
    });
  }

  Future<void> _fetchVideoForScan(String qrCode) async {
    final key = '${qrCode}_${_userRole.trim().toLowerCase()}';
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(key).get();
      if (doc.exists) {
        final url = doc.data()?['videoUrl'];
        if (url != null) {
          Vibration.hasVibrator().then((hasVibrator) {
            if (hasVibrator ?? false) {
              Vibration.vibrate(duration: 200);
            }
          });
          setState(() {
            _videoUrl = url;
            _selectedIndex = 0;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No video found for this scan and role',
              style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
            ),
            backgroundColor: Color(0xFF2A3439),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        setState(() {
          _selectedIndex = 0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No Internet Connection, Check your connection and refresh Profile',
            style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
          ),
          backgroundColor:  Color.fromARGB(255, 255, 11, 11),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _videoUrl != null
          ? VideoScreen(
              videoUrl: _videoUrl!,
              onClose: () {
                setState(() {
                  _videoUrl = null;
                  _isFullScreen = false;
                });
              },
              onFullScreenChanged: _onFullScreenChanged,
            )
          : QRScannerScreen(onScan: _addToHistory),
      HistoryScreen(
        key: UniqueKey(),
        history: _scanHistory,
        onPlayVideo: _fetchVideoForScan,
        onHistoryChanged: _saveScanHistory,
      ),
      ProfileScreen(
        androidId: _deviceId,
        name: _userName,
        role: _userRole,
        onRefresh: _initializeUser,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.2, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: _isFullScreen
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner),
                  label: 'Home',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;
  const QRScannerScreen({super.key, required this.onScan});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with TickerProviderStateMixin {
  String qrCode = 'Scan a QR code';
  bool _isScanning = true;
  bool _isFlashOn = false;
  double _zoomFactor = 0.0;
  final MobileScannerController _controller = MobileScannerController();
  late AnimationController _animationController;
  late Animation<double> _lineAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant QRScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _isScanning = true;
      qrCode = 'Scan a QR code';
      _isFlashOn = false;
      _zoomFactor = 0.0;
    });
    _controller.start();
    _controller.setZoomScale(0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final bottomNavHeight = kBottomNavigationBarHeight;
    final availableHeight = MediaQuery.of(context).size.height - appBarHeight - bottomNavHeight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EL FOULADH ScanGuide', style: TextStyle(fontFamily: 'NotoSansArabic')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoButton(
              onOptionSelected: (value) {
                if (value == 'credits') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreditsScreen()),
                  );
                } else if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox(
            height: availableHeight,
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (!_isScanning) return;
                final barcode = capture.barcodes.first;
                if (barcode.rawValue != null) {
                  final code = barcode.rawValue!;
                  setState(() {
                    qrCode = code;
                    _isScanning = false;
                  });
                  widget.onScan(code);
                }
              },
            ),
          ),
          Container(
            height: availableHeight,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Center(
              child: Container(
                width: availableHeight * 0.7,
                height: availableHeight * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Scan a QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'NotoSansArabic',
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () async {
                await _controller.toggleTorch();
                setState(() {
                  _isFlashOn = !_isFlashOn;
                });
              },
              tooltip: 'Toggle Flashlight',
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.black.withOpacity(0.3)),
                shape: MaterialStateProperty.all(CircleBorder()),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Text(
                  'Zoom: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _zoomFactor,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                    inactiveColor: Colors.white.withOpacity(0.5),
                    onChanged: (value) {
                      setState(() {
                        _zoomFactor = value;
                      });
                      _controller.setZoomScale(value);
                    },
                  ),
                ),
                Text(
                  '${(1.0 + _zoomFactor * 3.0).toStringAsFixed(1)}x',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final linePosition = availableHeight * (0.2 + 0.6 * _lineAnimation.value);
              return Positioned(
                left: 0,
                right: 0,
                top: linePosition,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                          Colors.white,
                          Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final List<ScanEntry> history;
  final Function(String) onPlayVideo;
  final VoidCallback onHistoryChanged;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onPlayVideo,
    required this.onHistoryChanged,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final Set<int> _selectedIndices = {};

  void _clearHistory() {
    setState(() {
      widget.history.clear();
      _selectedIndices.clear();
    });
    widget.onHistoryChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'History cleared',
          style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
        ),
        backgroundColor: Color(0xFF2A3439),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _deleteSelected() {
    setState(() {
      final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (var index in sortedIndices) {
        widget.history.removeAt(index);
      }
      _selectedIndices.clear();
    });
    widget.onHistoryChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected scans deleted',
          style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
        ),
        backgroundColor: Color(0xFF2A3439),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < widget.history.length; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  Map<String, List<ScanEntry>> _groupByDate() {
    final Map<String, List<ScanEntry>> grouped = {};
    for (var entry in widget.history) {
      final date = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedHistory = _groupByDate();
    final dates = groupedHistory.keys.toList()..sort((a, b) => b.compareTo(a));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndices.isEmpty ? 'History' : '${_selectedIndices.length} selected',
          style: TextStyle(fontFamily: 'NotoSansArabic'),
        ),
        actions: [
          if (groupedHistory.isNotEmpty && _selectedIndices.length < widget.history.length)
            IconButton(
              icon: Icon(Icons.select_all, color: Colors.white),
              onPressed: _selectAll,
              tooltip: 'Select All',
            ),
          if (groupedHistory.isNotEmpty && _selectedIndices.length == widget.history.length)
            IconButton(
              icon: Icon(Icons.deselect, color: Colors.white),
              onPressed: _deselectAll,
              tooltip: 'Deselect All',
            ),
          if (_selectedIndices.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelected,
              tooltip: 'Delete selected',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoButton(
              onOptionSelected: (value) {
                if (value == 'clear_history') {
                  _clearHistory();
                } else if (value == 'credits') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreditsScreen()),
                  );
                } else if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF2A3439).withOpacity(0.2),
                    Color(0xFF1C2526),
                  ]
                : [
                    Color(0xFFF8FAFC).withOpacity(0.2),
                    Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: groupedHistory.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 48,
                      color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.7),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No scans yet.',
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontSize: 18,
                        color: isDarkMode ? Color(0xFFE8ECEF) : Color(0xFF1C2526),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  final date = dates[index];
                  final entries = groupedHistory[date]!;
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              date,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                                fontFamily: 'NotoSansArabic',
                              ),
                            ),
                          ),
                          ...entries.asMap().entries.map((entry) {
                            final idx = widget.history.indexOf(entry.value);
                            final formattedTime = DateFormat('HH:mm:ss').format(entry.value.timestamp);
                            final isSelected = _selectedIndices.contains(idx);
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.15)
                                      : isDarkMode
                                          ? Color(0xFF2A3439)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: Icon(Icons.qr_code, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                  title: Text(
                                    entry.value.code,
                                    style: TextStyle(
                                      fontFamily: 'NotoSansArabic',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontFamily: 'NotoSansArabic',
                                      fontSize: 14,
                                      color: isDarkMode ? Color(0xFFB0BEC5) : Color(0xFF5C6BC0),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.play_arrow, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                    onPressed: () => widget.onPlayVideo(entry.value.code),
                                    tooltip: 'Play Video',
                                  ),
                                  selected: isSelected,
                                  selectedTileColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  onLongPress: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIndices.remove(idx);
                                      } else {
                                        _selectedIndices.add(idx);
                                      }
                                    });
                                  },
                                  onTap: _selectedIndices.isNotEmpty
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedIndices.remove(idx);
                                            } else {
                                              _selectedIndices.add(idx);
                                            }
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String androidId;
  final String name;
  final String role;
  final Future<void> Function() onRefresh;

  const ProfileScreen({
    super.key,
    required this.androidId,
    required this.name,
    required this.role,
    required this.onRefresh,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.045;
    final imageSize = screenWidth * 0.25;
    final spacing = screenHeight * 0.025;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'NotoSansArabic')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoButton(
              onOptionSelected: (value) {
                if (value == 'credits') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreditsScreen()),
                  );
                } else if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF2A3439).withOpacity(0.2),
                    Color(0xFF1C2526),
                  ]
                : [
                    Color(0xFFF8FAFC).withOpacity(0.2),
                    Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: RefreshIndicator(
          color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
          backgroundColor: isDarkMode ? Color(0xFF1C2526) : Color(0xFFF8FAFC),
          onRefresh: widget.onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(screenWidth, screenHeight * 0.3),
                    painter: WavePainter(isDarkMode: isDarkMode),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(height: screenHeight * 0.1),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: CircleAvatar(
                          radius: screenWidth * 0.15,
                          backgroundColor: isDarkMode ? Color(0xFF2A3439) : Color(0xFFFFFFFF),
                          child: Text(
                            widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: screenWidth * 0.1,
                              fontWeight: FontWeight.w700,
                              color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                              fontFamily: 'NotoSansArabic',
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: isDarkMode ? Color(0xFF2A3439) : Color(0xFFFFFFFF),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDarkMode ? Color(0xFFE8ECEF).withOpacity(0.2) : Color(0xFF5C6BC0).withOpacity(0.2),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: EdgeInsets.all(screenWidth * 0.05),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (widget.androidId.contains('Firebase Failed') || widget.androidId.contains('Unknown_'))
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0),
                                          child: Text(
                                            'Warning: Firebase connection failed. Device ID may be unreliable.',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.error,
                                              fontFamily: 'NotoSansArabic',
                                              fontSize: fontSize * 0.9,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ListTile(
                                        leading: Icon(Icons.devices, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                        title: Text(
                                          'Device ID',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                        subtitle: Text(
                                          widget.androidId,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize * 0.9,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                        trailing: ActionChip(
                                          label: Text(
                                            'Copy',
                                            style: TextStyle(
                                              color: isDarkMode ? Color(0xFFE8ECEF) : Color(0xFF1C2526),
                                              fontFamily: 'NotoSansArabic',
                                            ),
                                          ),
                                          avatar: Icon(Icons.copy, size: fontSize * 1.25, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                          backgroundColor: isDarkMode ? Color(0xFF2A3439) : Color(0xFFF8FAFC),
                                          onPressed: () {
                                            FlutterClipboard.copy(widget.androidId).then((_) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Device ID copied to clipboard',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: 'NotoSansArabic',
                                                    ),
                                                  ),
                                                  backgroundColor: Color(0xFF2A3439),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.person, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                        title: Text(
                                          'Name',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                        subtitle: Text(
                                          widget.name,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize * 1.2,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.work, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                        title: Text(
                                          'Role',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                        subtitle: Text(
                                          widget.role,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: fontSize * 1.1,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          icon: Icon(Icons.refresh, color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B)),
                                          label: Text(
                                            'Refresh',
                                            style: TextStyle(
                                              color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                                              fontFamily: 'NotoSansArabic',
                                              fontSize: fontSize,
                                            ),
                                          ),
                                          onPressed: widget.onRefresh,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 8,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.share,
                                        color: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                                        size: fontSize * 1.5,
                                      ),
                                      onPressed: () {
                                        Share.share(
                                          'Profile Information:\nDevice ID: ${widget.androidId}\nName: ${widget.name}\nRole: ${widget.role}',
                                          subject: 'EL FOULADH Profile',
                                        );
                                      },
                                      tooltip: 'Share Profile',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.15),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/logo (1).png',
                              width: imageSize,
                              height: imageSize,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  'Logo failed to load',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: Theme.of(context).colorScheme.error,
                                    fontFamily: 'NotoSansArabic',
                                  ),
                                );
                              },
                              filterQuality: FilterQuality.high,
                            ),
                            SizedBox(height: spacing),
                            Text(
                              'EL FOULADH',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: fontSize * 1.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'NotoSansArabic',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final bool isDarkMode;

  WavePainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Color(0xFF26A69A).withOpacity(0.2)
          : Color(0xFF00897B).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.7,
        size.width * 0.5,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.5,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() {
      _isDarkMode = value;
    });
    _QRScannerAppState? appState = context.findAncestorStateOfType<_QRScannerAppState>();
    if (appState != null) {
      appState.setState(() {
        appState._isDarkMode = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.04;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontFamily: 'NotoSansArabic')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoButton(
              onOptionSelected: (value) {
                if (value == 'credits') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreditsScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF2A3439).withOpacity(0.2),
                    Color(0xFF1C2526),
                  ]
                : [
                    Color(0xFFF8FAFC).withOpacity(0.2),
                    Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              child: SwitchListTile(
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'NotoSansArabic',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _isDarkMode,
                activeColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
                onChanged: _toggleDarkMode,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String> getDeviceId() async {
  try {
    final id = await FirebaseInstallations.instance.getId();
    return id;
  } catch (e) {
    print('Firebase Installations failed: $e');
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return 'Firebase Failed: ${androidInfo.id ?? 'Unknown_Android_ID'}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return 'Firebase Failed: ${iosInfo.identifierForVendor ?? 'Unknown_iOS_ID'}';
    } else {
      return 'Firebase Failed: Unsupported_Platform';
    }
  }
}

class VideoScreen extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onFullScreenChanged;

  const VideoScreen({
    super.key,
    required this.videoUrl,
    this.onClose,
    this.onFullScreenChanged,
  });

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;
  bool _lastFullScreenState = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    )..addListener(() {
        if (_controller.value.isFullScreen != _lastFullScreenState) {
          _lastFullScreenState = _controller.value.isFullScreen;
          setState(() {
            widget.onFullScreenChanged?.call(_controller.value.isFullScreen);
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: _controller.value.isFullScreen
          ? null
          : AppBar(
              title: const Text('Instruction Video', style: TextStyle(fontFamily: 'NotoSansArabic')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: LogoButton(
                    onOptionSelected: (value) {
                      if (value == 'credits') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreditsScreen()),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B),
          onReady: () {
            if (_controller.value.isFullScreen != _lastFullScreenState) {
              _lastFullScreenState = _controller.value.isFullScreen;
              widget.onFullScreenChanged?.call(_controller.value.isFullScreen);
            }
          },
        ),
      ),
    );
  }
}

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open link',
            style: TextStyle(color: Colors.white, fontFamily: 'NotoSansArabic'),
          ),
          backgroundColor: Color(0xFFF06292),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.06;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits', style: TextStyle(fontFamily: 'NotoSansArabic')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoButton(
              onOptionSelected: (value) {
                if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF2A3439).withOpacity(0.2),
                    Color(0xFF1C2526),
                  ]
                : [
                    Color(0xFFF8FAFC).withOpacity(0.2),
                    Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This App\nWas Created By\nAla Eddine Madani\n&\nOussema Weslati',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize * 0.8,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Color(0xFFE8ECEF) : Color(0xFF1C2526),
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
                SizedBox(height: fontSize),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Image.asset(
                        'assets/facebook.png',
                        width: fontSize * 1.5,
                        height: fontSize * 1.5,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error,
                          size: fontSize * 1.5,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: () => _launchUrl('https://www.facebook.com/ala.madani.54'),
                      tooltip: 'Visit Facebook',
                      iconSize: fontSize * 1.5,
                      splashColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.3),
                    ),
                    SizedBox(width: fontSize),
                    IconButton(
                      icon: Image.asset(
                        'assets/linkedin.png',
                        width: fontSize * 1.5,
                        height: fontSize * 1.5,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error,
                          size: fontSize * 1.5,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: () => _launchUrl('https://www.linkedin.com/in/ala-eddine-madani-697a20242/'),
                      tooltip: 'Visit LinkedIn',
                      iconSize: fontSize * 1.5,
                      splashColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.3),
                    ),
                    SizedBox(width: fontSize),
                    IconButton(
                      icon: Image.asset(
                        'assets/github.png',
                        width: fontSize * 1.5,
                        height: fontSize * 1.5,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error,
                          size: fontSize * 1.5,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: () => _launchUrl('https://github.com/AlaMadani'),
                      tooltip: 'Visit GitHub',
                      iconSize: fontSize * 1.5,
                      splashColor: Color(isDarkMode ? 0xFF26A69A : 0xFF00897B).withOpacity(0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LogoButton extends StatefulWidget {
  final Function(String?)? onOptionSelected;

  const LogoButton({super.key, this.onOptionSelected});

  @override
  State<LogoButton> createState() => _LogoButtonState();
}

class _LogoButtonState extends State<LogoButton> with SingleTickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late Animation<double> _logoRotation;
  bool _isRotated = false;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _logoRotation = Tween<double>(begin: 0.0, end: -0.5 * 3.14159).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  void _toggleRotation() {
    if (_isRotated) {
      _logoAnimationController.reverse();
    } else {
      _logoAnimationController.forward();
    }
    setState(() {
      _isRotated = !_isRotated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHistoryScreen = ModalRoute.of(context)?.settings.name == '/history';
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _logoRotation.value,
          child: IconButton(
            icon: Image.asset(
              'assets/whitelogo.png',
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.error, color: Colors.white),
            ),
            onPressed: () {
              _toggleRotation();
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(1000, 80, 0, 0),
                items: [
                  if (isHistoryScreen)
                    PopupMenuItem(
                      value: 'clear_history',
                      child: Text(
                        'Clear History',
                        style: TextStyle(fontFamily: 'NotoSansArabic'),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(
                      'Settings',
                      style: TextStyle(fontFamily: 'NotoSansArabic'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'credits',
                    child: Text(
                      'Credits',
                      style: TextStyle(fontFamily: 'NotoSansArabic'),
                    ),
                  ),
                ],
              ).then((value) {
                if (value == null) {
                  if (_isRotated) {
                    _toggleRotation();
                  }
                }
                widget.onOptionSelected?.call(value);
              });
            },
            tooltip: 'Options',
          ),
        );
      },
    );
  }
}