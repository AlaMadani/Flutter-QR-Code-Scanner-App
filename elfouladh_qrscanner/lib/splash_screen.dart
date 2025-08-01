import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF1E1E1E).withOpacity(0.1),
                    Color(0xFF121212),
                  ]
                : [
                    Color(0xFFFFFFFF).withOpacity(0.1),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo2.png',
                width: 140,
                height: 140,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    'Logo failed to load',
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.error,
                      fontFamily: 'NotoSansArabic',
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'EL FOULADH ScanGuide',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSansArabic',
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}