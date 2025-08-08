import 'package:flutter/material.dart';
import 'Page/Users_page.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Orqa fon rasmi
          Positioned.fill(
            child: Image.asset(
              'assets/rasm/sora_logo_black.png',
              fit: BoxFit.cover,
            ),
          ),

          /// Qorong‘iroq qatlam (background ustiga yarim shaffof qora)
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          /// Tugma markazda
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserListPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                textStyle: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              child: const Text("KIRISH"),
            ),
          ),
        ],
      ),
    );
  }
}
