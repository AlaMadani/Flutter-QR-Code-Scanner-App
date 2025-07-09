import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:firebase_core/firebase_core.dart';

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
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<String> _scanHistory = [];
  String _deviceId = 'Loading...';
  String _userName = '';
  String _userRole = '';
  String? _videoUrl; // Track video URL for VideoScreen

  @override
  void initState() {
    super.initState();
    _initializeUser();
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
      _videoUrl = null; // Clear video when switching tabs
    });
  }

  void _addToHistory(String code) {
    setState(() {
      _scanHistory.insert(0, code);
    });
    _fetchVideoForScan(code);
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
        setState(() {
          _videoUrl = url; // Set video URL to show VideoScreen
          _selectedIndex = 0; // Stay on scanner tab (or adjust as needed)
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
                  _videoUrl = null; // Return to QRScannerScreen
                });
              },
            )
          : QRScannerScreen(onScan: _addToHistory),
      HistoryScreen(history: _scanHistory),
      ProfileScreen(androidId: _deviceId, name: _userName, role: _userRole),
    ];

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
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

class _QRScannerScreenState extends State<QRScannerScreen> {
  String qrCode = 'Scan a QR code';
  bool _isScanning = true;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void didUpdateWidget(covariant QRScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      _isScanning = true;
      qrCode = 'Scan a QR code';
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Scanner')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
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
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                qrCode,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Device ID:\n$androidId', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Name: $name'),
            Text('Role: $role'),
          ],
        ),
      ),
    );
  }
}

Future<String> getDeviceId() async {
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

class VideoScreen extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onClose; // Add callback for closing
  const VideoScreen({super.key, required this.videoUrl, this.onClose});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruction Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose, // Trigger onClose to return to scanner
        ),
      ),
      body: Center( // Center the video
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
        ),
      ),
    );
  }
}