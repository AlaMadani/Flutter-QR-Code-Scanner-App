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
        backgroundColor: const Color(0xFF8B0000), // Darker Red
        title: Text(
          'Firebase Connection Failed',
          style: TextStyle(
            color: Color(0xFFFFFFFF), // White
            fontFamily: 'NotoSansArabic',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Failed to connect to Firebase. Please check your network and try again.\nError: $error',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontFamily: 'NotoSansArabic',
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFB22222), // Industrial Red
              foregroundColor: Color(0xFFFFFFFF), // White
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {}); // Trigger rebuild to retry Firebase init
            },
            child: Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFA9A9A9), // Steel Gray
              foregroundColor: Color(0xFF333333), // Warm Charcoal
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              SystemNavigator.pop();
            },
            child: Text(
              'Close',
              style: TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Color(0xFF333333),
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
        primaryColor: const Color(0xFFB22222), // Industrial Red
        scaffoldBackgroundColor: const Color(0xFFFFFFFF), // Clean White
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFB22222),
          secondary: Color(0xFFA9A9A9),
          surface: Color(0xFFA9A9A9),
          error: Color(0xFF8B0000),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFF333333),
          onSurface: Color(0xFF333333),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB22222),
          foregroundColor: Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFB22222),
          selectedItemColor: Color(0xFFFFFFFF),
          unselectedItemColor: Color(0xFFA9A9A9),
          selectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic'),
          unselectedLabelStyle: TextStyle(fontFamily: 'NotoSansArabic'),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF333333), fontFamily: 'NotoSansArabic'),
          titleLarge: TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSansArabic',
          ),
          bodySmall: TextStyle(color: Color(0xFF333333), fontFamily: 'NotoSansArabic'),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFB22222),
            foregroundColor: Color(0xFFFFFFFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Color(0xFFFFFFFF),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFB22222),
                ),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.data!) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showFirebaseErrorDialog(context, snapshot.error?.toString() ?? 'Unknown error');
            });
            return Container(
              color: Color(0xFFFFFFFF),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFB22222),
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
            'Failed to fetch user data: $e',
            style: TextStyle(color: Color(0xFFFFFFFF), fontFamily: 'NotoSansArabic'),
          ),
          backgroundColor: Color(0xFF8B0000),
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
              style: TextStyle(color: Color(0xFFFFFFFF), fontFamily: 'NotoSansArabic'),
            ),
            backgroundColor: Color(0xFF8B0000),
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
            'Failed to fetch video: $e',
            style: TextStyle(color: Color(0xFFFFFFFF), fontFamily: 'NotoSansArabic'),
          ),
          backgroundColor: Color(0xFF8B0000),
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
      HistoryScreen(history: _scanHistory),
      ProfileScreen(androidId: _deviceId, name: _userName, role: _userRole),
    ];

    return Scaffold(
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
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

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
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
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
    final screenHeight = MediaQuery.of(context).size.height;
    final cameraHeight = screenHeight * 0.6;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner', style: TextStyle(fontFamily: 'NotoSansArabic')),
      ),
      body: Column(
        children: [
          SizedBox(
            height: cameraHeight,
            child: Stack(
              children: [
                MobileScanner(
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: Center(
                    child: Container(
                      width: cameraHeight * 0.7,
                      height: cameraHeight * 0.7,
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFB22222), width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Scan Now',
                      style: TextStyle(
                        color: Color(0xFFB22222),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NotoSansArabic',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                      });
                    },
                    tooltip: 'Toggle Flashlight',
                    style: ButtonStyle(
                      animationDuration: Duration(milliseconds: 150),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Text(
                        'Zoom: ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _zoomFactor,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: Color(0xFFB22222),
                          inactiveColor: Color(0xFFA9A9A9),
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
                          color: Color(0xFFFFFFFF),
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final linePosition = cameraHeight * (0.2 + 0.6 * _lineAnimation.value);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: linePosition,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFB22222),
                                Color(0xFFA9A9A9),
                                Color(0xFFB22222),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text(
              qrCode,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                fontFamily: 'NotoSansArabic',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<ScanEntry> history;

  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontFamily: 'NotoSansArabic')),
      ),
      body: history.isEmpty
          ? Center(
              child: Text(
                'No scans yet.',
                style: TextStyle(color: Color(0xFF333333), fontFamily: 'NotoSansArabic'),
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp);
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn,
                  offset: index == 0 ? Offset(0, 0) : Offset(0, 0),
                  child: ListTile(
                    leading: Icon(Icons.qr_code, color: Color(0xFFB22222)),
                    title: Text(
                      entry.code,
                      style: TextStyle(color: Color(0xFF333333), fontFamily: 'NotoSansArabic'),
                    ),
                    subtitle: Text(
                      formattedDate,
                      style: TextStyle(color: Color(0xFF333333), fontFamily: 'NotoSansArabic'),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Color(0xFFFFFFFF),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  ),
                );
              },
            ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String androidId;
  final String name;
  final String role;

  const ProfileScreen({
    super.key,
    required this.androidId,
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.04;
    final imageSize = screenWidth * 0.25;
    final spacing = screenHeight * 0.02;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'NotoSansArabic')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA9A9A9).withOpacity(0.1),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenHeight * 0.1),
                if (androidId.contains('Firebase Failed') || androidId.contains('Unknown_'))
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Warning: Firebase connection failed. Device ID may be unreliable.',
                      style: TextStyle(
                        color: Color(0xFF8B0000),
                        fontFamily: 'NotoSansArabic',
                        fontSize: fontSize,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Device ID:\n$androidId',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Color(0xFF333333),
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    IconButton(
                      icon: Icon(Icons.copy, size: fontSize * 1.25),
                      onPressed: () {
                        FlutterClipboard.copy(androidId).then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Device ID copied to clipboard',
                                style: TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontFamily: 'NotoSansArabic',
                                ),
                              ),
                            ),
                          );
                        });
                      },
                      tooltip: 'Copy Device ID',
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                Text(
                  'Name: $name',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Color(0xFF333333),
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
                Text(
                  'Role: $role',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Color(0xFF333333),
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
                SizedBox(height: spacing),
                ElevatedButton.icon(
                  icon: Icon(Icons.share, size: fontSize * 1.25),
                  label: Text(
                    'Share Profile',
                    style: TextStyle(fontSize: fontSize, fontFamily: 'NotoSansArabic'),
                  ),
                  onPressed: () {
                    Share.share(
                      'Profile Information:\nDevice ID: $androidId\nName: $name\nRole: $role',
                      subject: 'EL FOULADH Profile',
                    );
                  },
                ),
                SizedBox(height: screenHeight * 0.2),
                Container(
                  child: Image.asset(
                    'assets/logo (1).png',
                    width: imageSize,
                    height: imageSize,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        'Logo failed to load',
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Color(0xFF8B0000),
                          fontFamily: 'NotoSansArabic',
                        ),
                      );
                    },
                    filterQuality: FilterQuality.high,
                  ),
                ),
                SizedBox(height: spacing),
                Text(
                  'EL FOULADH',
                  style: TextStyle(
                    fontSize: fontSize * 1.5,
                    fontWeight: FontWeight.bold,
                  
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
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

class _VideoScreenState extends State<VideoScreen> {
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
    return Scaffold(
      appBar: _controller.value.isFullScreen
          ? null
          : AppBar(
              title: const Text('Instruction Video', style: TextStyle(fontFamily: 'NotoSansArabic')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Color(0xFFB22222),
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