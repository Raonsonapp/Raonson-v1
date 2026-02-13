import '../core/api/api.dart';

class AuthApi {
  static Future<void> sendOtp(String phone) async {
    await Api.post(
      "/auth/send-otp",
      body: {"phone": phone},
    );
  }

  static Future<String> verifyOtp(
    String phone,
    String code,
  ) async {
    final res = await Api.post(
      "/auth/verify-otp",
      body: {
        "phone": phone,
        "code": code,
      },
    );
    return res["tempToken"];
  }

  static Future<String> verifyGmail(
    String email,
    String tempToken,
  ) async {
    final res = await Api.post(
      "/auth/verify-gmail",
      body: {"email": email},
      token: tempToken,
    );
    return res["token"];
  }
}
