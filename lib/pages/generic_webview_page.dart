import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GenericWebViewPage extends StatefulWidget {
  const GenericWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.cookies,
  });

  final String title;
  final String url;
  final List<WebViewCookie>? cookies;

  @override
  State<GenericWebViewPage> createState() => _GenericWebViewPageState();
}

class _GenericWebViewPageState extends State<GenericWebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController();
    unawaited(controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      ),
    );

    unawaited(_loadWithCookies());
  }

  Future<void> _loadWithCookies() async {
    final cookieManager = WebViewCookieManager();

    await cookieManager.clearCookies();

    for (final cookie in widget.cookies ?? const <WebViewCookie>[]) {
      await cookieManager.setCookie(cookie);
    }

    await controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: WebViewWidget(controller: controller),
    );
  }
}
