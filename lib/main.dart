import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import 'models/connection_models.dart';
import 'services/nearby_service.dart';
import 'ui/main_screen.dart';
import 'utils/logger.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const PoC1App());
}

class PoC1App extends StatelessWidget {
  const PoC1App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NearbyService(),
      child: MaterialApp(
        title: 'PoC-1A Direct Chat',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}