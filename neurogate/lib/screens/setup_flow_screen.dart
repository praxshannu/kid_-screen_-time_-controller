import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../main.dart';
import 'home_tab.dart';
import 'parent_panel_screen.dart';

class SetupFlowScreen extends StatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen> {
  final _pageController = PageController();
  final _pinController = TextEditingController();
  final _q1qController = TextEditingController();
  final _q1aController = TextEditingController();
  final _q2qController = TextEditingController();
  final _q2aController = TextEditingController();

  int _currentPage = 0;
  String _errorMessage = '';

  @override
  void dispose() {
    _pageController.dispose();
    _pinController.dispose();
    _q1qController.dispose();
    _q1aController.dispose();
    _q2qController.dispose();
    _q2aController.dispose();
    super.dispose();
  }

  void _nextPage() async {
    setState(() => _errorMessage = '');

    if (_currentPage == 0) {
      if (_pinController.text.length < 4) {
        setState(() => _errorMessage = 'PIN must be at least 4 digits.');
        return;
      }
    } else if (_currentPage == 1) {
      if (_q1qController.text.trim().isEmpty || _q1aController.text.trim().isEmpty ||
          _q2qController.text.trim().isEmpty || _q2aController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please fill out all fields.');
        return;
      }
    }

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _finishSetup();
    }
  }

  void _previousPage() {
    setState(() => _errorMessage = '');
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _errorMessage = ''); // Clear old errors
    
    // Show a loading indicator if desirable, though this should be fast
    final appState = Provider.of<AppState>(context, listen: false);

    await appState.setParentPin(_pinController.text);
    
    final questions = [
      {'question': _q1qController.text.trim(), 'answer': _q1aController.text.trim()},
      {'question': _q2qController.text.trim(), 'answer': _q2aController.text.trim()},
    ];
    await appState.setVerificationQuestions(questions);
    
    // Auto-block known browsers during initial setup
    try {
      final platform = const MethodChannel('com.neurogate/apps');
      final List<dynamic>? installedApps = await platform.invokeMethod('getInstalledApps');
      if (installedApps != null) {
        await appState.autoBlockBrowsers(installedApps);
      }
    } on PlatformException catch (e) {
      debugPrint("Setup: Failed to get installed apps for auto-blocking: ${e.message}");
    }

    await appState.setSetupComplete(true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigator()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? Colors.blueAccent
                          : index < _currentPage
                              ? Colors.greenAccent
                              : Colors.white24,
                    ),
                  ),
                ),
              ),
            ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildPinPage(),
                  _buildQuestionsPage(),
                  _buildSummaryPage(),
                ],
              ),
            ),

            // Navigation bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      style: TextButton.styleFrom(foregroundColor: Colors.white54),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80), // Placeholder to keep button right aligned
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == 2 ? 'Complete Setup' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            'Set Parent Passcode',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'This passcode will be required to change restrictions or enter the Parent Panel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '----',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(Icons.security, size: 64, color: Colors.greenAccent),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Verification Questions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Add at least 2 personal questions. When you disable Parent Mode (unlocking all apps), the system will verify it\'s really you by asking one randomly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),

          // Q1
          const Text('Question 1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTextField(_q1qController, 'e.g., What was the name of our first dog?'),
          const SizedBox(height: 8),
          _buildTextField(_q1aController, 'Answer (keep it simple)'),
          
          const SizedBox(height: 24),

          // Q2
          const Text('Question 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTextField(_q2qController, 'e.g., In what city did my parents meet?'),
          const SizedBox(height: 8),
          _buildTextField(_q2aController, 'Answer (keep it simple)'),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            'All Set!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'NeuroGate is ready to guide your child towards mindful app usage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryLine(Icons.lock, 'Passcode Set'),
                _buildSummaryLine(Icons.security, '2 Verification Questions Set'),
                _buildSummaryLine(Icons.child_care, 'Ready for Child Mode'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
