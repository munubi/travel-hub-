import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screen imports
import 'screens/login_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/email_verification_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/preferences_page.dart';
import 'screens/first_time_home_page.dart';
import 'screens/bottom_nav_bar.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('Error initializing app: $e');
    // Show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Xplore',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData) {
              return const MainScreen();
            }

            return const LoginPage();
          },
        ),
        routes: {
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/email-verification': (context) => const EmailVerificationPage(),
          '/preferences': (context) => const PreferencesPage(),
          '/first-time-home': (context) => const FirstTimeHomePage(),
          '/home': (context) => const MainScreen(),
        },
      ),
    );
  }
}
