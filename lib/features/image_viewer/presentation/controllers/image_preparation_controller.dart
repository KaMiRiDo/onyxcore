import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/image_viewer/utils/special_image_converter.dart';

class ImagePreparationController extends ChangeNotifier {

  ImagePreparationController({
    this.converter,
  });
  final Future<String?> Function(String)? converter;

  bool _isConverting = false;
  String? _preparedPath;
  int _generation = 0;
  bool _isDisposed = false;

  bool get isConverting => _isConverting;
  String? get preparedPath => _preparedPath;

  Future<void> prepare(String sourcePath) async {
    if (_isDisposed) return;

    final currentGeneration = ++_generation;

    final ext = sourcePath.toLowerCase();
    final isSpecial = ext.endsWith('.heic') ||
        ext.endsWith('.heif') ||
        ext.endsWith('.avif') ||
        ext.endsWith('.dng') ||
        ext.endsWith('.raw');

    if (!isSpecial) {
      if (_isConverting || _preparedPath != null) {
        _isConverting = false;
        _preparedPath = null;
        notifyListeners();
      }
      return;
    }

    _isConverting = true;
    _preparedPath = null;
    notifyListeners();

    final converterFunc = converter ?? SpecialImageConverter.convertIfNecessary;
    final resultPath = await converterFunc(sourcePath);

    if (_isDisposed || _generation != currentGeneration) {
      return; // Stale result due to disposal or rapid media switching
    }

    _preparedPath = resultPath;
    _isConverting = false;
    notifyListeners();
  }

  void reset() {
    if (_isDisposed) return;
    _generation++;
    _isConverting = false;
    _preparedPath = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
