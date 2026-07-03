import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SmsHelper {
  static Future<bool> launchSmsFallback({
    required String title,
    required String description,
    required String severity,
    required String latitude,
    required String longitude,
    required String disasterType,
    required String userName,
    required String userId,
  }) async {
    // Format: TITLE|DESCRIPTION|SEVERITY|LATITUDE|LONGITUDE|DISASTER_TYPE|USER_NAME|USER_ID
    final smsBody = "$title|$description|$severity|$latitude|$longitude|$disasterType|$userName|$userId";

    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map((MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }
    
    final gatewayNumber = dotenv.env['SMS_GATEWAY_NUMBER'] ?? '';

    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: gatewayNumber,
      query: encodeQueryParameters(<String, String>{
        'body': smsBody,
      }),
    );

    if (await canLaunchUrl(smsLaunchUri)) {
      await launchUrl(smsLaunchUri);
      return true;
    }
    return false;
  }
}
