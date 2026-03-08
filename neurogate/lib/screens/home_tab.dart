import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../widgets/interceptor_dialog.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const platform = MethodChannel('com.neurogate/apps');
  List<dynamic> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    try {
      final List<dynamic>? result = await platform.invokeMethod('getInstalledApps');
      if (mounted) {
        setState(() {
          _apps = result ?? [];
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get apps: '\${e.message}'.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleAppLaunch(Map<dynamic, dynamic> app, AppState appState) async {
    final String packageName = app['packageName'];
    final bool isLocked = appState.isAppLocked(packageName);

    if (isLocked && appState.timeBank <= 0) {
      debugPrint("App is locked and timeBank is 0! Triggering interceptor.");
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => InterceptorDialog(
          targetApp: app,
          onSuccess: () {
            // Trigger app launch on success
            _launchApp(packageName, appState, isLocked);
          },
        ),
      );
    } else {
      _launchApp(packageName, appState, isLocked);
    }
  }

  Future<void> _launchApp(String packageName, AppState appState, bool isLocked) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
      if (isLocked) {
        // If locked but they have time, deduct time
        // We can start a timer or deduct per launch for MVP
        // For now let's deduct 1 min per launch just as a placeholder
        appState.subtractTime(1);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to launch app: '\${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return SafeArea(
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimeBank(appState),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Text(
              'My Apps',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAppGrid(appState),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBank(AppState appState) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIME BANK',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\${appState.timeBank}',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'mins',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppGrid(AppState appState) {
    if (_apps.isEmpty) {
      return const Center(child: Text('No apps found'));
    }
    
    // Sort array to bubble locked apps? Optional.
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 24,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _apps.length,
      itemBuilder: (context, index) {
        final app = _apps[index] as Map<dynamic, dynamic>;
        final String name = app['name'] ?? 'Unknown';
        final String packageName = app['packageName'] ?? '';
        final bool isLocked = appState.isAppLocked(packageName);

        return GestureDetector(
          onTap: () => _handleAppLaunch(app, appState),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isLocked ? Colors.red.withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isLocked ? Icons.lock : Icons.apps,
                        color: isLocked ? Colors.redAccent.shade100 : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
