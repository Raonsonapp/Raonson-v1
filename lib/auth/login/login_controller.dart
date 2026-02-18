import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class LoginController extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: {
          'email': email,
          'password': password,
        },
      );

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (!data.containsKey('token')) {
        throw Exception('Token missing');
      }
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
