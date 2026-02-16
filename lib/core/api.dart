import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl = 'https://raonson-v1.onrender.com';

  // GET
  static Future<http.Response> get(String path) {
    return http.get(Uri.parse('$baseUrl$path'));
  }

  // POST JSON
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  // POST MULTIPART (UPLOAD)
  static Future<void> multipart({
    required String path,
    required Map<String, String> fields,
    required List<File> files,
    required String fileField,
  }) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));

    req.fields.addAll(fields);

    for (final file in files) {
      req.files.add(
        await http.MultipartFile.fromPath(fileField, file.path),
      );
    }

    final res = await req.send();
    if (res.statusCode >= 400) {
      throw Exception('Upload failed');
    }
  }
}
