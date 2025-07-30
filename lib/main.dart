import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/map_project.dart';
import 'models/map_point.dart';
import 'views/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MapProjectAdapter());
  Hive.registerAdapter(MapPointAdapter());
  await Hive.openBox<MapProject>('mapProjects');
  await Hive.openBox<MapPoint>('mapPoints');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LandMappin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.white,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'NotoSans',
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
        fontFamily: 'NotoSans',
      ),
      home: const HomePage(title: 'LandMappin'),
    );
  }
}
