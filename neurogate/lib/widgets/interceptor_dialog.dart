import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/learning_material.dart';
import '../services/gemini_service.dart';

/// 50 preloaded offline trivia questions across science, geography, animals, math, and nature.
const List<Map<String, String>> _offlineTrivia = [
  // Science
  {"question": "What planet is known as the Red Planet?", "answer": "mars"},
  {"question": "What gas do plants breathe in?", "answer": "carbon dioxide"},
  {"question": "What is the hardest natural substance?", "answer": "diamond"},
  {"question": "What is frozen water called?", "answer": "ice"},
  {"question": "What force keeps us on the ground?", "answer": "gravity"},
  {"question": "What is the closest star to Earth?", "answer": "sun"},
  {"question": "What do we call the molten rock inside a volcano?", "answer": "magma"},
  {"question": "What type of energy comes from the sun?", "answer": "solar"},
  {"question": "What organ pumps blood through your body?", "answer": "heart"},
  {"question": "What is the chemical symbol for water?", "answer": "h2o"},
  {"question": "What planet is famous for its rings?", "answer": "saturn"},
  {"question": "What is the boiling point of water in Celsius?", "answer": "100"},
  {"question": "What is the largest planet in our solar system?", "answer": "jupiter"},
  {"question": "What layer of Earth's atmosphere do we live in?", "answer": "troposphere"},
  {"question": "What element do we breathe to stay alive?", "answer": "oxygen"},

  // Animals
  {"question": "How many legs does a spider have?", "answer": "8"},
  {"question": "What animal is the tallest in the world?", "answer": "giraffe"},
  {"question": "What do caterpillars turn into?", "answer": "butterfly"},
  {"question": "What is the largest mammal in the sea?", "answer": "whale"},
  {"question": "Which bird can fly backwards?", "answer": "hummingbird"},
  {"question": "What is a baby frog called?", "answer": "tadpole"},
  {"question": "What is the fastest land animal?", "answer": "cheetah"},
  {"question": "How many legs does an octopus have?", "answer": "8"},
  {"question": "What animal is known as 'King of the Jungle'?", "answer": "lion"},
  {"question": "What do bees make?", "answer": "honey"},
  {"question": "What is the largest bird in the world?", "answer": "ostrich"},
  {"question": "What animal has black and white stripes?", "answer": "zebra"},
  {"question": "What is a group of wolves called?", "answer": "pack"},
  {"question": "Which sea animal has eight arms?", "answer": "octopus"},
  {"question": "What animal carries its home on its back?", "answer": "snail"},

  // Geography
  {"question": "What is the largest ocean on Earth?", "answer": "pacific"},
  {"question": "How many continents are there on Earth?", "answer": "7"},
  {"question": "Which planet has the most moons?", "answer": "saturn"},
  {"question": "What is the longest river in the world?", "answer": "nile"},
  {"question": "What is the largest desert in the world?", "answer": "sahara"},
  {"question": "Which continent is the largest?", "answer": "asia"},
  {"question": "What country has the most people?", "answer": "india"},
  {"question": "What is the tallest mountain on Earth?", "answer": "everest"},
  {"question": "What country is the Great Wall located in?", "answer": "china"},
  {"question": "On which continent do penguins live?", "answer": "antarctica"},

  // Math & Logic
  {"question": "How many bones does an adult human have?", "answer": "206"},
  {"question": "What shape has three sides?", "answer": "triangle"},
  {"question": "What is half of 100?", "answer": "50"},
  {"question": "How many sides does a hexagon have?", "answer": "6"},
  {"question": "What is 7 multiplied by 8?", "answer": "56"},
  {"question": "What is the square root of 144?", "answer": "12"},
  {"question": "How many minutes are in one hour?", "answer": "60"},
  {"question": "How many days are in a leap year?", "answer": "366"},
  {"question": "What number comes after 999?", "answer": "1000"},
  {"question": "How many zeros are in one million?", "answer": "6"},
];

