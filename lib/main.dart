import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Firebase Core initialization is skipped locally since we are using mock repositories.
  // It should be initialized under production environments with:
  // await Firebase.initializeApp();

  // Initialize Sentry for unhandled exception tracking (Part G / Step 6)
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://sentry.zeropay.io/123456';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: ZeroPayApp(),
      ),
    ),
  );
}
