import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hand-offs to other apps (M10, M13): maps, share sheet, dialer and mail
/// app. Abstract so
/// widgets can be tested without platform channels.
abstract class ExternalActions {
  /// Opens the maps app (or browser) searching for [query]. False if nothing
  /// could open it.
  Future<bool> openMaps(String query);

  /// [origin] anchors the share sheet on iPad (the button's rectangle).
  Future<void> shareText(String text, {String? subject, Rect? origin});

  /// Opens the phone's dialer with [phone]. False if nothing could open it.
  Future<bool> call(String phone);

  /// Opens the mail app addressed to [address]. False if nothing could.
  Future<bool> email(String address, {String? subject});
}

class PlatformExternalActions implements ExternalActions {
  const PlatformExternalActions();

  @override
  Future<bool> openMaps(String query) async {
    // A Google Maps search URL works on Android, iOS and the web; it opens
    // the Maps app when installed.
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false; // e.g. PlatformException when nothing can open it
    }
  }

  @override
  Future<bool> call(String phone) => _launch(
    Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), '')),
  );

  @override
  Future<bool> email(String address, {String? subject}) => _launch(
    Uri(
      scheme: 'mailto',
      path: address,
      query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
    ),
  );

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
  }
}
