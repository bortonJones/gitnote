import 'package:flutter/material.dart';

import '../features/home_gate.dart';

class GitNoteApp extends StatelessWidget {
  const GitNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeGate(),
    );
  }
}
