import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

class ParentPortalTab extends StatefulWidget {
  const ParentPortalTab({super.key});

  @override
  State<ParentPortalTab> createState() => _ParentPortalTabState();
}

class _ParentPortalTabState extends State<ParentPortalTab> {
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.shield, color: Colors.indigoAccent, size: 28),
                SizedBox(width: 12),
                Text(
                  'Parent Portal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Adjust cognitive tolls based on your child\'s developmental milestones.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            
            // Age Group Selector
            _buildSection(
              title: 'Developmental Stage (Toll Type)',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: appState.ageGroup,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                    items: const [
                      DropdownMenuItem(value: '3-5', child: Text('3–5 yrs (✨ AI Voice Object Hunt)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '6-8', child: Text('6–8 yrs (✨ AI Voice Phonics)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '9-12', child: Text('9–12 yrs (✨ Dynamic AI Trivia)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '13-16', child: Text('13–16 yrs (✨ AI Intent Evaluator)', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        appState.setAgeGroup(value);
                      }
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Exchange Rate
            _buildSection(
              title: 'Exchange Rate',
              subtitle: 'Time rewarded per completed toll: \${appState.exchangeRate}m',
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.indigoAccent,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.indigoAccent,
                ),
                child: Slider(
                  value: appState.exchangeRate.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11, // (60 - 5) / 5
                  onChanged: (val) {
                    appState.setExchangeRate(val.toInt());
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            const Text(
              'App Restrictions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),

            // App List
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _apps.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                      itemBuilder: (context, index) {
                        final app = _apps[index] as Map<dynamic, dynamic>;
                        final String name = app['name'] ?? 'Unknown';
                        final String packageName = app['packageName'] ?? '';
                        final bool isLocked = appState.isAppLocked(packageName);

                        return SwitchListTile(
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            packageName,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          value: isLocked,
                          activeColor: Colors.indigoAccent,
                          onChanged: (val) {
                            appState.toggleAppLock(packageName);
                          },
                        );
                      },
                    ),
                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
