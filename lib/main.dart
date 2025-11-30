import 'package:flutter/material.dart';
import 'splash/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'services/session_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/admin_notification_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment variables first
  await SupabaseConfig.initialize();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize session service
  await SessionService.initialize();

  // Initialize realtime notification service
  await RealtimeNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print(
      'DEBUG: App lifecycle state changed from $_appLifecycleState to $state',
    );

    // Handle app lifecycle state changes for notifications
    if (state == AppLifecycleState.detached) {
      print(
        'DEBUG: App detached (force closed) - stopping all notifications',
      );
      // Stop listening to realtime events when app is closed
      RealtimeNotificationService.stopListening();
      AdminNotificationService.stopListening();
    } else if (state == AppLifecycleState.paused) {
      // App is in background but still running
      // Keep listening to notifications
      print('DEBUG: App paused - notifications will continue');
    } else if (state == AppLifecycleState.resumed) {
      // App is back in foreground
      // Restart listening if needed
      print('DEBUG: App resumed - restarting notifications if needed');
      RealtimeNotificationService.restartListening();
      
      // Restart admin notifications if admin is logged in
      if (SessionService.isAdmin) {
        print('DEBUG: Admin detected - restarting admin notifications');
        AdminNotificationService.restartListening();
      }
    }

    _appLifecycleState = state;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eCampusPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
