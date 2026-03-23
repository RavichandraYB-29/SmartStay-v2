// ──────────────────────────────────────────────────────────────────────────
// firebase_options.example.dart
// ──────────────────────────────────────────────────────────────────────────
// This is a TEMPLATE file. The real firebase_options.dart is excluded from
// version control for security reasons.
//
// HOW TO SET UP:
//   1. Create a Firebase project at https://console.firebase.google.com
//   2. Install FlutterFire CLI:
//        dart pub global activate flutterfire_cli
//   3. Run from the project root:
//        flutterfire configure
//      This will auto-generate lib/firebase_options.dart with your real keys.
//
//   Alternatively, copy this file to lib/firebase_options.dart and replace
//   every 'YOUR_*_HERE' placeholder with your actual Firebase project values.
// ──────────────────────────────────────────────────────────────────────────

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('FirebaseOptions are not configured for iOS.');
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseOptions are not configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError('FirebaseOptions are not configured for Linux.');
      default:
        throw UnsupportedError(
          'FirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// 🔵 WEB Firebase config
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY_HERE',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    projectId: 'YOUR_PROJECT_ID_HERE',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    appId: 'YOUR_WEB_APP_ID_HERE',
    measurementId: 'YOUR_MEASUREMENT_ID_HERE',
  );

  /// 🤖 ANDROID Firebase config
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY_HERE',
    appId: 'YOUR_ANDROID_APP_ID_HERE',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    projectId: 'YOUR_PROJECT_ID_HERE',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );

  /// 🍎 macOS Firebase config
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY_HERE',
    appId: 'YOUR_MACOS_APP_ID_HERE',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID_HERE',
    projectId: 'YOUR_PROJECT_ID_HERE',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );
}
