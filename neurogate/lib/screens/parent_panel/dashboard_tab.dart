import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

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
                  color: Colors.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.dashboard, color: Colors.indigoAccent, size: 24),
              ),
              const SizedBox(width: 14),
              const Text(
                'Dashboard',
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
            'Manually adjust time, set developmental stage, and configure the dopamine tax.',
            style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
          ),
          const SizedBox(height: 28),

          // ── Time Bank Controls ──
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIME BANK',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${appState.timeBank}',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'mins',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: '− 15 min',
                        icon: Icons.remove_circle_outline,
                        color: Colors.redAccent,
                        onTap: () => appState.subtractTime(15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: '+ 15 min',
                        icon: Icons.add_circle_outline,
                        color: Colors.greenAccent,
                        onTap: () => appState.addTime(15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Child Age Selector ──
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Developmental Stage (Toll Type)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
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
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Colors.white54),
                      items: const [
                        DropdownMenuItem(
                            value: '3-5',
                            child: Text('3–5 yrs (✨ AI Voice Object Hunt)',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: '6-8',
                            child: Text('6–8 yrs (✨ AI Voice Phonics)',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: '9-12',
                            child: Text('9–12 yrs (✨ Dynamic AI Trivia)',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: '13-16',
                            child: Text('13–16 yrs (✨ AI Intent Evaluator)',
                                style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          appState.setAgeGroup(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Dopamine Tax / Exchange Rate Slider ──
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dopamine Tax (Exchange Rate)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Time rewarded per completed toll: ${appState.exchangeRate} min',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.indigoAccent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.indigoAccent,
                    overlayColor: Colors.indigoAccent.withOpacity(0.15),
                    valueIndicatorColor: Colors.indigoAccent,
                    valueIndicatorTextStyle:
                        const TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: appState.exchangeRate.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${appState.exchangeRate} min',
                    onChanged: (val) {
                      appState.setExchangeRate(val.toInt());
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
