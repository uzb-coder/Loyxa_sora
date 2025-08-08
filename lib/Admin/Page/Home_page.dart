import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // intl paketi uchun
import 'dart:async';

import '../../Controller/usersCOntroller.dart';
import 'Blyuda/Blyuda.dart';
import 'Blyuda/Otdel.dart';
import 'Blyuda/Personal_restoran.dart';
import 'Cilnet_page.dart';
import 'Stollar_page.dart'; // Timer uchun


class ManagerHomePage extends StatefulWidget {
  final User user;
  final token;
  const ManagerHomePage({super.key, this.token, required this.user});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  late String _timeString;
  late String _dateString;

  @override
  void initState() {
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    super.initState();
  }

  void _updateTime() {
    final now = DateTime.now();  // Hozirgi vaqtni olamiz

    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(now); // Hozirgi vaqtni formatlaymiz

      // Hozirgi sanani rasmga o'xshatib rus tilida formatlaymiz
      _dateString = DateFormat('EEEE, d MMMM y', 'ru_RU').format(now);
      // Natija: "четверг, 7 августа 2025 г." ko'rinishida bo'ladi

      // Agar "г." qo'shishni xohlasangiz, qo'shishingiz mumkin:
      _dateString = _dateString + " г.";
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5a5a5a), // Orqa fon rangi
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF6b6b6b),
          elevation: 2.0,
          title: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hodim : ${widget.user.firstName} | ${widget.user.lastName}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_dateString\n$_timeString',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalRestoran(token: widget.token,)));
              },
              child: const Text('Персонал ресторана', style: TextStyle(color: Colors.white, fontSize: 20,)),
            ),
            const SizedBox(width: 5),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => TablesPage(token: widget.token,)));
              },
              child: const Text('Залы', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            const SizedBox(width: 5),
            TextButton(
              onPressed: () {},
              child: const Text('Настройки', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          color: const Color(0xFF424242), // Asosiy qismning foni
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        color: const Color(0xFFcccccc),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ClientPage(token: widget.token,)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFe0e0e0),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  ),
                  child: const Text('Клиенты'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(token: widget.token,)));

                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFe0e0e0),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  ),
                  child: const Text('Блюда'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe0e0e0),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              ),
              child: const Text('Выход'),
            ),
          ],
        ),
      ),
    );
  }
}