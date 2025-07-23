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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA9A9A9).withOpacity(1),  
              Color(0xFFFFFFFF), 
            ],
          ),
           image: DecorationImage(
             image: AssetImage('assets/gueriage.png'),
             fit: BoxFit.cover,
             opacity: 0.5,
           ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo2.png',
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    'Logo failed to load',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF8B0000),  
                      
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'EL FOULADH ScanGuide',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}