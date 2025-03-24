import 'dart:io';
import 'package:flutter/foundation.dart'; // для kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pattern_3/pages/main_menu.dart';
import 'package:pattern_3/pages/authorization.dart';
import 'package:pattern_3/pages/orders.dart';
import 'package:pattern_3/pages/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  await Firebase.initializeApp(options: firebaseOptions);

  // Инициализация SQLite в зависимости от платформы
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MaterialApp(
    initialRoute: '/',
    onGenerateRoute: (settings) {
      if (settings.name == '/main_menu') {
        final String userEmail = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => MainMenu(userEmail: userEmail),
        );
      } else if (settings.name == '/orders') {
        final String userEmail = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => Orders(userEmail: userEmail),
        );
      } else if (settings.name == '/services') {
        return MaterialPageRoute(
          builder: (context) => const Services(),
        );
      }
      return MaterialPageRoute(builder: (context) => const Authorization());
    },
  ));
}
