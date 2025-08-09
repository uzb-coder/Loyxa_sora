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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF6b6b6b),
        elevation: 2.0,
        title: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
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
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PersonalRestoran(token: widget.token,)));
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(120, 70),
              backgroundColor: Color(0xFFF5F5F5),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey, width: 2),
              ),
              shadowColor: Colors.black.withOpacity(0.2),
              elevation: 6,
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Персонал ресторана'),
          ),
          const SizedBox(width: 5),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => TablesPage(token: widget.token,)));
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(120, 70),
              backgroundColor: Color(0xFFF5F5F5),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey, width: 2),
              ),
              shadowColor: Colors.black.withOpacity(0.2),
              elevation: 6,
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Залы'),
          ),
          const SizedBox(width: 5),
          ElevatedButton(
            onPressed: () {
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(120, 70),
              backgroundColor: Color(0xFFF5F5F5),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey, width: 2),
              ),
              shadowColor: Colors.black.withOpacity(0.2),
              elevation: 6,
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Настройки'),
          ),
          const SizedBox(width: 20),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                    minimumSize: Size(120, 70),
                    backgroundColor: Color(0xFFF5F5F5),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey, width: 2),
                    ),
                    shadowColor: Colors.black.withOpacity(0.2),
                    elevation: 6,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Клиенты'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(token: widget.token,)));

                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(120, 70),
                    backgroundColor: Color(0xFFF5F5F5),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey, width: 2),
                    ),
                    shadowColor: Colors.black.withOpacity(0.2),
                    elevation: 6,
                    padding: EdgeInsets.symmetric(horizontal: 10),
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
                minimumSize: Size(120, 70),
                backgroundColor: Color(0xFFF5F5F5),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey, width: 2),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 6,
                padding: EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Выход'),
            ),
          ],
        ),
      ),
    );
  }
}