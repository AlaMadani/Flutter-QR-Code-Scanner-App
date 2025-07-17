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
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const QRScannerApp());
}

class QRScannerApp extends StatelessWidget {
  const QRScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
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
  final List<String> _scanHistory = [];
  String _deviceId = 'Loading...';
  String _userName = '';
  String _userRole = '';
  String? _videoUrl;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    WidgetsBinding.instance.addObserver(this); // Add observer for orientation
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle orientation changes after the frame is built
    if (_selectedIndex == 0 && _videoUrl != null) {
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      if (isLandscape != _isFullScreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isFullScreen = isLandscape;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up observer
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final id = await getDeviceId();
    setState(() {
      _deviceId = id;
    });

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get();
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
      _scanHistory.insert(0, code);
    });
    _fetchVideoForScan(code);
  }

  void _onFullScreenChanged(bool isFullScreen) {
    // Defer setState to avoid build-time errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isFullScreen = isFullScreen;
      });
    });
  }

  Future<void> _fetchVideoForScan(String qrCode) async {
    final key = '${qrCode}_${_userRole.trim().toLowerCase()}';
    final doc = await FirebaseFirestore.instance
        .collection('videos')
        .doc(key)
        .get();
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
        const SnackBar(content: Text('No video found for this scan and role')),
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
      //appBar: _isFullScreen ? null : AppBar(title: const Text('EL FOULADH')),
      body: _screens[_selectedIndex],
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
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
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

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
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
      duration: const Duration(seconds: 2),
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
      appBar: AppBar(title: const Text('QR Code Scanner')),
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
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      const Text(
                        'Zoom: ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _zoomFactor,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white54,
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
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final linePosition =
                        cameraHeight * (0.2 + 0.6 * _lineAnimation.value);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: linePosition,
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Container(height: 2, color: Colors.red),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Text(
              qrCode,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<String> history;
  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.isEmpty
          ? const Center(child: Text('No scans yet.'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text(history[index]),
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
    // Get screen dimensions for responsive sizing
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate dynamic font size and image size based on screen width
    final fontSize = screenWidth * 0.04; // Scales to ~16px on 400px-wide screen
    final imageSize =
        screenWidth * 0.25; // Scales to ~100px on 400px-wide screen
    final spacing =
        screenHeight * 0.02; // Scales to ~10-20px depending on screen height

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.1), // 5% of screen height
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Device ID:\n$androidId',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: fontSize),
                  ),
                  SizedBox(width: screenWidth * 0.02), // 2% of screen width
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: fontSize * 1.25,
                    ), // Slightly larger than text
                    onPressed: () {
                      FlutterClipboard.copy(androidId).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device ID copied to clipboard'),
                          ),
                        );
                      });
                    },
                    tooltip: 'Copy Device ID',
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Text('Name: $name', style: TextStyle(fontSize: fontSize)),
              Text('Role: $role', style: TextStyle(fontSize: fontSize)),
              SizedBox(height: spacing),
              ElevatedButton.icon(
                icon: Icon(Icons.share, size: fontSize * 1.25),
                label: Text(
                  'Share Profile',
                  style: TextStyle(fontSize: fontSize),
                ),
                onPressed: () {
                  Share.share(
                    'Profile Information:\nDevice ID: $androidId\nName: $name\nRole: $role',
                    subject: 'EL FOULADH Profile',
                  );
                },
              ),
              SizedBox(height: screenHeight * 0.2), // 10% of screen height
              Image.asset(
                'assets/logo (1).png', // Renamed to avoid spaces
                width: imageSize,
                height: imageSize,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    'Logo failed to load',
                    style: TextStyle(fontSize: fontSize, color: Colors.red),
                  );
                },
              ),
              SizedBox(height: spacing),
              Text(
                'EL FOULADH',
                style: TextStyle(
                  fontSize: fontSize * 1.5, // Larger for emphasis
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.05), // Bottom padding
            ],
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
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? 'Unknown_Android_ID';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'Unknown_iOS_ID';
    } else {
      return 'Unsupported_Platform';
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
  bool _lastFullScreenState =
      false; // Track last full-screen state to avoid redundant updates

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    _controller =
        YoutubePlayerController(
          initialVideoId: videoId ?? '',
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: true,
          ),
        )..addListener(() {
          // Only notify if full-screen state changes
          if (_controller.value.isFullScreen != _lastFullScreenState) {
            _lastFullScreenState = _controller.value.isFullScreen;
            WidgetsBinding.instance.addPostFrameCallback((_) {
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
              title: const Text('Instruction Video'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          onReady: () {
            // Notify initial full-screen state after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_controller.value.isFullScreen != _lastFullScreenState) {
                _lastFullScreenState = _controller.value.isFullScreen;
                widget.onFullScreenChanged?.call(
                  _controller.value.isFullScreen,
                );
              }
            });
          },
        ),
      ),
    );
  }
}
