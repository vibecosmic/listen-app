import 'package:flutter/material.dart';

void main() => runApp(const ListenApp());

class ListenApp extends StatelessWidget {
  const ListenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Listen',
      home: Scaffold(
        body: Center(child: Text('Listen — coming soon')),
      ),
    );
  }
}
