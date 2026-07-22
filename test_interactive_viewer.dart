import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('InteractiveViewer Clamping Test')),
        body: const TestWidget(),
      ),
    );
  }
}

class TestWidget extends StatefulWidget {
  const TestWidget({Key? key}) : super(key: key);

  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  final TransformationController _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final value = _controller.value;
    final dx = value.getTranslation().x;
    // Clamp dx between -100 and 0
    double clampedDx = dx.clamp(-100.0, 0.0);
    
    if ((dx - clampedDx).abs() > 0.1) {
      final Matrix4 clamped = value.clone();
      clamped.setTranslationRaw(clampedDx, value.getTranslation().y, 0);
      _controller.value = clamped;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(
        child: Container(
          width: 200,
          height: 200,
          color: Colors.red,
          child: const Center(child: Text('Pan me', style: TextStyle(color: Colors.white))),
        ),
      ),
    );
  }
}
