import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/app.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final SharedPreferences sharedPreferences;
  try {
    sharedPreferences = await SharedPreferences.getInstance();
  } on Exception catch (e) {
    debugPrint('Failed to initialize SharedPreferences: $e');
    runApp(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Failed to initialize app storage. Please restart.'),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Load auth tokens from platform-secure storage into the in-memory cache
  // before the app reads them (the Dio auth interceptor reads synchronously).
  final localStorage = LocalStorage(sharedPreferences);
  await localStorage.initSecureAuth();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const EvToolApp(),
    ),
  );
}
