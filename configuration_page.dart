// ConfigurationPage
import 'package:flutter/material.dart';

class ConfigurationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuration'),
      ),
      body: Center(
        child: Text(
          'This is the Configuration page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
