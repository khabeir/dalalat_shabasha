import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'services/visitor_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const DalalatShabshaApp());
}

class DalalatShabshaApp extends StatefulWidget {
  const DalalatShabshaApp({super.key});

  @override
  State<DalalatShabshaApp> createState() => _DalalatShabshaAppState();
}

class _DalalatShabshaAppState extends State<DalalatShabshaApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _startVisitorTracking();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed) {
          _startVisitorTracking();
        }

        if (event == AuthChangeEvent.signedOut) {
          VisitorTrackingService.instance.dispose();
        }
      },
    );
  }

  Future<void> _startVisitorTracking() async {
    await VisitorTrackingService.instance.start();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    VisitorTrackingService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دلالة شبشة',
      theme: ThemeData(
        useMaterial3: true,
      ),
      locale: const Locale('ar'),
      home: const HomeScreen(),
    );
  }
}