import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/environment.dart';
import 'core/config/environment_provider.dart';
import 'core/config/firebase_options_selector.dart';
import 'features/onboarding/presentation/screens/onboarding_first_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = resolveEnvironment();
  await Firebase.initializeApp(options: firebaseOptionsFor(environment));
  runApp(
    ProviderScope(
      overrides: [environmentProvider.overrideWithValue(environment)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PosterNung',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const OnboardingFirstScreen(),
    );
  }
}
