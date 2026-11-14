import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openSourceBrowser(BuildContext context, Uri url) => launchUrl(
  url,
  mode: LaunchMode.inAppBrowserView,
  browserConfiguration: const BrowserConfiguration(showTitle: true),
);
