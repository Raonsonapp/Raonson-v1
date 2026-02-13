import '../core/api.dart';
import '../core/session.dart';
import 'dart:convert';

class AuthApi {
  static Future<void> sendOtp(String phone) async {
    final res = await Api.post('/auth/send-otp', {
      'phone': phone,
    });

    if (res.statusCode != 200) {
      throw Exception('Send OTP failed');
    }
  }

  static Future<void> verifyOtp(String phone, String code) async {
    final res = await Api.post('/auth/verify-otp', {
      'phone': phone,
      'code': code,
    });

    if (res.statusCode != 200) {
      throw Exception('OTP invalid');
    }

    final data = jsonDecode(res.body);
    Session.token = data['tempToken'];
  }

  static Future<void> verifyGmail(String email) async {
    final res = await Api.post('/auth/verify-gmail', {
      'email': email,
    });

    if (res.statusCode != 200) {
      throw Exception('Gmail verify failed');
    }

    final data = jsonDecode(res.body);
    Session.token = data['token'];
    Session.userId = data['user']['phone'];
  }
}
