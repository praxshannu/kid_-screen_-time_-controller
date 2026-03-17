import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../widgets/interceptor_dialog.dart';
import 'safe_browser_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.neurogate/apps');
  List<dynamic> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchApps();
    _requestOverlayPermission();
    // Register overlay tap callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setOverlayTapCallback(() {
        if (mounted) {
          _showChallenge(appState);
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to NeuroGate — sync remaining time from native service
      final appState = Provider.of<AppState>(context, listen: false);
      appState.syncRemainingTime();
    }
  }

  Future<void> _requestOverlayPermission() async {
    try {
      final canDraw = await platform.invokeMethod('canDrawOverlays') as bool;
      if (!canDraw) {
        await platform.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      debugPrint('Overlay permission check error: $e');
    }
  }

  void _showChallenge(AppState appState) {
    if (appState.parentModeActive) return; // No bypass needed if parent mode is active

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InterceptorDialog(
        targetApp: {'name': 'current app', 'packageName': ''},
        onSuccess: () {
          // Time added by InterceptorDialog._handleSuccess
        },
      ),
    );
  }

  Future<void> _fetchApps() async {
    try {
      final List<dynamic>? result =
          await platform.invokeMethod('getInstalledApps');
      if (mounted) {
        setState(() {
          _apps = result ?? [];
          _isLoading = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get apps: '${e.message}'.");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAppLaunch(Map<dynamic, dynamic> app, AppState appState) async {
    final String packageName = app['packageName'];
    final tag = appState.getAppTag(packageName);

    // Parent mode bypasses all locks
    if (appState.parentModeActive) {
      _launchApp(packageName, appState, isTaxed: false);
      return;
    }

    switch (tag) {
      case AppTag.blocked:
        // Completely blocked — show a snackbar.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.block, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('This app has been blocked by your parent.'),
                ],
              ),
              backgroundColor: Colors.redAccent.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;

      case AppTag.free:
        // No restrictions — launch immediately.
        _launchApp(packageName, appState, isTaxed: false);
        return;

      case AppTag.taxed:
        // Taxed — requires time bank to launch.
        if (appState.timeBankSeconds <= 0) {
          // No time — must do cognitive toll first
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => InterceptorDialog(
                targetApp: app,
                onSuccess: () {
                  _launchApp(packageName, appState, isTaxed: true);
                },
              ),
            );
          }
        } else {
          // Has time — launch and the background timer handles the rest
          _launchApp(packageName, appState, isTaxed: true);
        }
    }
  }

  Future<void> _launchApp(
    String packageName,
    AppState appState, {
    required bool isTaxed,
  }) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
      if (isTaxed) {
        // Start the floating overlay timer — it counts down natively
        await appState.startOverlayTimer();
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to launch app: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(appState),
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

  Widget _buildTopBar(AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                appState.parentModeActive ? Icons.shield : Icons.child_care,
                color: appState.parentModeActive ? Colors.indigoAccent : Colors.greenAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                appState.parentModeActive ? 'Parent Mode' : 'Child Mode',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Switch(
            value: appState.parentModeActive,
            activeColor: Colors.indigoAccent,
            onChanged: (val) {
              if (val) {
                // Turning parent mode ON (unlocking)
                _showParentVerificationDialog(appState);
              } else {
                // Turning parent mode OFF (locking) -> instant
                appState.setParentModeActive(false);
              }
            },
          )
        ],
      ),
    );
  }

  void _showParentVerificationDialog(AppState appState) {
    if (appState.verificationQuestions.isEmpty) {
      // Fallback if no questions are set
      appState.setParentModeActive(true);
      return;
    }

    final randomQuestion = appState.verificationQuestions[Random().nextInt(appState.verificationQuestions.length)];
    String pinInput = '';
    String answerInput = '';
    String error = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, color: Colors.indigoAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Parent Verification',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Disable cognitive system and unlock all apps.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Passcode',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => pinInput = v,
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      randomQuestion['question']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Answer',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => answerInput = v,
                    ),
                    
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                    
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              if (pinInput == appState.parentPin &&
                                  answerInput.toLowerCase().trim() == randomQuestion['answer']) {
                                appState.setParentModeActive(true);
                                Navigator.pop(context);
                              } else {
                                setState(() => error = 'Incorrect passcode or answer.');
                              }
                            },
                            child: const Text('Verify'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                '${(appState.timeBankSeconds / 60).ceil()}',
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

    // Insert Safe Browser as the first item virtually
    final itemCount = _apps.length + 1;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 32,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Render Safe Browser
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SafeBrowserScreen()),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.explore, size: 36, color: Colors.greenAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browser',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Render Normal Apps
        final appIndex = index - 1;
        final app = _apps[appIndex] as Map<dynamic, dynamic>;
        final String name = app['name'] ?? 'Unknown';
        final String packageName = app['packageName'] ?? '';
        final String iconBase64 = app['icon'] ?? '';
        final tag = appState.getAppTag(packageName);

        Color badgeColor;
        IconData? badgeIcon;

        switch (tag) {
          case AppTag.taxed:
            badgeColor = appState.timeBank > 0 ? Colors.amber : Colors.redAccent;
            badgeIcon = appState.timeBank > 0 ? Icons.timer : Icons.lock;
          case AppTag.free:
            badgeColor = Colors.greenAccent;
            badgeIcon = null;
          case AppTag.blocked:
            badgeColor = Colors.grey;
            badgeIcon = Icons.block;
        }

        return GestureDetector(
          onTap: () => _handleAppLaunch(app, appState),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: iconBase64.isNotEmpty
                        ? Image.memory(
                            base64Decode(iconBase64),
                            fit: BoxFit.contain,
                          )
                        : const Icon(Icons.apps, color: Colors.white24, size: 32),
                  ),
                  if (badgeIcon != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F172A), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(badgeIcon, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tag == AppTag.blocked ? Colors.white24 : Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