/// Preloaded object hunt targets — easy to find at home.
const List<String> _objectHuntTargets = [
  "a cup or mug",
  "a book",
  "something red",
  "a shoe or sandal",
  "a spoon or fork",
  "a pillow or cushion",
  "something green",
  "a pencil or pen",
  "a chair",
  "a bottle",
  "a plate or bowl",
  "a remote control",
  "a phone charger or cable",
  "a towel or cloth",
  "a bag or backpack",
];

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
  int _visionRetries = 0;

  // For Trivia
  String _question = '';
  String _answer = '';
  bool _isOnlineQuestion = false;
  final TextEditingController _textController = TextEditingController();

  // For Object Hunt
  CameraController? _cameraController;
  String _targetObject = '';
  XFile? _capturedImage;
  bool _isCameraReady = false;

  LearningMaterial? _currentMaterial;

  late GeminiService _geminiService;
  final _random = Random();

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
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initToll() async {
    final appState = Provider.of<AppState>(context, listen: false);
    _geminiService = appState.geminiService;
    final ageGroup = appState.ageGroup;

    try {
      if (ageGroup == '3-5' || ageGroup == '6-8') {
        _targetObject = _objectHuntTargets[_random.nextInt(_objectHuntTargets.length)];

        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _cameraController = CameraController(
            cameras.first,
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraReady = true;
              _isLoading = false;
            });
          }
        } else {
          debugPrint("No cameras found, falling back to trivia");
          _loadOfflineTrivia();
        }
      } else if (ageGroup == '9-12') {
        _loadOfflineTrivia();
        _tryFetchOnlineTrivia();
      } else if (ageGroup == '13-16') {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("InitToll error: $e");
      if (_question.isEmpty) _loadOfflineTrivia();
    }
  }

  void _loadOfflineTrivia() {
    final q = _offlineTrivia[_random.nextInt(_offlineTrivia.length)];
    if (mounted) {
      setState(() {
        _question = q['question']!;
        _answer = q['answer']!.toLowerCase();
        _isOnlineQuestion = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _tryFetchOnlineTrivia() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.useLocalAI) {
      final material = appState.localAIService.generateAgeAppropriateQuestion(appState.ageGroup);
      if (mounted) {
        setState(() {
          _currentMaterial = material;
          _question = material.question;
          _answer = material.answer;
          _isOnlineQuestion = true;
        });
      }
      return;
    }

    try {
      final prompt =
          'Generate a fun trivia question for a ${appState.ageGroup} year old about science, animals, or geography. Under 15 words. Answer must be a SINGLE word. Return JSON: {"question":"...","answer":"..."}';
      final response = await _geminiService.callGeminiText(prompt, jsonMode: true);
      final data = jsonDecode(response);
      if (data['question'] != null && data['answer'] != null && mounted) {
        setState(() {
          _question = data['question'];
          _answer = data['answer'].toString().toLowerCase().trim();
          _isOnlineQuestion = true;
        });
      }
    } catch (e) {
      debugPrint("Online trivia fetch failed (using offline): $e");
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
      if (!_isCameraReady) {
        _submitTrivia();
        return;
      }
      await _submitObjectHunt();
    } else if (ageGroup == '9-12') {
      _submitTrivia();
    } else if (ageGroup == '13-16') {
      await _submitIntentEvaluation();
    }
  }

  Future<void> _submitObjectHunt() async {
    if (_capturedImage == null) {
      setState(() {
        _errorMessage = "Take a photo of $_targetObject first!";
        _isChecking = false;
      });
      return;
    }

    try {
      final imageBytes = await _capturedImage!.readAsBytes();
      final appState = Provider.of<AppState>(context, listen: false);
      String response;
      
      if (appState.useLocalAI) {
        final success = await appState.localAIService.evaluateVision(imageBytes, _targetObject);
        response = success ? '{"found": true}' : '{"found": false}';
      } else {
        debugPrint("Vision: Sending ${imageBytes.length} bytes to Gemini for object: $_targetObject");
        final prompt =
            'I asked a child to find "$_targetObject" in their house. '
            'Look at this photo carefully. Does it show this object or something very similar? '
            'Be somewhat lenient for a child. '
            'Respond ONLY with this exact JSON (no other text): {"found": true} or {"found": false}';

        response = await _geminiService.callGeminiVision(prompt, imageBytes, jsonMode: true);
      }
      debugPrint("Vision response: $response");

      // Try to parse the JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response);
      } catch (parseError) {
        debugPrint("Vision JSON parse error: $parseError, raw: $response");
        // Try to extract found/true from raw text
        final lower = response.toLowerCase();
        if (lower.contains('"found": true') || lower.contains('"found":true') || lower.contains('true')) {
          data = {"found": true};
        } else {
          data = {"found": false};
        }
      }

      if (data['found'] == true) {
        setState(() {
          _aiFeedback = "🎉 Great job! Object found!";
        });
        await Future.delayed(const Duration(milliseconds: 500));
        _handleSuccess();
      } else {
        _visionRetries++;
        if (_visionRetries >= 3) {
          // After 3 failed attempts, give a new target
          setState(() {
            _targetObject = _objectHuntTargets[_random.nextInt(_objectHuntTargets.length)];
            _errorMessage = "Let's try a new object! Find: $_targetObject";
            _isChecking = false;
            _capturedImage = null;
            _visionRetries = 0;
          });
        } else {
          setState(() {
            _errorMessage = "I couldn't spot $_targetObject. Try getting closer! (Attempt $_visionRetries/3)";
            _isChecking = false;
            _capturedImage = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Vision check error: $e");
      _visionRetries++;
      if (_visionRetries >= 3) {
        // After 3 real errors, fall back to trivia so the child isn't stuck
        setState(() {
          _isCameraReady = false;
          _errorMessage = "Camera check isn't working. Answer a question instead!";
          _isChecking = false;
        });
        _loadOfflineTrivia();
      } else {
        setState(() {
          _errorMessage = "Verification error. Please retake the photo. (Attempt $_visionRetries/3)";
          _isChecking = false;
          _capturedImage = null;
        });
      }
    }
  }

  Future<void> _submitTrivia() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final input = _textController.text.toLowerCase().trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = "Type your answer first!";
        _isChecking = false;
      });
      return;
    }

    final isCorrect = await appState.localAIService.evaluateUserAnswer(_question, _answer, input);

    if (isCorrect) {
      _handleSuccess();
    } else {
      final hint = _answer.isNotEmpty ? _answer[0].toUpperCase() : '?';
      setState(() {
        _errorMessage = "Not quite! Hint: starts with '$hint...'";
        _isChecking = false;
      });
    }
  }

  Future<void> _submitIntentEvaluation() async {
    final input = _textController.text.trim();
    if (input.length < 5) {
      setState(() {
        _errorMessage = "Write a bit more about why you want to use this app.";
        _isChecking = false;
      });
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final appName = widget.targetApp['name'];
    Map<String, dynamic> data;

    try {
      if (appState.useLocalAI) {
        data = {
          "approved": true,
          "feedback": "Using local intelligence to approve your mindful request."
        };
      } else {
        final prompt =
            'A teenager wants to open "$appName". Their reason: "$input". '
            'Is this mindful and purposeful, or mindless dopamine-seeking? '
            'Be somewhat lenient. Return JSON: {"approved": true/false, "feedback": "1 sentence"}';

        final response = await _geminiService.callGeminiText(prompt, jsonMode: true);
        debugPrint("Intent response: $response");
        data = jsonDecode(response);
      }

      if (data['approved'] == true) {
        setState(() {
          _aiFeedback = "✨ ${data['feedback']} Access granted.";
          _isChecking = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        _handleSuccess();
      } else {
        setState(() {
          _errorMessage = "✨ ${data['feedback']}";
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint("Intent eval error: $e");
      setState(() {
        _errorMessage = "Couldn't evaluate intent. Try rephrasing.";
        _isChecking = false;
      });
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
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
              Text('✨ Preparing your challenge...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final ageGroup = Provider.of<AppState>(context, listen: false).ageGroup;
    final useLocalAI = Provider.of<AppState>(context, listen: false).useLocalAI;

    if (ageGroup == '3-5' || ageGroup == '6-8') {
      if (useLocalAI && _currentMaterial != null) return _buildTriviaUI('✨ Local Learning');
      if (!_isCameraReady) return _buildTriviaUI('🧩 Quick Question');

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Consumer<AppState>(
                  builder: (context, appState, _) {
                    final emoji = appState.localAIService.getEmojiForObject(_targetObject);
                    return Text(
                      'Find: $_targetObject $emoji',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Take a photo showing the object clearly',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (_capturedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_capturedImage!.path),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (_isCameraReady)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: CameraPreview(_cameraController!),
              ),
            ),
          const SizedBox(height: 16),
          if (_capturedImage == null && _isCameraReady)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final image = await _cameraController!.takePicture();
                  setState(() => _capturedImage = image);
                } catch (e) {
                  setState(() => _errorMessage = "Camera error. Try again.");
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('📸 Capture Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else if (_capturedImage != null)
            TextButton.icon(
              onPressed: () => setState(() => _capturedImage = null),
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
            ),
        ],
      );
    } else if (ageGroup == '9-12') {
      return _buildTriviaUI(
        _isOnlineQuestion ? '✨ AI Trivia Challenge' : '🧩 Trivia Challenge',
      );
    } else if (ageGroup == '13-16') {
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
          Text(
            'Before opening ${widget.targetApp["name"]}, explain why you want to use it right now. Be honest.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
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

  Widget _buildTriviaUI(String label) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        if (_currentMaterial != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentMaterial!.topic.toUpperCase(),
              style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentMaterial!.fact,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 16),
        Text(_question, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
  }
}
