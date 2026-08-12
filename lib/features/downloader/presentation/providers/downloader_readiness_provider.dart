import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class DownloaderReadinessState {
  const DownloaderReadinessState({
    this.isReady = false,
    this.needsInstall = false,
    this.isChecking = false,
  });

  final bool isReady;
  final bool needsInstall;
  final bool isChecking;

  DownloaderReadinessState copyWith({
    bool? isReady,
    bool? needsInstall,
    bool? isChecking,
  }) {
    return DownloaderReadinessState(
      isReady: isReady ?? this.isReady,
      needsInstall: needsInstall ?? this.needsInstall,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class DownloaderReadinessNotifier extends AsyncNotifier<DownloaderReadinessState> {
  @override
  Future<DownloaderReadinessState> build() async {
    return _checkReadiness();
  }

  Future<DownloaderReadinessState> _checkReadiness() async {
    // Determine if all required binaries are installed.
    final allReady = EngineRegistry.allRequiredReady;
    if (allReady) {
      return const DownloaderReadinessState(isReady: true);
    } else {
      return const DownloaderReadinessState(needsInstall: true);
    }
  }

  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _checkReadiness());
  }
}

final downloaderReadinessProvider =
    AsyncNotifierProvider<DownloaderReadinessNotifier, DownloaderReadinessState>(
      DownloaderReadinessNotifier.new,
    );
