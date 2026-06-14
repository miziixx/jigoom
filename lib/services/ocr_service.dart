import 'dart:convert';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  static Future<String?> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final result = await _recognizer.processImage(inputImage);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> cleanWithAI(String rawText, String apiKey) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', '2023-06-01');

      final body = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 512,
        'messages': [
          {
            'role': 'user',
            'content': '다음은 캡처 이미지에서 OCR로 추출한 텍스트야. '
                '아이디, 비밀번호, 계좌번호, 전화번호, 주민번호 등 개인정보는 제거하고 '
                '핵심 내용만 간결하게 정리해줘. 설명 없이 정리된 텍스트만 반환해:\n\n$rawText',
          },
        ],
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final text = (json['content'] as List).first['text'] as String;
        return text.trim().isEmpty ? null : text.trim();
      }
    } catch (_) {}
    return null;
  }
}
