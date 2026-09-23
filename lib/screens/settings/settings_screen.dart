import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('Réglages')),
      body: Center(child: Text('Réglages de l’application')),
    );
  }
}
