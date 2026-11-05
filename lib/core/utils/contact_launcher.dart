import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

abstract final class ContactLauncher {
  static Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  static Future<bool> whatsapp({String number = AppConstants.whatsappNumber, String message = ''}) => launchUrl(
    Uri.https('wa.me', '/$number', message.isEmpty ? null : {'text': message}),
    mode: LaunchMode.externalApplication,
  );

  /// Opens directions through [stops] in order, the last being the destination.
  static Future<bool> navigateRoute(List<String> stops) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': stops.last,
      if (stops.length > 1) 'waypoints': stops.sublist(0, stops.length - 1).join('|'),
    }),
    mode: LaunchMode.externalApplication,
  );

  /// Opens turn-by-turn directions in the phone's maps app.
  static Future<bool> navigateTo(String address) => launchUrl(
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': address}),
    mode: LaunchMode.externalApplication,
  );
}
