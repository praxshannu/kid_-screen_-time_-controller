import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../services/gemini_service.dart';

class InterceptorDialog extends StatefulWidget {
  final Map<dynamic, dynamic> targetApp;
  final VoidCallback onSuccess;

  const InterceptorDialog({
    super.key,
    required this.targetApp,
    required this.onSuccess,
  });

  @override
  State<InterceptorDialog> createState() => _InterceptorDialogState();
}

class _InterceptorDialogState extends State<InterceptorDialog> {
  bool _isLoading = true;
  bool _isChecking = false;
  String _errorMessage = '';
  String _aiFeedback = '';
  
  // For 9-12 Trivia
  String _question = '';
  String _answer = '';
  final TextEditingController _textController = TextEditingController();

  late GeminiService _geminiService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initToll();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initToll() async {
    final appState = Provider.of<AppState>(context, listen: false);
    _geminiService = GeminiService(accessToken: appState.googleAccessToken);

    final ageGroup = appState.ageGroup;

    try {
      if (ageGroup == '3-5' || ageGroup == '6-8') {
        // Simple verification for younger kids for now
        setState(() {
          _isLoading = false;
        });
      } else if (ageGroup == '9-12') {
        final prompt =
            'Generate a fun, educational trivia question for a 10 year old. The topic can be science, geography, or animals. Keep the question under 15 words. Keep the answer to a SINGLE simple word (no punctuation). Return as JSON: {"question": "...", "answer": "..."}';
        
        final response = await _geminiService.callGeminiText(prompt, jsonMode: true);
        final data = jsonDecode(response);
        
        setState(() {
          _question = data['question'] ?? 'What is 2 + 2?';
          _answer = (data['answer'] ?? '4').toString().toLowerCase();
          _isLoading = false;
        });
      } else if (ageGroup == '13-16') {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load AI challenge: \$e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitToll() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final ageGroup = appState.ageGroup;
    setState(() {
      _isChecking = true;
      _aiFeedback = '';
      _errorMessage = '';
    });

    if (ageGroup == '3-5' || ageGroup == '6-8') {
      // Immediate success
      await Future.delayed(const Duration(milliseconds: 500));
      _handleSuccess();
    } else if (ageGroup == '9-12') {
      final input = _textController.text.toLowerCase().trim();
      if (input.isEmpty || !_answer.contains(input)) {
        setState(() {
          _errorMessage = "Incorrect. Hint: It relates to \${_answer[0].toUpperCase()}...";
          _isChecking = false;
        });
        return;
      }
      _handleSuccess();
    } else if (ageGroup == '13-16') {
      final input = _textController.text.trim();
      if (input.length < 5) {
        setState(() {
          _errorMessage = "Please write a slightly longer sentence.";
          _isChecking = false;
        });
        return;
      }

      final appName = widget.targetApp['name'];
      final prompt =
          'A teenager wants to open the app "$appName". Their stated reason is: "${_textController.text}". Evaluate if this intention is mindful and purposeful, OR if it sounds like mindless dopamine seeking/boredom. If it\'s mindless, deny them. If it\'s purposeful, approve them. Return JSON: {"approved": boolean, "feedback": "Brief 1 sentence explaining why"}';

      try {
        final response = await _geminiService.callGeminiText(prompt, jsonMode: true);
        final data = jsonDecode(response);

        if (data['approved'] == true) {
          setState(() {
            _aiFeedback = "✨ AI Says: \${data['feedback']} Access granted.";
            _isChecking = false;
          });
          // For UX, wait a bit so they can read the feedback
          await Future.delayed(const Duration(seconds: 2));
          _handleSuccess();
        } else {
           setState(() {
            _errorMessage = "✨ AI Says: \${data['feedback']}";
            _isChecking = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = "Error checking intent. Permitting access anyway.";
          _isChecking = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        _handleSuccess();
      }
    }
  }

  void _handleSuccess() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.addTime(appState.exchangeRate);
    widget.onSuccess();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology, color: Colors.blueAccent, size: 36),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Cognitive Toll',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete this task to switch your brain from passive to active mode.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 24),

            // Dynamic Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildDynamicContent(),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ],
            
            if (_aiFeedback.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _aiFeedback,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isChecking) ? null : _submitToll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.purpleAccent),
              SizedBox(height: 12),
              Text('✨ AI is preparing your challenge...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final ageGroup = Provider.of<AppState>(context, listen: false).ageGroup;

    if (ageGroup == '3-5' || ageGroup == '6-8') {
      return const Column(
        children: [
          Icon(Icons.family_restroom, color: Colors.indigoAccent, size: 48),
          SizedBox(height: 12),
          Text('Parent Verification Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Show your parent what you found.', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
        ],
      );
    } else if (ageGroup == '9-12') {
      return Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 14),
              SizedBox(width: 4),
              Text('AI Trivia Challenge', style: TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_question, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    } else if (ageGroup == '13-16') {
      final appName = widget.targetApp['name'];
      return Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 14),
              SizedBox(width: 4),
              Text('AI Intent Evaluator', style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Before opening \$appName, explain why you want to use it right now. Be honest.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g., I want to watch a tutorial on...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    }

    return const Text('Unknown challenge', style: TextStyle(color: Colors.red));
  }
}
