import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_emoji/flutter_emoji.dart';
import 'package:path_provider/path_provider.dart';
import '../models/learning_material.dart';

class LocalAIService {
  Interpreter? _visionInterpreter;
  OrtSession? _textSession;
  final _emojiParser = EmojiParser();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    OrtEnv.instance.init();

    try {
      // Load TFLite model for Vision
      _visionInterpreter = await Interpreter.fromAsset(
        'models/job_jpydxz38p_optimized_onnx/1.tflite',
      );

      // Load ONNX model for Text
      // Onnxruntime usually needs a physical file path
      final docDir = await getApplicationDocumentsDirectory();
      final onnxPath = '${docDir.path}/model.onnx';
      final dataPath = '${docDir.path}/model.data';

      // Copy from assets to local storage if not exists
      await _copyAssetToFile('models/job_jpydxz38p_optimized_onnx/model.onnx', onnxPath);
      await _copyAssetToFile('models/job_jpydxz38p_optimized_onnx/model.data', dataPath);

      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(1)
        ..setIntraOpNumThreads(1);
      
      _textSession = OrtSession.fromFile(File(onnxPath), sessionOptions);

      _isInitialized = true;
      debugPrint("LocalAI: Initialized successfully");
    } catch (e) {
      debugPrint("LocalAI: Initialization error: $e");
    }
  }

  Future<void> _copyAssetToFile(String assetPath, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
    }
  }

  String getEmojiForObject(String objectName) {
    // Map of common objects to emojis for a start
    final map = {
      'cup': '☕',
      'mug': '☕',
      'bottle': '🍼',
      'chair': '🪑',
      'table': 'TABLE', // No direct emoji? 
      'desk': '🖥️',
      'book': '📖',
      'pen': '🖊️',
      'pencil': '✏️',
      'phone': '📱',
      'laptop': '💻',
      'mouse': '🖱️',
      'keyboard': '⌨️',
      'bottle': '🍾',
      'glasses': '👓',
      'watch': '⌚',
      'remote': '🎮',
      'spoon': '🥄',
      'fork': '🍴',
      'knife': '🔪',
      'plate': '🍽️',
      'bowl': '🥣',
      'umbrella': '☂️',
      'bag': '👜',
      'backpack': '🎒',
      'shoe': '👟',
      'socks': '🧦',
      'hat': '🎩',
      'flower': '🌸',
      'plant': '🌱',
      'tree': '🌳',
      'apple': '🍎',
      'banana': '🍌',
      'orange': '🍊',
      'fruit': '🍎',
      'toy': '🧸',
      'car': '🚗',
      'key': '🔑',
      'door': '🚪',
      'window': '🪟',
      'bed': '🛏️',
      'pillow': '☁️',
      'blanket': '🛌',
    };

    final lower = objectName.toLowerCase();
    for (var entry in map.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Fallback search with emoji parser if available
    final emojis = _emojiParser.getEmoji(lower);
    if (emojis != null) {
      return emojis.code;
    }

    return '🔍'; // General search emoji
  }

  Future<bool> evaluateVision(Uint8List imageBytes, String targetObject) async {
    if (_visionInterpreter == null) return false;

    try {
      // 1. Preprocess image (Resize to model input size, normalize)
      // Note: This is a placeholder. Proper preprocessing depends on the specific model.
      // Usually it's 224x224 or 299x299.
      
      // Let's assume the model is a classification model or a detector.
      // For now, we simulate a 'found' result for demonstration if the model is loaded.
      // Real integration would use something like 'tflite_flutter_helper' (not in pubspec yet).
      
      debugPrint("LocalAI Vision: Evaluating image for $targetObject");
      
      // Run inference...
      // var input = ...;
      // var output = ...;
      // _visionInterpreter!.run(input, output);
      
      // Return true if confidence > threshold
      return true; 
    } catch (e) {
      debugPrint("LocalAI Vision inference error: $e");
      return false;
    }
  }

  void dispose() {
    _visionInterpreter?.close();
    // _textSession?.release(); // Depends on onnxruntime API
  }

  LearningMaterial generateAgeAppropriateQuestion(String ageGroup) {
    final filtered = ageAppropriateKnowledge.where((m) => m.ageGroup == ageGroup).toList();
    if (filtered.isEmpty) {
      // Fallback to any material if none found for age group
      return ageAppropriateKnowledge[0];
    }
    return filtered[DateTime.now().millisecond % filtered.length];
  }

  Future<bool> evaluateUserAnswer(String question, String correctAnswer, String userAnswer) async {
    final lowerUserAnswer = userAnswer.toLowerCase().trim();
    final lowerCorrectAnswer = correctAnswer.toLowerCase().trim();

    // Basic heuristic for now, but in a real app, this would use the ONNX model 
    // to check for semantic similarity (e.g., "3" vs "three").
    if (lowerUserAnswer == lowerCorrectAnswer) return true;
    
    // If the answer is a number, try to parse both
    if (double.tryParse(lowerUserAnswer) != null && double.tryParse(lowerCorrectAnswer) != null) {
      return double.parse(lowerUserAnswer) == double.parse(lowerCorrectAnswer);
    }

    // Semantic check (simplified for now)
    if (lowerUserAnswer.contains(lowerCorrectAnswer) || lowerCorrectAnswer.contains(lowerUserAnswer)) {
      return true;
    }

    // In the future:
    // _textSession?.run(...) to check if userAnswer is a valid response to question
    
    return false;
  }
}
