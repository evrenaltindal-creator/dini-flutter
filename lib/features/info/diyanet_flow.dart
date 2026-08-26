import 'package:url_launcher/url_launcher.dart';

class DiyanetFlow {
  // Release öncesi güncel resmi URL doğrulaması zorunludur; bu değer doğrulanmış ilan edilmez.
  static final Uri questionUri = Uri.parse(
    'https://kurul.diyanet.gov.tr/Soru/Sor',
  );
  const DiyanetFlow._();

  static Future<bool> openQuestionFlow() async {
    return launchUrl(questionUri, mode: LaunchMode.externalApplication);
  }
}
