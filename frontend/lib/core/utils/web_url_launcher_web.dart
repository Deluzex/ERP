// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openWebWindow(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}
