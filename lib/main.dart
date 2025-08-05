import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- MUHIM O'ZGARISH
import 'package:intl/intl.dart';

import 'Page/Categorya.dart';
import 'Page/Example.dart';
import 'Page/Home.dart';
import 'Page/Login.dart';
import 'Page/Users_page.dart';

void main() async { // <-- MUHIM O'ZGARISH
  WidgetsFlutterBinding.ensureInitialized(); // <-- MUHIM O'ZGARISH
  await initializeDateFormatting('uz', null); // <-- MUHIM O'ZGARISH
  runApp(const MyApp());
}

// Asosiy ilova vidjeti
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
      home: UserListPage(),
    );
  }
}

