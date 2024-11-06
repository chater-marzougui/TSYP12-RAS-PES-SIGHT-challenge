import 'dart:async';
import 'package:cleaner_tunisia/helpers/robot_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'values/app_preferences.dart';
import 'bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final appPreferences = AppPreferences(prefs);
  await appPreferences.initDefaults();
  await Firebase.initializeApp();
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RobotProvider()),
      ],
      child: MyApp(appPreferences: appPreferences,)
    )
  );
}

class MyApp extends StatefulWidget {
  final AppPreferences appPreferences;

  const MyApp({super.key, required this.appPreferences});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String _userId = 'user1';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    _userId = widget.appPreferences.getUserId(); // Assuming this method exists in AppPreferences
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaner Tunisia',
      theme: _lightTheme(),
      home: HomePage(userID: _userId),
    );
  }
  ThemeData _lightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Colors.blueAccent,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: Colors.black87, fontSize: 57),
        displayMedium: TextStyle(color: Colors.black87, fontSize: 45),
        displaySmall: TextStyle(color: Colors.black87, fontSize: 36),
        headlineLarge: TextStyle(color: Colors.black87, fontSize: 32),
        headlineMedium: TextStyle(color: Colors.black87, fontSize: 28),
        headlineSmall: TextStyle(color: Colors.black87, fontSize: 24),
        titleLarge: TextStyle(color: Colors.black87, fontSize: 22),
        titleMedium: TextStyle(color: Colors.black87, fontSize: 16),
        titleSmall: TextStyle(color: Colors.black87, fontSize: 14),
        bodyLarge: TextStyle(color: Colors.black87, fontSize: 20),
        bodyMedium: TextStyle(color: Colors.black87, fontSize: 18),
        bodySmall: TextStyle(color: Colors.black87, fontSize: 15),
        labelLarge: TextStyle(color: Colors.black87, fontSize: 14),
        labelMedium: TextStyle(color: Colors.black87, fontSize: 12),
        labelSmall: TextStyle(color: Colors.black87, fontSize: 10),
      ),
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.white70,
      dialogBackgroundColor: Colors.white,
      dividerColor: Colors.grey[300],
      iconTheme: IconThemeData(color: Colors.black87),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white70),
          textStyle: WidgetStateProperty.all(TextStyle(color: Colors.blueAccent, fontSize: 16)),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: Colors.blueAccent,
        textTheme: ButtonTextTheme.primary,
      ),
      colorScheme: ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.blueAccent[700]!,
        surface: Colors.white,
        tertiary: Colors.grey[600],
        error: Colors.red[700]!,
      ),
    );
  }
}