import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/services/deno_extractor_runtime_service.dart';

class CustomExtractorNotifier extends AsyncNotifier<List<CustomExtractor>> {
  @override
  Future<List<CustomExtractor>> build() async {
    final db = ref.watch(databaseProvider);
    final entries = await db.getAllExtractors();
    return entries.map((e) => CustomExtractor(
      id: e.id,
      name: e.name,
      script: e.script,
      createdAt: DateTime.fromMillisecondsSinceEpoch(e.createdAt),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(e.modifiedAt),
    )).toList();
  }

  Future<void> addExtractor(CustomExtractor extractor) async {
    final db = ref.read(databaseProvider);
    await db.upsertExtractor(
      extractor.id,
      extractor.name,
      extractor.script,
      extractor.createdAt.millisecondsSinceEpoch,
      extractor.modifiedAt.millisecondsSinceEpoch,
    );
    final current = state.value ?? [];
    state = AsyncValue.data([...current, extractor]);
  }

  Future<void> updateExtractor(CustomExtractor extractor) async {
    final db = ref.read(databaseProvider);
    await db.upsertExtractor(
      extractor.id,
      extractor.name,
      extractor.script,
      extractor.createdAt.millisecondsSinceEpoch,
      extractor.modifiedAt.millisecondsSinceEpoch,
    );
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((e) => e.id == extractor.id ? extractor : e).toList(),
    );
  }

  Future<void> deleteExtractor(String id) async {
    final db = ref.read(databaseProvider);
    await db.deleteExtractor(id);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != id).toList());
  }
}

final customExtractorsProvider = AsyncNotifierProvider<CustomExtractorNotifier, List<CustomExtractor>>(
  CustomExtractorNotifier.new,
);

class DummyExtractorRuntimeService implements ExtractorRuntimeService {
  @override
  Future<ExtractorResult> execute(
    CustomExtractor extractor,
    String url, {
    BrowserInfo? browser,
    ExtractorRuntimeConfig? config,
    void Function(String)? onLog,
    void Function(int pid)? onProcessStarted,
  }) async {
    // Return empty result for tests
    return ExtractorResult([], 'Dummy logs');
  }
}

final extractorRuntimeServiceProvider = Provider<ExtractorRuntimeService>((ref) {
  return DenoExtractorRuntimeService();
});
