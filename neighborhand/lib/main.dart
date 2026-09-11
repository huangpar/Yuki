import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'theme/brand_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/booking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Starts downloading now so it overlaps with Supabase setup below.
  final brandFonts = loadBrandFonts().catchError((Object error) {
    debugPrint('Brand font failed to load, using the default font: $error');
  });

  String supabaseUrl = 'https://xqcqcysrdcfdhabvtcwt.supabase.co';
  String supabaseKey = 'sb_publishable_WHzMegyHK_Ol5MiBov24mw_Q-HivOrR';

  // Try to load from dotenv (works on mobile, not guaranteed on web)
  try {
    await dotenv.load();
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? supabaseUrl;
    supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? supabaseKey;
  } catch (e) {
    // Silent fail - use hardcoded values
  }

  final supabaseService = SupabaseService();
  try {
    await supabaseService.initialize(supabaseUrl, supabaseKey);
  } catch (e) {
    print('Supabase initialization error: $e');
    // Continue anyway with uninitialized service
  }

  try {
    await brandFonts.timeout(const Duration(seconds: 3));
  } catch (_) {
    // Slow network: start with the default font; Museo Sans swaps in once it arrives.
  }

  runApp(const YukiApp());
}

class YukiApp extends StatelessWidget {
  const YukiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yuki',
      theme: appTheme,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/signin': (context) => const AuthScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Also covers returning from Google/Apple sign-in, which reloads the app signed in.
    if (SupabaseService.instance.getCurrentUser() != null) {
      await finishSignIn(context);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Yuki',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
