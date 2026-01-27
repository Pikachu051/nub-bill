import 'package:flutter/material.dart';
<<<<<<< Updated upstream
import 'package:nubbill/pages/authentication_page.dart';
import 'package:nubbill/pages/home_page.dart';
=======
import 'package:nubbill/screens/authentication_page.dart';
import 'package:nubbill/screens/create_group_page.dart';
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
      home: const HomePage(),
=======
      home: const CreateGroupPage(),
>>>>>>> Stashed changes
    );
  }
}
