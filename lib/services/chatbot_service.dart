import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

class ChatbotService {
  static Future<String> sendMessage({
    required String message,
    required List<Map<String, dynamic>> history,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/chatbot/send');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'message': message,
        'history': history,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'];
    } else {
      throw Exception('Chatbot error: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> scanReceipt({
    required Uint8List imageBytes,
    required String fileName,
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/chatbot/scan-receipt');

    final request = http.MultipartRequest('POST', url);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Xác định MIME type từ tên file
    String mimeType = 'image/jpeg';
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (lower.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (lower.endsWith('.gif')) {
      mimeType = 'image/gif';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Scan failed: ${response.statusCode}');
    }
  }
}