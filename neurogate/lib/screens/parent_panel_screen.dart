import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import 'parent_panel/dashboard_tab.dart';
import 'parent_panel/app_rules_tab.dart';
import 'parent_panel/system_tab.dart';

/// The Parent Control Panel.
///
/// On first display, a PIN screen is shown (via `flutter_screen_lock`).
/// After successful authentication the 3-tab scaffold is revealed.
class ParentPanelScreen extends StatefulWidget {
  const ParentPanelScreen({super.key});

  @override
  State<ParentPanelScreen> createState() => _ParentPanelScreenState();
}

class _ParentPanelScreenState extends State<ParentPanelScreen> {
  bool _authenticated = false;
  int _currentTab = 0;

  final List<Widget> _tabs = const [
    DashboardTab(),
    AppRulesTab(),
    SystemTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Show the PIN lock after the first frame so the context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_authenticated) _showPinLock();
    });
  }

  void _showPinLock() {
    final appState = Provider.of<AppState>(context, listen: false);

    screenLock(
      context: context,
      correctString: appState.parentPin,
      canCancel: true,
      title: const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Enter Parent PIN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      config: ScreenLockConfig(
        backgroundColor: const Color(0xFF0F172A),
      ),
      secretsConfig: SecretsConfig(
        spacing: 20,
        secretConfig: SecretConfig(
          borderColor: Colors.indigoAccent,
          enabledColor: Colors.indigoAccent,
          disabledColor: Colors.white24,
          borderSize: 2,
          size: 14,
        ),
      ),
      keyPadConfig: KeyPadConfig(
        buttonConfig: KeyPadButtonConfig(
          buttonStyle: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
        ),
      ),
      onCancelled: Navigator.of(context).pop,
      onUnlocked: () {
        // Dismiss the lock screen overlay.
        Navigator.of(context).pop();
        setState(() => _authenticated = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      // Show a blank dark screen while the lock overlay is visible.
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _tabs[_currentTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
          selectedItemColor: Colors.indigoAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps),
              label: 'App Rules',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'System',
            ),
          ],
        ),
      ),
    );
  }
}
