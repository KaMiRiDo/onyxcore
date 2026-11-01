import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';

/// Presentation state for configuring a duplicate comparison run.
class CompareConfigState extends Equatable {
  const CompareConfigState({
    this.sourceFolder = '',
    this.destinationFolder = '',
    this.category = ComparisonCategory.all,
    this.errorMessage,
    this.isValid = false,
  });

  final String sourceFolder;
  final String destinationFolder;
  final ComparisonCategory category;
  final String? errorMessage;
  final bool isValid;

  CompareConfigState copyWith({
    String? sourceFolder,
    String? destinationFolder,
    ComparisonCategory? category,
    String? errorMessage,
    bool? isValid,
    bool clearError = false,
  }) {
    return CompareConfigState(
      sourceFolder: sourceFolder ?? this.sourceFolder,
      destinationFolder: destinationFolder ?? this.destinationFolder,
      category: category ?? this.category,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isValid: isValid ?? this.isValid,
    );
  }

  @override
  List<Object?> get props => [
    sourceFolder,
    destinationFolder,
    category,
    errorMessage,
    isValid,
  ];
}

/// Manages comparison configuration state and folder validation.
class CompareConfigNotifier extends Notifier<CompareConfigState> {
  CompareConfigNotifier({
    String initialSource = '',
    String initialDestination = '',
    ComparisonCategory initialCategory = ComparisonCategory.all,
  }) : _initialSource = initialSource,
       _initialDestination = initialDestination,
       _initialCategory = initialCategory;

  final String _initialSource;
  final String _initialDestination;
  final ComparisonCategory _initialCategory;

  @override
  CompareConfigState build() {
    return CompareConfigState(
      sourceFolder: _initialSource,
      destinationFolder: _initialDestination,
      category: _initialCategory,
    );
  }

  void setSourceFolder(String path) {
    state = state.copyWith(sourceFolder: path.trim());
    validate();
  }

  void setDestinationFolder(String path) {
    state = state.copyWith(destinationFolder: path.trim());
    validate();
  }

  void setCategory(ComparisonCategory category) {
    state = state.copyWith(category: category);
  }

  void validate() {
    final src = state.sourceFolder.trim();
    final dst = state.destinationFolder.trim();

    if (src.isEmpty) {
      state = state.copyWith(
        isValid: false,
        errorMessage: 'Source folder cannot be empty.',
      );
      return;
    }

    if (dst.isEmpty) {
      state = state.copyWith(
        isValid: false,
        errorMessage: 'Destination folder cannot be empty.',
      );
      return;
    }

    if (src == dst) {
      state = state.copyWith(
        isValid: false,
        errorMessage: 'Source and destination folders cannot be the same.',
      );
      return;
    }

    if (!Directory(src).existsSync()) {
      state = state.copyWith(
        isValid: false,
        errorMessage: 'Source folder does not exist or is inaccessible.',
      );
      return;
    }

    if (!Directory(dst).existsSync()) {
      state = state.copyWith(
        isValid: false,
        errorMessage: 'Destination folder does not exist or is inaccessible.',
      );
      return;
    }

    state = state.copyWith(isValid: true, clearError: true);
  }

  ComparisonRequest? buildRequest() {
    validate();
    if (!state.isValid) return null;

    return ComparisonRequest(
      sourceFolder: state.sourceFolder,
      destinationFolder: state.destinationFolder,
      category: state.category,
    );
  }
}

final compareConfigProvider =
    NotifierProvider<CompareConfigNotifier, CompareConfigState>(
      CompareConfigNotifier.new,
    );
