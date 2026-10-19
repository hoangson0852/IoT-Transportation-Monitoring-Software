import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

// Screens
import 'screens/login.dart';
import 'screens/home/home.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/success_update_screen.dart';
import 'screens/connect_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmmoMonitorApp());
}

class AmmoMonitorApp extends StatelessWidget {
  const AmmoMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Ammo Monitor',
            debugShowCheckedModeBanner: false,
            // =============================
            // LIGHT THEME
            // =============================
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
            ),
            // =============================
            // DARK THEME
            // =============================
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue,
              ),
            ),
            themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            home: const _AuthGate(),
            routes: {
              "/login": (_) => const LoginScreen(),
              "/profile": (_) => const ProfileScreen(),
              "/edit_profile": (_) => const EditProfileScreen(),
              "/change_password": (_) => const ChangePasswordScreen(),
              "/success_update": (_) => const SuccessUpdateScreen(),
              "/esp32_setup": (_) => const ConnectScreen(),
            },
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const _SplashScreen();
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D2533);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1C70D1), width: 1.5),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF1C70D1),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AMMO MONITOR',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hệ thống giám sát vận chuyển đạn dược',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1C70D1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
