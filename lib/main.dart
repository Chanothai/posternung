import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/environment.dart';
import 'core/config/environment_provider.dart';
import 'core/config/firebase_options_selector.dart';
import 'core/router/app_router.dart';
import 'core/strings/app_strings.dart';

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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `MaterialApp.router` rather than `home:` — the first screen is now the
    // `/` entry in the route table, not a widget named here (ADR-0018).
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
