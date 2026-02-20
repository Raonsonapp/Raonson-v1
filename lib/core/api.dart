import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl = 'https://raonson-v1.onrender.com';

  // ================= GET =================
  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );

    if (res.statusCode >= 400) {
      throw Exception('GET $path failed');
    }

    if (res.body.isEmpty) return {};
    return jsonDecode(res.body);
  }

  // ================= POST JSON =================
  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode >= 400) {
      throw Exception('POST $path failed');
    }

    if (res.body.isEmpty) return {};
    return jsonDecode(res.body);
  }

  // ================= POST MULTIPART =================
  static Future<void> multipart({
    required String path,
    required Map<String, String> fields,
    required List<File> files,
    required String fileField,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);

    req.fields.addAll(fields);

    for (final file in files) {
      req.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
        ),
      );
    }

    final res = await req.send();

    if (res.statusCode >= 400) {
      final body = await res.stream.bytesToString();
      throw Exception('Multipart upload failed: $body');
    }
  }

  // ================= HEADERS =================
  static Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}
