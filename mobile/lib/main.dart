import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId(AppConfig.appGroupId);
  HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
    // Deep link from widget is handled after auth via go_router query params.
    debugPrint('Widget launch: $uri');
  });
  runApp(const TaktApp());
}
