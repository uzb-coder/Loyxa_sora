import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'Page/Users_page.dart'; // Keyingi sahifangiz

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late String _timeString;
  late String _dateString;
  late Timer _timer;

  @override
  void initState() {
    // O'zbek tilidagi sana formatlari uchun
    initializeDateFormatting('uz_UZ', null);

    _timeString = _formatDateTime(DateTime.now(), 'HH:mm');
    _dateString = _formatDateTime(DateTime.now(), 'EEEE, d MMMM, yyyy');

    // Har soniyada vaqtni yangilab turish uchun taymer
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel(); // Sahifadan chiqilganda taymerni to'xtatish
    super.dispose();
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = _formatDateTime(now, 'HH:mm:ss'); // :ss qo'shildi
    final String formattedDate = _formatDateTime(now, 'EEEE, d MMMM, yyyy');

    setState(() {
      _timeString = formattedTime;
      _dateString = formattedDate;
    });
  }

  String _formatDateTime(DateTime dateTime, String format) {
    // Sana va vaqtni O'zbek tilida (Lotin alifbosida) formatlash
    return DateFormat(format, 'uz_UZ').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Orqa fon uchun chiroyli gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffcacdce), Color(0xffd2c9c9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Elementlarni vertikal tekislash
            children: <Widget>[
              const SizedBox(), // Yuqorida bo'sh joy qoldirish uchun

              // Soat va Sana
              Column(
                children: [
                  // Katta RAQAMLI SOAT
                  Text(
                    _timeString,
                    style: TextStyle(
                      fontFamily: 'Roboto', // Siz boshqa shrift ham tanlashingiz mumkin
                      fontWeight: FontWeight.w200, // Yupqa, elegant shrift
                      fontSize: 120,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // SANA
                  Text(
                    _dateString,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),

              // KIRISH TUGMASI va LOGOTIP
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserListPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0d5720), // Siz aytgan yashil rang
                      minimumSize: const Size(double.infinity, 60), // Keng tugma
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Kirish'),
                  ),
                  const SizedBox(height: 40),
                  // LOGOTIP
                  Image.asset(
                    'assets/images/logo.png',
                    height: 50, // O'lchamini moslashtiring
                    color: Colors.white.withOpacity(0.5), // Logotipni oqartirish
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}