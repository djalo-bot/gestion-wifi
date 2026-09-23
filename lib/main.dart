import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/ticket_repository.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/report/report_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/stock/stock_screen.dart';

void main() {
  runApp(const GestionWifiApp());
}

class GestionWifiApp extends StatelessWidget {
  const GestionWifiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<TicketRepository>(
      create: (_) => TicketRepository(),
      child: MaterialApp(
        title: 'Gestion Wi-Fi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    PosScreen(),
    StockScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Caisse',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Bilan',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}
