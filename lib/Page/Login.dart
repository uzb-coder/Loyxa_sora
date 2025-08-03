import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

import '../Controller/usersCOntroller.dart';
import '../Example.dart';
import 'Home.dart';
import 'Users_page.dart';

class LoginScreen extends StatefulWidget {
  final User user;

  const LoginScreen({super.key, required this.user});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late String _timeString;
  late String _dateString;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('H : mm : ss').format(now);
      _dateString =
          toBeginningOfSentenceCase(
            DateFormat("EEEE, d MMMM y 'г.'", 'ru').format(now),
          )!;
    });
  }

  void _onKeyPressed(String value) {
    if (value == 'delete') {
      if (_pinController.text.isNotEmpty) {
        _pinController.text = _pinController.text.substring(
          0,
          _pinController.text.length - 1,
        );
      }
    } else {
      _pinController.text += value;
    }
  }

  final String baseUrl = "https://sora-b.vercel.app/api";

  String? _errorMessage;

  Future<void> _login() async {
    final pin = _pinController.text.trim();

    if (widget.user.userCode.isEmpty || pin.isEmpty) {
      setState(() {
        _errorMessage = "Iltimos, barcha maydonlarni to'ldiring.";
      });
      return;
    }

    try {
      final loginUrl = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': widget.user.userCode, 'password': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        print("Token: $token");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Muvaffaqiyatli kirdingiz!')),
        );
        // ✅ HOME PAGE ga o'tkazish
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PosScreen(user: widget.user)),
        );
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['message'] ?? 'Login amalga oshmadi.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Xatolik yuz berdi: $e';
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Orqa fon rasmi
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://i.stack.imgur.com/Hl52W.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildClock(),
                  const SizedBox(height: 30),
                  _buildLoginPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            _timeString,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _dateString,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEFF2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildUserInfo(),
          const SizedBox(height: 15),
          _buildPinField(),
          const SizedBox(height: 20),
          _buildNumpad(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // ✅ const olib tashlandi
          const Icon(Icons.person, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.user.firstName} ${widget.user.lastName}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Text(
                '${widget.user.role}', // ✅ endi ishlaydi
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinField() {
    return TextField(
      controller: _pinController,
      readOnly: true,
      showCursor: true,
      cursorColor: Colors.black,
      textAlign: TextAlign.center,
      obscureText: true,
      obscuringCharacter: '•',
      style: const TextStyle(fontSize: 24, letterSpacing: 10),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final List<String> keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'Стереть',
      '0',
      'delete',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        return _buildNumpadButton(keys[index]);
      },
    );
  }

  Widget _buildNumpadButton(String key) {
    if (key == 'delete') {
      return ElevatedButton(
        onPressed: () => _onKeyPressed('delete'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD6DADE),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.all(16),
        ),
        child: const Icon(Icons.backspace_outlined),
      );
    }

    bool isClearButton = key == 'Стереть';

    return ElevatedButton(
      onPressed: () {
        if (isClearButton) {
          _pinController.clear();
        } else {
          _onKeyPressed(key);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isClearButton ? const Color(0xFFD6DADE) : const Color(0xFFF7F8FA),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      child: Text(key),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserListPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Назад',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Вход',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
