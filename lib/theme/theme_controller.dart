import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  /// Load saved theme on app start (from SharedPreferences and Firestore)
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    // Try Firestore first if user is signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final firestoreTheme = userDoc.data()?['themeMode']?.toString();
        if (firestoreTheme == 'dark' || firestoreTheme == 'light') {
          final themeStr = firestoreTheme!;
          _themeMode = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
          await prefs.setString(_key, themeStr);
          notifyListeners();
          return;
        }
      } catch (_) {
        // Fallback to SharedPreferences if Firestore fails
      }
    }

    // Fallback to SharedPreferences
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Toggle theme (saves to SharedPreferences and Firestore)
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      await prefs.setString(_key, 'dark');
    } else {
      _themeMode = ThemeMode.light;
      await prefs.setString(_key, 'light');
    }

    // Sync to Firestore if user is signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'themeMode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
        }, SetOptions(merge: true));
      } catch (_) {
        // Silently fail if Firestore update fails (SharedPreferences is saved)
      }
    }

    notifyListeners();
  }
}
