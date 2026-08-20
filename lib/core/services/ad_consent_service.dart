import 'package:shared_preferences/shared_preferences.dart';

class AdConsentService {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  static const _kConsent = 'ad_consent_given';
  bool _consentGiven = false;

  bool get consentGiven => _consentGiven;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _consentGiven = p.getBool(_kConsent) ?? false;
    } catch (_) {}
  }

  Future<void> grantConsent() async {
    _consentGiven = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kConsent, true);
    } catch (_) {}
  }
}
