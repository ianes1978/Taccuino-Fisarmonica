import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/boot_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(TaccuinoApp(state: state));
}

class TaccuinoApp extends StatelessWidget {
  final AppState state;
  const TaccuinoApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taccuino Fisarmonica',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: BootSplash(child: HomeScreen(state: state)),
    );
  }
}
