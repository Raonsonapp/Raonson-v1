import 'dart:io';
import 'package:http/http.dart' as http;
import 'api.dart';

class PostApi {
  static Future<bool> createPost({
    required File file,
    required String caption,
    required String type, // image | video
  }) async {
    final request =
        http.MultipartRequest("POST", Uri.parse("$BASE_URL/posts"));

    request.fields["caption"] = caption;
    request.fields["type"] = type;

    request.files.add(
      await http.MultipartFile.fromPath("file", file.path),
    );

    final response = await request.send();
    return response.statusCode == 200;
  }
}
