import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

Future<bool> openSourceBrowser(BuildContext context, Uri url) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => _SourceBrowser(url: url),
    ),
  );
  return true;
}

class _SourceBrowser extends StatelessWidget {
  const _SourceBrowser({required this.url});

  final Uri url;

  Future<void> _openNewTab(BuildContext context) async {
    try {
      if (await launchUrl(url, webOnlyWindowName: '_blank')) return;
    } on Exception {
      // Keep the browser open when the new tab could not be opened.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 탭을 열지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: '원문 브라우저 닫기',
        icon: const Icon(CupertinoIcons.xmark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(url.host, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton.icon(
          icon: const Icon(CupertinoIcons.arrow_up_right, size: 15),
          label: const Text('새 탭에서 열기'),
          onPressed: () => _openNewTab(context),
        ),
      ],
    ),
    body: HtmlElementView.fromTagName(
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
    ),
  );
}
