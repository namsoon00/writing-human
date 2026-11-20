import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

const openOnEntry = true;
const collectionInstructions = '웹페이지에서 원문을 복사한 뒤 이 화면에서 가져와 주세요.';

Widget? embeddedSourcePage(Uri url) => null;

Future<bool> launchSourcePage(Uri url) => launchUrl(
  url,
  mode: LaunchMode.inAppBrowserView,
  browserConfiguration: const BrowserConfiguration(showTitle: true),
);
