import 'package:flutter/material.dart';
import 'package:nubbill/pages/authentication_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nub-Bill',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 129, 206, 242)),
        fontFamily: 'LineSeedSansTH',
      ),
      home: const AuthenticationPage(),
    );
  }
}
