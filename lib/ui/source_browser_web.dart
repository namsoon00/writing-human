import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

const openOnEntry = false;
const collectionInstructions = '새 탭에서 원하는 구절을 복사한 뒤, 이 화면으로 돌아와 담으세요.';

Widget? embeddedSourcePage(Uri url) {
  if (url.host == 'search.naver.com') return null;
  return HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      frame
        ..title = '${url.host} 원문'
        ..referrerPolicy = 'no-referrer';
      frame.setAttribute('sandbox', 'allow-forms allow-scripts');
      frame.style.border = '0';
      frame.src = url.toString();
    },
  );
}

Future<bool> launchSourcePage(Uri url) =>
    launchUrl(url, webOnlyWindowName: '_blank');
