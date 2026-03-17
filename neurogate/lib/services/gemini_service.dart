import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _modelText = 'gemini-2.5-flash';
  static const String _modelVision = 'gemini-2.5-flash';

  final String apiKey;

  GeminiService({required this.apiKey});

  Future<String> callGeminiText(String prompt, {bool jsonMode = false}) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelText:generateContent?key=$apiKey');

    final Map<String, dynamic> payload = {
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
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint("Gemini HTTP Error: ${response.statusCode} - ${response.body}");
        return jsonMode ? "{}" : "Error connecting to AI. Please try again.";
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      return text ?? (jsonMode ? "{}" : "Error connecting to AI. Please try again.");
    } catch (e) {
      debugPrint("Gemini Exception: $e");
      return jsonMode ? "{}" : "Error connecting to AI. Please try again.";
    }
  }
      
  Future<String> callGeminiVision(String prompt, Uint8List imageBytes, {bool jsonMode = false}) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelVision:generateContent?key=$apiKey');

    final Map<String, dynamic> payload = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {
                "mimeType": "image/jpeg",
                "data": base64Encode(imageBytes)
              }
            }
          ]
        }
      ],
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
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint("Gemini Vision Error: ${response.statusCode} - ${response.body}");
        return jsonMode ? "{}" : "Error connecting to AI.";
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      return text ?? (jsonMode ? "{}" : "Error connecting to AI.");
    } catch (e) {
      debugPrint("Gemini Vision Exception: $e");
      return jsonMode ? "{}" : "Error connecting to AI.";
    }
  }
}
