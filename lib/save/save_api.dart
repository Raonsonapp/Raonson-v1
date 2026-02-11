import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';

class SaveApi {
  static Future<void> toggleSave(String postId) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/save/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
