import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        return InteractiveViewer(
          scaleEnabled: true,
          panEnabled: true,
          child: Container(color: Colors.red, width: 1000, height: 1000),
        );
      }),
    ),
  ));
}
