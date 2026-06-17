import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/driver_provider.dart';
import '../home/home_screen.dart';
import '../earnings/earnings_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';
import '../orders/new_order_screen.dart';
import '../orders/active_delivery_screen.dart';

// Approximate rendered height of the ActiveDeliveryScreen compact bar.
// Compact header padding (12+10) + row content (~52px) = ~74px.
const double _kCompactBarHeight = 74.0;

class MainNavShell extends StatefulWidget {
  const MainNavShell({super.key});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _index = 0;
  late final List<Widget> _screens;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
    NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Earnings'),
    NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onTabSwitch: (i) => setState(() => _index = i)),
      const EarningsScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final systemBottom = MediaQuery.of(context).padding.bottom;

    // When the compact delivery bar is visible, push the new order card up
    // so its Accept/Decline buttons are never hidden underneath it.
    final newOrderBottom = (driver.hasActiveDelivery && _index == 0)
        ? _kCompactBarHeight + systemBottom
        : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _screens[_index]),

          // Active delivery — drawn first so new order card appears on top
          if (driver.hasActiveDelivery && _index == 0)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: const ActiveDeliveryScreen(),
              ),
            ),

          // Incoming order — drawn last (topmost), shifted up above compact bar
          if (driver.hasIncomingOrder)
            Positioned(
              bottom: newOrderBottom,
              left: 0,
              right: 0,
              child: NewOrderScreen(atBottom: newOrderBottom == 0),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}
