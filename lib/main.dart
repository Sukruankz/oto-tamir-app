import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'theme/app_theme.dart';

// `flutterfire configure` bu dosyayı otomatik üretir (Faz 2).
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OtoTamirApp());
}

class OtoTamirApp extends StatelessWidget {
  const OtoTamirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OtoTamir SaaS Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Firebase Auth durumuna göre Login veya Dashboard'a yönlendirir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return FutureBuilder<AppUser?>(
          future: authService.currentAppUser(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return DashboardScreen(user: userSnapshot.data!);
          },
        );
      },
    );
  }
}
