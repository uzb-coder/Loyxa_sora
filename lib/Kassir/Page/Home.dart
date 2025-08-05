import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../Controller/usersCOntroller.dart';
import 'Kassr_page.dart';

class KassrPage extends StatelessWidget {
   final User user;

  const KassrPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Кассир: ${user.firstName}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d5720), Color(0xFF145c25), Color(0xFF1b7a33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: Center(child: ClockWidget())),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GradientButton(
                      text: 'Вс счета',
                      colors: [Colors.orange, Colors.deepOrange],
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Kassr_Page(user: user)),
                        );
                      },
                    ),
                    GradientButton(
                      text: 'Выход',
                      colors: [Colors.pink, Colors.redAccent],
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClockWidget extends StatefulWidget {

  @override
  _ClockWidgetState createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
  }

  void _updateTime() {
    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(DateTime.now());
    });
    Future.delayed(Duration(seconds: 1), _updateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [Colors.cyanAccent, Colors.teal],
          center: Alignment(0.0, 0.0),
          radius: 0.8,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.7),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white70, width: 4),
      ),
      child: Center(
        child: Text(
          _timeString,
          style: TextStyle(
            fontSize: 65,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(2, 2),
              ),
              Shadow(
                color: Colors.tealAccent,
                blurRadius: 15,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final VoidCallback onPressed;

  const GradientButton({
    required this.text,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
