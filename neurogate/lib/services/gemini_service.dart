import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _modelText = 'gemini-2.5-flash';

  final String accessToken;

  GeminiService({required this.accessToken});

  Future<String> callGeminiText(String prompt, {bool jsonMode = false}) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/\$_modelText:generateContent');

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "systemInstruction": {
        "parts": [
          {
            "text":
                "You are NeuroGate, a child psychology assistant. You provide short, engaging, safe content."
          }
        ]
      },
      "model": _modelText
    };

    if (jsonMode) {
      payload["generationConfig"] = {
        "responseMimeType": "application/json"
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer \$accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint("Gemini HTTP Error: \${response.statusCode} - \${response.body}");
        return jsonMode ? "{}" : "Error connecting to AI. Please try again.";
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      return text ?? (jsonMode ? "{}" : "Error connecting to AI. Please try again.");
    } catch (e) {
      debugPrint("Gemini Exception: \$e");
      return jsonMode ? "{}" : "Error connecting to AI. Please try again.";
    }
  }

  // Audio generation to be implemented when Google fully supports TTS from OAuth tokens across SDKs
  // For MVP, we'll return a mock text challenge for younger kids
}
