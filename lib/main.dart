import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app/app.dart';
import 'src/state/app_controller.dart';
import 'src/state/log_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppController()..init()),
        ChangeNotifierProxyProvider<AppController, LogStore>(
          create: (_) => LogStore(),
          update: (_, controller, __) => controller.logs,
        ),
      ],
      child: const AppRoot(),
    ),
  );
}

