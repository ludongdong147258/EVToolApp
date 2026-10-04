import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ev_tool_app/app.dart';
import 'package:ev_tool_app/core/storage/key_value_store.dart';
import 'package:ev_tool_app/core/storage/local_storage.dart';
import 'package:ev_tool_app/features/pro/data/pro_repository.dart';

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

  final localStorage = LocalStorage(sharedPreferences);

  // Pro 订阅（RevenueCat）：缺 key 时静默降级为全功能解锁（dev 模式）。
  await initRevenueCat(SharedPrefsKeyValueStore(sharedPreferences));

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
