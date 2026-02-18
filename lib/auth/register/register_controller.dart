import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class RegisterController extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      jsonDecode(response.body);
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
