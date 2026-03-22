// File generated manually — replace the TODO values with your Firebase config.
// Steps:
//  1. Open https://console.firebase.google.com/project/agri-app-b1664/settings/general
//  2. Scroll to "Your apps" → click your Web app (or add one with "Add app" > Web icon)
//  3. Under "SDK setup and configuration" select "Config"
//  4. Copy the values from the firebaseConfig object shown there
//
// Values to replace below:
//   YOUR_API_KEY          → apiKey  (e.g. "AIzaSy...")
//   YOUR_APP_ID           → appId   (e.g. "1:123456:web:abc123")
//   YOUR_MESSAGING_SENDER_ID → messagingSenderId (e.g. "123456789")
//   YOUR_MEASUREMENT_ID   → measurementId (e.g. "G-XXXXXXXX")  ← optional

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
        return ios;
      case TargetPlatform.windows:
        // Windows uses the Web app configuration
        return windows;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Web / Windows config ──────────────────────────────────────────────────
  // Replace all TODO values from Firebase Console → Project Settings → Your Apps → Web App
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD69Dcxai8SoGED0ezEXD_EOTtS8Eep4eo',
    appId: '1:673280040137:web:55ff643db1f08ee5d38118',
    messagingSenderId: '673280040137',
    projectId: 'agri-app-b1664',
    authDomain: 'agri-app-b1664.firebaseapp.com',
    storageBucket: 'agri-app-b1664.firebasestorage.app',
    measurementId: 'G-BQQCQPK1CW',
  );

  // Windows uses the same Web app configuration as Firebase has no native Windows SDK
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD69Dcxai8SoGED0ezEXD_EOTtS8Eep4eo',
    appId: '1:673280040137:web:55ff643db1f08ee5d38118',
    messagingSenderId: '673280040137',
    projectId: 'agri-app-b1664',
    authDomain: 'agri-app-b1664.firebaseapp.com',
    storageBucket: 'agri-app-b1664.firebasestorage.app',
    measurementId: 'G-BQQCQPK1CW',
  );

  // ── Android config ────────────────────────────────────────────────────────
  // If you registered an Android app, use its values here (apiKey and appId differ)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD69Dcxai8SoGED0ezEXD_EOTtS8Eep4eo',
    appId: '1:673280040137:web:55ff643db1f08ee5d38118',
    messagingSenderId: '673280040137',
    projectId: 'agri-app-b1664',
    storageBucket: 'agri-app-b1664.firebasestorage.app',
  );

  // ── iOS config ────────────────────────────────────────────────────────────
  // If you registered an iOS app, use its values here
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD69Dcxai8SoGED0ezEXD_EOTtS8Eep4eo',
    appId: '1:673280040137:web:55ff643db1f08ee5d38118',
    messagingSenderId: '673280040137',
    projectId: 'agri-app-b1664',
    storageBucket: 'agri-app-b1664.firebasestorage.app',
    iosBundleId: 'com.example.agriApp',
  );
}
