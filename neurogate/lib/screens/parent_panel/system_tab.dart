import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';

class SystemTab extends StatelessWidget {
  const SystemTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.settings,
                    color: Colors.tealAccent, size: 24),
              ),
              const SizedBox(width: 14),
              const Text(
                'System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'NeuroGate needs special permissions to monitor and manage screen time. '
            'Tap each card to open the relevant Android settings page.',
            style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 28),

          // ── Usage Access ──
          _PermissionCard(
            icon: Icons.data_usage,
            iconColor: Colors.cyanAccent,
            title: 'Usage Access',
            description:
                'Allows NeuroGate to see which apps are being used and '
                'for how long. Required for the Time Bank to function.',
            onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.security,
            ),
          ),
          const SizedBox(height: 16),

          // ── Draw Over Other Apps ──
          _PermissionCard(
            icon: Icons.layers,
            iconColor: Colors.orangeAccent,
            title: 'Draw Over Other Apps',
            description:
                'Allows NeuroGate to display the Cognitive Toll overlay '
                'on top of other applications when time runs out.',
            onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.settings,
              asAnotherTask: true,
            ),
          ),
          const SizedBox(height: 16),

          // ── Notification Access (bonus) ──
          _PermissionCard(
            icon: Icons.notifications_active,
            iconColor: Colors.purpleAccent,
            title: 'Notification Access',
            description:
                'Optional. Allows NeuroGate to send reminders when '
                'screen time is running low.',
            onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            ),
          ),
          const SizedBox(height: 16),

          // ── Battery Optimisation ──
          _PermissionCard(
            icon: Icons.battery_charging_full,
            iconColor: Colors.greenAccent,
            title: 'Battery Optimisation',
            description:
                'Disable battery optimisation for NeuroGate so it can '
                'run reliably in the background.',
            onTap: () => AppSettings.openAppSettings(
              type: AppSettingsType.batteryOptimization,
            ),
          ),
          const SizedBox(height: 32),

          // ── Parent Security ──
          const Row(
            children: [
              Icon(Icons.security, color: Colors.indigoAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Security',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _SecurityCard(
            title: 'Change Passcode',
            icon: Icons.password,
            onTap: () => _showChangePasscodeDialog(context),
          ),
          const SizedBox(height: 16),
          _SecurityCard(
            title: 'Manage Verification Questions',
            icon: Icons.question_answer,
            onTap: () => _showManageQuestionsDialog(context),
          ),
          const SizedBox(height: 16),
          
          Consumer<AppState>(
            builder: (context, appState, _) {
              return Material(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Local AI',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Process models on-device (no internet required).',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: appState.useLocalAI,
                        activeColor: Colors.amberAccent,
                        onChanged: (val) => appState.setUseLocalAI(val),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePasscodeDialog(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    String oldPin = '';
    String newPin = '';
    String error = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Change Passcode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Current Passcode',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => oldPin = v,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Passcode',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => newPin = v,
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                            onPressed: () {
                              if (oldPin != appState.parentPin) {
                                setState(() => error = 'Current passcode is incorrect.');
                              } else if (newPin.length < 4) {
                                setState(() => error = 'New passcode must be at least 4 digits.');
                              } else {
                                appState.setParentPin(newPin);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Passcode updated successfully.')),
                                );
                              }
                            },
                            child: const Text('Save', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showManageQuestionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<AppState>(
          builder: (context, appState, _) {
            String newQ = '';
            String newA = '';
            String error = '';

            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Verification Questions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: appState.verificationQuestions.isEmpty
                          ? const Center(child: Text('No questions added.', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: appState.verificationQuestions.length,
                              itemBuilder: (context, index) {
                                final q = appState.verificationQuestions[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(q['question']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text('A: ${q['answer']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => appState.removeVerificationQuestion(index),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(color: Colors.white24, height: 32),
                    const Text('Add New Question', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Column(
                          children: [
                            TextField(
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Question',
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) => newQ = v,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Answer',
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (v) => newA = v,
                            ),
                            if (error.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ],
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                              onPressed: () {
                                if (newQ.trim().isEmpty || newA.trim().isEmpty) {
                                  setDialogState(() => error = 'Fill both fields.');
                                } else {
                                  appState.addVerificationQuestion(newQ, newA);
                                  setDialogState(() {
                                    error = '';
                                    newQ = '';
                                    newA = '';
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              label: const Text('Add', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Colors.white54)),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigoAccent, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new,
                  color: Colors.white.withOpacity(0.2), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
