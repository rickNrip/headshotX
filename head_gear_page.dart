import 'package:flutter/material.dart';

class HeadGearPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Head Gear'),
      ),
      body: Center(
        child: Text(
          'This is the Head Gear page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
