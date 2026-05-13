import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_screen.dart';


const String _kGistRawUrl = 'https://gist.githubusercontent.com/ImJawadHossain/d08819180aeb7c154720b7ebd9999057/raw/status.json';

void main() {
  // Ensure widgets are bound
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make status bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const DigitalTasbihApp());
}

class DigitalTasbihApp extends StatelessWidget {
  const DigitalTasbihApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Tasbih',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AppInitializer(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF),    // Cyan accent
        onPrimary: Color(0xFF001F24),
        secondary: Color(0xFFB388FF),  // Purple accent
        onSecondary: Color(0xFF2A0054),
        tertiary: Color(0xFF1DE9B6),   // Teal accent
        onTertiary: Color(0xFF002019),
        surface: Color(0xFF121212),    // Dark background
        onSurface: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFF1E1E1E), 
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

/// This acts as a Splash Screen while strictly checking the Kill Switch online
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    try {
      if (_kGistRawUrl.contains('YOUR_GIST')) {
        // If developer hasn't set URL yet, let it pass
        _proceed(true, ['Md Jawad Hossain'], 'Khulna Polytechnic Institute');
        return;
      }

      final urlWithBuster = '$_kGistRawUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(urlWithBuster)).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool isActive = data['status'] == 'active';
        
        List<String> developers = [];
        if (data.containsKey('developers') && data['developers'] is List) {
          developers = List<String>.from(data['developers']);
        } else {
          // Fallback parsing if they use developer1, developer2 format
          if (data.containsKey('developer1')) developers.add(data['developer1'].toString());
          if (data.containsKey('developer2')) developers.add(data['developer2'].toString());
        }

        if (developers.isEmpty) {
          developers = ['Md Jawad Hossain']; // Absolute fallback
        }

        String university = data['university']?.toString() ?? 'North Western University';

        // Add a tiny delay just so the splash screen feels smooth
        await Future.delayed(const Duration(milliseconds: 500));
        _proceed(isActive, developers, university);
        return;
      }
    } on FormatException catch (e) {
      // Invalid JSON syntax in the Gist
      debugPrint('JSON Syntax Error in Gist: $e');
      _proceed(false, [], '');
      return;
    } catch (e) {
      // Internet failed or timeout — NO CACHE fallback allowed!
      debugPrint('Network Error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const _NoInternetScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return;
    }

    // Default error catch-all
    _proceed(false, [], '');
  }

  void _proceed(bool isActive, List<String> developers, String university) {
    if (!mounted) return;
    
    if (isActive) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainScreen(
            developers: developers,
            university: university,
          ),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const _CriticalErrorScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mosque_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Screen shown when no internet is available
class _NoInternetScreen extends StatelessWidget {
  const _NoInternetScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 80, color: Colors.orange[300]),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please connect to the internet to use Digital Tasbih.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, height: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AppInitializer()),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fake "Crash" screen to trick the client if they are blocked
class _CriticalErrorScreen extends StatelessWidget {
  const _CriticalErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 80, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 24),
            Text(
              'Fatal Exception',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'There is a critical bug in the app, please contact with developer Md Jawad Hossain.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_rounded, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Text(
                    'WhatsApp: 01402633318',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
