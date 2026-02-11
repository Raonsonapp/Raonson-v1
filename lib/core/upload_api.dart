import 'dart:io';
import 'package:http/http.dart' as http;
import 'api.dart';

class UploadApi {
  static Future<bool> uploadFile({
    required File file,
    required String type, // image | video
  }) async {
    final uri = Uri.parse("$BASE_URL/upload");

    final request = http.MultipartRequest("POST", uri);
    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        file.path,
      ),
    );
    request.fields["type"] = type;

    final response = await request.send();
    return response.statusCode == 200;
  }
}
