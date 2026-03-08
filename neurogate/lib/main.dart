import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_tab.dart'; // We will create this next
import 'screens/parent_portal_tab.dart'; // We will create this next

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const NeuroGateLauncher(),
    ),
  );
}

class NeuroGateLauncher extends StatelessWidget {
  const NeuroGateLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NeuroGate',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate-900
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.isInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (appState.googleAccessToken.isEmpty) {
            return const LoginScreen();
          }
          
          return const MainNavigator();
        },
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const ParentPortalTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95), // Slate-800
          selectedItemColor: Colors.blue.shade400,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.security),
              label: 'Parent',
            ),
          ],
        ),
      ),
    );
  }
}
