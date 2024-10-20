import 'package:flutter/material.dart';
import 'home_page.dart'; // Import the HomePage file
import 'sensor_data.dart'; // Import the new SensorDataWidget

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(), // HomePage is the initial route
      },
    );
  }
}
