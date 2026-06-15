import 'package:equatable/equatable.dart';

enum SortOption {
  aToZ,
  zToA,
  firstModified,
  lastModified,
  sizeSmallToLarge,
  sizeLargeToSmall,
  filesFirst
  ;

  String get label {
    switch (this) {
      case SortOption.aToZ:
        return 'A-Z';
      case SortOption.zToA:
        return 'Z-A';
      case SortOption.firstModified:
        return 'First Modified';
      case SortOption.lastModified:
        return 'Last Modified';
      case SortOption.sizeSmallToLarge:
        return 'Size (Small to Large)';
      case SortOption.sizeLargeToSmall:
        return 'Size (Large to Small)';
      case SortOption.filesFirst:
        return 'Files First';
    }
  }
}

class SortSettings extends Equatable {
  final SortOption option;

  const SortSettings({this.option = SortOption.aToZ});

  @override
  List<Object?> get props => [option];

  SortSettings copyWith({SortOption? option}) {
    return SortSettings(option: option ?? this.option);
  }

  Map<String, dynamic> toJson() => {'option': option.name};

  factory SortSettings.fromJson(Map<String, dynamic> json) {
    return SortSettings(
      option: SortOption.values.firstWhere(
        (e) => e.name == json['option'],
        orElse: () => SortOption.aToZ,
      ),
    );
  }
}
