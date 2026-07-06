// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FolderSortPreferencesTable extends FolderSortPreferences
    with TableInfo<$FolderSortPreferencesTable, FolderSortPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderSortPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderPath, sortKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folder_sort_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderSortPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sortKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderPath};
  @override
  FolderSortPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderSortPreference(
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
    );
  }

  @override
  $FolderSortPreferencesTable createAlias(String alias) {
    return $FolderSortPreferencesTable(attachedDatabase, alias);
  }
}

class FolderSortPreference extends DataClass
    implements Insertable<FolderSortPreference> {
  final String folderPath;
  final String sortKey;
  const FolderSortPreference({required this.folderPath, required this.sortKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_path'] = Variable<String>(folderPath);
    map['sort_key'] = Variable<String>(sortKey);
    return map;
  }

  FolderSortPreferencesCompanion toCompanion(bool nullToAbsent) {
    return FolderSortPreferencesCompanion(
      folderPath: Value(folderPath),
      sortKey: Value(sortKey),
    );
  }

  factory FolderSortPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderSortPreference(
      folderPath: serializer.fromJson<String>(json['folderPath']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderPath': serializer.toJson<String>(folderPath),
      'sortKey': serializer.toJson<String>(sortKey),
    };
  }

  FolderSortPreference copyWith({String? folderPath, String? sortKey}) =>
      FolderSortPreference(
        folderPath: folderPath ?? this.folderPath,
        sortKey: sortKey ?? this.sortKey,
      );
  FolderSortPreference copyWithCompanion(FolderSortPreferencesCompanion data) {
    return FolderSortPreference(
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderSortPreference(')
          ..write('folderPath: $folderPath, ')
          ..write('sortKey: $sortKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderPath, sortKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderSortPreference &&
          other.folderPath == this.folderPath &&
          other.sortKey == this.sortKey);
}

class FolderSortPreferencesCompanion
    extends UpdateCompanion<FolderSortPreference> {
  final Value<String> folderPath;
  final Value<String> sortKey;
  final Value<int> rowid;
  const FolderSortPreferencesCompanion({
    this.folderPath = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FolderSortPreferencesCompanion.insert({
    required String folderPath,
    required String sortKey,
    this.rowid = const Value.absent(),
  }) : folderPath = Value(folderPath),
       sortKey = Value(sortKey);
  static Insertable<FolderSortPreference> custom({
    Expression<String>? folderPath,
    Expression<String>? sortKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderPath != null) 'folder_path': folderPath,
      if (sortKey != null) 'sort_key': sortKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FolderSortPreferencesCompanion copyWith({
    Value<String>? folderPath,
    Value<String>? sortKey,
    Value<int>? rowid,
  }) {
    return FolderSortPreferencesCompanion(
      folderPath: folderPath ?? this.folderPath,
      sortKey: sortKey ?? this.sortKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderSortPreferencesCompanion(')
          ..write('folderPath: $folderPath, ')
          ..write('sortKey: $sortKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PinnedFoldersTable extends PinnedFolders
    with TableInfo<$PinnedFoldersTable, PinnedFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinnedFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderPath, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pinned_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PinnedFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderPath};
  @override
  PinnedFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinnedFolder(
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PinnedFoldersTable createAlias(String alias) {
    return $PinnedFoldersTable(attachedDatabase, alias);
  }
}

class PinnedFolder extends DataClass implements Insertable<PinnedFolder> {
  final String folderPath;
  final int position;
  const PinnedFolder({required this.folderPath, required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_path'] = Variable<String>(folderPath);
    map['position'] = Variable<int>(position);
    return map;
  }

  PinnedFoldersCompanion toCompanion(bool nullToAbsent) {
    return PinnedFoldersCompanion(
      folderPath: Value(folderPath),
      position: Value(position),
    );
  }

  factory PinnedFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinnedFolder(
      folderPath: serializer.fromJson<String>(json['folderPath']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderPath': serializer.toJson<String>(folderPath),
      'position': serializer.toJson<int>(position),
    };
  }

  PinnedFolder copyWith({String? folderPath, int? position}) => PinnedFolder(
    folderPath: folderPath ?? this.folderPath,
    position: position ?? this.position,
  );
  PinnedFolder copyWithCompanion(PinnedFoldersCompanion data) {
    return PinnedFolder(
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinnedFolder(')
          ..write('folderPath: $folderPath, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderPath, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinnedFolder &&
          other.folderPath == this.folderPath &&
          other.position == this.position);
}

class PinnedFoldersCompanion extends UpdateCompanion<PinnedFolder> {
  final Value<String> folderPath;
  final Value<int> position;
  final Value<int> rowid;
  const PinnedFoldersCompanion({
    this.folderPath = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PinnedFoldersCompanion.insert({
    required String folderPath,
    required int position,
    this.rowid = const Value.absent(),
  }) : folderPath = Value(folderPath),
       position = Value(position);
  static Insertable<PinnedFolder> custom({
    Expression<String>? folderPath,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderPath != null) 'folder_path': folderPath,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PinnedFoldersCompanion copyWith({
    Value<String>? folderPath,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PinnedFoldersCompanion(
      folderPath: folderPath ?? this.folderPath,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinnedFoldersCompanion(')
          ..write('folderPath: $folderPath, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PinnedItemsTable extends PinnedItems
    with TableInfo<$PinnedItemsTable, PinnedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinnedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemPathMeta = const VerificationMeta(
    'itemPath',
  );
  @override
  late final GeneratedColumn<String> itemPath = GeneratedColumn<String>(
    'item_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<int> pinnedAt = GeneratedColumn<int>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [itemPath, pinnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pinned_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PinnedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_path')) {
      context.handle(
        _itemPathMeta,
        itemPath.isAcceptableOrUnknown(data['item_path']!, _itemPathMeta),
      );
    } else if (isInserting) {
      context.missing(_itemPathMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemPath};
  @override
  PinnedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinnedItem(
      itemPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_path'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $PinnedItemsTable createAlias(String alias) {
    return $PinnedItemsTable(attachedDatabase, alias);
  }
}

class PinnedItem extends DataClass implements Insertable<PinnedItem> {
  final String itemPath;
  final int pinnedAt;
  const PinnedItem({required this.itemPath, required this.pinnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_path'] = Variable<String>(itemPath);
    map['pinned_at'] = Variable<int>(pinnedAt);
    return map;
  }

  PinnedItemsCompanion toCompanion(bool nullToAbsent) {
    return PinnedItemsCompanion(
      itemPath: Value(itemPath),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory PinnedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinnedItem(
      itemPath: serializer.fromJson<String>(json['itemPath']),
      pinnedAt: serializer.fromJson<int>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemPath': serializer.toJson<String>(itemPath),
      'pinnedAt': serializer.toJson<int>(pinnedAt),
    };
  }

  PinnedItem copyWith({String? itemPath, int? pinnedAt}) => PinnedItem(
    itemPath: itemPath ?? this.itemPath,
    pinnedAt: pinnedAt ?? this.pinnedAt,
  );
  PinnedItem copyWithCompanion(PinnedItemsCompanion data) {
    return PinnedItem(
      itemPath: data.itemPath.present ? data.itemPath.value : this.itemPath,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PinnedItem(')
          ..write('itemPath: $itemPath, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemPath, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinnedItem &&
          other.itemPath == this.itemPath &&
          other.pinnedAt == this.pinnedAt);
}

class PinnedItemsCompanion extends UpdateCompanion<PinnedItem> {
  final Value<String> itemPath;
  final Value<int> pinnedAt;
  final Value<int> rowid;
  const PinnedItemsCompanion({
    this.itemPath = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PinnedItemsCompanion.insert({
    required String itemPath,
    required int pinnedAt,
    this.rowid = const Value.absent(),
  }) : itemPath = Value(itemPath),
       pinnedAt = Value(pinnedAt);
  static Insertable<PinnedItem> custom({
    Expression<String>? itemPath,
    Expression<int>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemPath != null) 'item_path': itemPath,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PinnedItemsCompanion copyWith({
    Value<String>? itemPath,
    Value<int>? pinnedAt,
    Value<int>? rowid,
  }) {
    return PinnedItemsCompanion(
      itemPath: itemPath ?? this.itemPath,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemPath.present) {
      map['item_path'] = Variable<String>(itemPath.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<int>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinnedItemsCompanion(')
          ..write('itemPath: $itemPath, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetadataCacheEntriesTable extends MetadataCacheEntries
    with TableInfo<$MetadataCacheEntriesTable, MetadataCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetadataCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aspectRatioMeta = const VerificationMeta(
    'aspectRatio',
  );
  @override
  late final GeneratedColumn<double> aspectRatio = GeneratedColumn<double>(
    'aspect_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filePath, aspectRatio, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metadata_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetadataCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('aspect_ratio')) {
      context.handle(
        _aspectRatioMeta,
        aspectRatio.isAcceptableOrUnknown(
          data['aspect_ratio']!,
          _aspectRatioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aspectRatioMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  MetadataCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetadataCacheEntry(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      aspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aspect_ratio'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $MetadataCacheEntriesTable createAlias(String alias) {
    return $MetadataCacheEntriesTable(attachedDatabase, alias);
  }
}

class MetadataCacheEntry extends DataClass
    implements Insertable<MetadataCacheEntry> {
  final String filePath;
  final double aspectRatio;
  final int cachedAt;
  const MetadataCacheEntry({
    required this.filePath,
    required this.aspectRatio,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    map['aspect_ratio'] = Variable<double>(aspectRatio);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  MetadataCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetadataCacheEntriesCompanion(
      filePath: Value(filePath),
      aspectRatio: Value(aspectRatio),
      cachedAt: Value(cachedAt),
    );
  }

  factory MetadataCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetadataCacheEntry(
      filePath: serializer.fromJson<String>(json['filePath']),
      aspectRatio: serializer.fromJson<double>(json['aspectRatio']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'aspectRatio': serializer.toJson<double>(aspectRatio),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  MetadataCacheEntry copyWith({
    String? filePath,
    double? aspectRatio,
    int? cachedAt,
  }) => MetadataCacheEntry(
    filePath: filePath ?? this.filePath,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  MetadataCacheEntry copyWithCompanion(MetadataCacheEntriesCompanion data) {
    return MetadataCacheEntry(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      aspectRatio: data.aspectRatio.present
          ? data.aspectRatio.value
          : this.aspectRatio,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetadataCacheEntry(')
          ..write('filePath: $filePath, ')
          ..write('aspectRatio: $aspectRatio, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filePath, aspectRatio, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetadataCacheEntry &&
          other.filePath == this.filePath &&
          other.aspectRatio == this.aspectRatio &&
          other.cachedAt == this.cachedAt);
}

class MetadataCacheEntriesCompanion
    extends UpdateCompanion<MetadataCacheEntry> {
  final Value<String> filePath;
  final Value<double> aspectRatio;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const MetadataCacheEntriesCompanion({
    this.filePath = const Value.absent(),
    this.aspectRatio = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetadataCacheEntriesCompanion.insert({
    required String filePath,
    required double aspectRatio,
    required int cachedAt,
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath),
       aspectRatio = Value(aspectRatio),
       cachedAt = Value(cachedAt);
  static Insertable<MetadataCacheEntry> custom({
    Expression<String>? filePath,
    Expression<double>? aspectRatio,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (aspectRatio != null) 'aspect_ratio': aspectRatio,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetadataCacheEntriesCompanion copyWith({
    Value<String>? filePath,
    Value<double>? aspectRatio,
    Value<int>? cachedAt,
    Value<int>? rowid,
  }) {
    return MetadataCacheEntriesCompanion(
      filePath: filePath ?? this.filePath,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (aspectRatio.present) {
      map['aspect_ratio'] = Variable<double>(aspectRatio.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetadataCacheEntriesCompanion(')
          ..write('filePath: $filePath, ')
          ..write('aspectRatio: $aspectRatio, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackMemoryEntriesTable extends PlaybackMemoryEntries
    with TableInfo<$PlaybackMemoryEntriesTable, PlaybackMemoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackMemoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filePath, positionMs, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_memory';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackMemoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  PlaybackMemoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackMemoryEntry(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackMemoryEntriesTable createAlias(String alias) {
    return $PlaybackMemoryEntriesTable(attachedDatabase, alias);
  }
}

class PlaybackMemoryEntry extends DataClass
    implements Insertable<PlaybackMemoryEntry> {
  final String filePath;
  final int positionMs;
  final int updatedAt;
  const PlaybackMemoryEntry({
    required this.filePath,
    required this.positionMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    map['position_ms'] = Variable<int>(positionMs);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaybackMemoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaybackMemoryEntriesCompanion(
      filePath: Value(filePath),
      positionMs: Value(positionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackMemoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackMemoryEntry(
      filePath: serializer.fromJson<String>(json['filePath']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'positionMs': serializer.toJson<int>(positionMs),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackMemoryEntry copyWith({
    String? filePath,
    int? positionMs,
    int? updatedAt,
  }) => PlaybackMemoryEntry(
    filePath: filePath ?? this.filePath,
    positionMs: positionMs ?? this.positionMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackMemoryEntry copyWithCompanion(PlaybackMemoryEntriesCompanion data) {
    return PlaybackMemoryEntry(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackMemoryEntry(')
          ..write('filePath: $filePath, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filePath, positionMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackMemoryEntry &&
          other.filePath == this.filePath &&
          other.positionMs == this.positionMs &&
          other.updatedAt == this.updatedAt);
}

class PlaybackMemoryEntriesCompanion
    extends UpdateCompanion<PlaybackMemoryEntry> {
  final Value<String> filePath;
  final Value<int> positionMs;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PlaybackMemoryEntriesCompanion({
    this.filePath = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackMemoryEntriesCompanion.insert({
    required String filePath,
    required int positionMs,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath),
       positionMs = Value(positionMs),
       updatedAt = Value(updatedAt);
  static Insertable<PlaybackMemoryEntry> custom({
    Expression<String>? filePath,
    Expression<int>? positionMs,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (positionMs != null) 'position_ms': positionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackMemoryEntriesCompanion copyWith({
    Value<String>? filePath,
    Value<int>? positionMs,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackMemoryEntriesCompanion(
      filePath: filePath ?? this.filePath,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackMemoryEntriesCompanion(')
          ..write('filePath: $filePath, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioFavoriteEntriesTable extends AudioFavoriteEntries
    with TableInfo<$AudioFavoriteEntriesTable, AudioFavoriteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioFavoriteEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filePath, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioFavoriteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  AudioFavoriteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioFavoriteEntry(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $AudioFavoriteEntriesTable createAlias(String alias) {
    return $AudioFavoriteEntriesTable(attachedDatabase, alias);
  }
}

class AudioFavoriteEntry extends DataClass
    implements Insertable<AudioFavoriteEntry> {
  final String filePath;
  final int favoritedAt;
  const AudioFavoriteEntry({required this.filePath, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    map['favorited_at'] = Variable<int>(favoritedAt);
    return map;
  }

  AudioFavoriteEntriesCompanion toCompanion(bool nullToAbsent) {
    return AudioFavoriteEntriesCompanion(
      filePath: Value(filePath),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory AudioFavoriteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioFavoriteEntry(
      filePath: serializer.fromJson<String>(json['filePath']),
      favoritedAt: serializer.fromJson<int>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'favoritedAt': serializer.toJson<int>(favoritedAt),
    };
  }

  AudioFavoriteEntry copyWith({String? filePath, int? favoritedAt}) =>
      AudioFavoriteEntry(
        filePath: filePath ?? this.filePath,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  AudioFavoriteEntry copyWithCompanion(AudioFavoriteEntriesCompanion data) {
    return AudioFavoriteEntry(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioFavoriteEntry(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filePath, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioFavoriteEntry &&
          other.filePath == this.filePath &&
          other.favoritedAt == this.favoritedAt);
}

class AudioFavoriteEntriesCompanion
    extends UpdateCompanion<AudioFavoriteEntry> {
  final Value<String> filePath;
  final Value<int> favoritedAt;
  final Value<int> rowid;
  const AudioFavoriteEntriesCompanion({
    this.filePath = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioFavoriteEntriesCompanion.insert({
    required String filePath,
    required int favoritedAt,
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath),
       favoritedAt = Value(favoritedAt);
  static Insertable<AudioFavoriteEntry> custom({
    Expression<String>? filePath,
    Expression<int>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioFavoriteEntriesCompanion copyWith({
    Value<String>? filePath,
    Value<int>? favoritedAt,
    Value<int>? rowid,
  }) {
    return AudioFavoriteEntriesCompanion(
      filePath: filePath ?? this.filePath,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioFavoriteEntriesCompanion(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VideoFavoriteEntriesTable extends VideoFavoriteEntries
    with TableInfo<$VideoFavoriteEntriesTable, VideoFavoriteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VideoFavoriteEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filePath, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'video_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<VideoFavoriteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  VideoFavoriteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VideoFavoriteEntry(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $VideoFavoriteEntriesTable createAlias(String alias) {
    return $VideoFavoriteEntriesTable(attachedDatabase, alias);
  }
}

class VideoFavoriteEntry extends DataClass
    implements Insertable<VideoFavoriteEntry> {
  final String filePath;
  final int favoritedAt;
  const VideoFavoriteEntry({required this.filePath, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    map['favorited_at'] = Variable<int>(favoritedAt);
    return map;
  }

  VideoFavoriteEntriesCompanion toCompanion(bool nullToAbsent) {
    return VideoFavoriteEntriesCompanion(
      filePath: Value(filePath),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory VideoFavoriteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VideoFavoriteEntry(
      filePath: serializer.fromJson<String>(json['filePath']),
      favoritedAt: serializer.fromJson<int>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'favoritedAt': serializer.toJson<int>(favoritedAt),
    };
  }

  VideoFavoriteEntry copyWith({String? filePath, int? favoritedAt}) =>
      VideoFavoriteEntry(
        filePath: filePath ?? this.filePath,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  VideoFavoriteEntry copyWithCompanion(VideoFavoriteEntriesCompanion data) {
    return VideoFavoriteEntry(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VideoFavoriteEntry(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filePath, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoFavoriteEntry &&
          other.filePath == this.filePath &&
          other.favoritedAt == this.favoritedAt);
}

class VideoFavoriteEntriesCompanion
    extends UpdateCompanion<VideoFavoriteEntry> {
  final Value<String> filePath;
  final Value<int> favoritedAt;
  final Value<int> rowid;
  const VideoFavoriteEntriesCompanion({
    this.filePath = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VideoFavoriteEntriesCompanion.insert({
    required String filePath,
    required int favoritedAt,
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath),
       favoritedAt = Value(favoritedAt);
  static Insertable<VideoFavoriteEntry> custom({
    Expression<String>? filePath,
    Expression<int>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VideoFavoriteEntriesCompanion copyWith({
    Value<String>? filePath,
    Value<int>? favoritedAt,
    Value<int>? rowid,
  }) {
    return VideoFavoriteEntriesCompanion(
      filePath: filePath ?? this.filePath,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideoFavoriteEntriesCompanion(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageFavoriteEntriesTable extends ImageFavoriteEntries
    with TableInfo<$ImageFavoriteEntriesTable, ImageFavoriteEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageFavoriteEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favoritedAtMeta = const VerificationMeta(
    'favoritedAt',
  );
  @override
  late final GeneratedColumn<int> favoritedAt = GeneratedColumn<int>(
    'favorited_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filePath, favoritedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageFavoriteEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('favorited_at')) {
      context.handle(
        _favoritedAtMeta,
        favoritedAt.isAcceptableOrUnknown(
          data['favorited_at']!,
          _favoritedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favoritedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filePath};
  @override
  ImageFavoriteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageFavoriteEntry(
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      favoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorited_at'],
      )!,
    );
  }

  @override
  $ImageFavoriteEntriesTable createAlias(String alias) {
    return $ImageFavoriteEntriesTable(attachedDatabase, alias);
  }
}

class ImageFavoriteEntry extends DataClass
    implements Insertable<ImageFavoriteEntry> {
  final String filePath;
  final int favoritedAt;
  const ImageFavoriteEntry({required this.filePath, required this.favoritedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_path'] = Variable<String>(filePath);
    map['favorited_at'] = Variable<int>(favoritedAt);
    return map;
  }

  ImageFavoriteEntriesCompanion toCompanion(bool nullToAbsent) {
    return ImageFavoriteEntriesCompanion(
      filePath: Value(filePath),
      favoritedAt: Value(favoritedAt),
    );
  }

  factory ImageFavoriteEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageFavoriteEntry(
      filePath: serializer.fromJson<String>(json['filePath']),
      favoritedAt: serializer.fromJson<int>(json['favoritedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filePath': serializer.toJson<String>(filePath),
      'favoritedAt': serializer.toJson<int>(favoritedAt),
    };
  }

  ImageFavoriteEntry copyWith({String? filePath, int? favoritedAt}) =>
      ImageFavoriteEntry(
        filePath: filePath ?? this.filePath,
        favoritedAt: favoritedAt ?? this.favoritedAt,
      );
  ImageFavoriteEntry copyWithCompanion(ImageFavoriteEntriesCompanion data) {
    return ImageFavoriteEntry(
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      favoritedAt: data.favoritedAt.present
          ? data.favoritedAt.value
          : this.favoritedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageFavoriteEntry(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filePath, favoritedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageFavoriteEntry &&
          other.filePath == this.filePath &&
          other.favoritedAt == this.favoritedAt);
}

class ImageFavoriteEntriesCompanion
    extends UpdateCompanion<ImageFavoriteEntry> {
  final Value<String> filePath;
  final Value<int> favoritedAt;
  final Value<int> rowid;
  const ImageFavoriteEntriesCompanion({
    this.filePath = const Value.absent(),
    this.favoritedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageFavoriteEntriesCompanion.insert({
    required String filePath,
    required int favoritedAt,
    this.rowid = const Value.absent(),
  }) : filePath = Value(filePath),
       favoritedAt = Value(favoritedAt);
  static Insertable<ImageFavoriteEntry> custom({
    Expression<String>? filePath,
    Expression<int>? favoritedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filePath != null) 'file_path': filePath,
      if (favoritedAt != null) 'favorited_at': favoritedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageFavoriteEntriesCompanion copyWith({
    Value<String>? filePath,
    Value<int>? favoritedAt,
    Value<int>? rowid,
  }) {
    return ImageFavoriteEntriesCompanion(
      filePath: filePath ?? this.filePath,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (favoritedAt.present) {
      map['favorited_at'] = Variable<int>(favoritedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageFavoriteEntriesCompanion(')
          ..write('filePath: $filePath, ')
          ..write('favoritedAt: $favoritedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomEmojiSetEntriesTable extends CustomEmojiSetEntries
    with TableInfo<$CustomEmojiSetEntriesTable, CustomEmojiSetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomEmojiSetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawDataMeta = const VerificationMeta(
    'rawData',
  );
  @override
  late final GeneratedColumn<String> rawData = GeneratedColumn<String>(
    'raw_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionsMeta = const VerificationMeta(
    'definitions',
  );
  @override
  late final GeneratedColumn<String> definitions = GeneratedColumn<String>(
    'definitions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, rawData, definitions];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_emoji_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomEmojiSetEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('raw_data')) {
      context.handle(
        _rawDataMeta,
        rawData.isAcceptableOrUnknown(data['raw_data']!, _rawDataMeta),
      );
    } else if (isInserting) {
      context.missing(_rawDataMeta);
    }
    if (data.containsKey('definitions')) {
      context.handle(
        _definitionsMeta,
        definitions.isAcceptableOrUnknown(
          data['definitions']!,
          _definitionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomEmojiSetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomEmojiSetEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      rawData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_data'],
      )!,
      definitions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definitions'],
      )!,
    );
  }

  @override
  $CustomEmojiSetEntriesTable createAlias(String alias) {
    return $CustomEmojiSetEntriesTable(attachedDatabase, alias);
  }
}

class CustomEmojiSetEntry extends DataClass
    implements Insertable<CustomEmojiSetEntry> {
  final String id;
  final String rawData;
  final String definitions;
  const CustomEmojiSetEntry({
    required this.id,
    required this.rawData,
    required this.definitions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['raw_data'] = Variable<String>(rawData);
    map['definitions'] = Variable<String>(definitions);
    return map;
  }

  CustomEmojiSetEntriesCompanion toCompanion(bool nullToAbsent) {
    return CustomEmojiSetEntriesCompanion(
      id: Value(id),
      rawData: Value(rawData),
      definitions: Value(definitions),
    );
  }

  factory CustomEmojiSetEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomEmojiSetEntry(
      id: serializer.fromJson<String>(json['id']),
      rawData: serializer.fromJson<String>(json['rawData']),
      definitions: serializer.fromJson<String>(json['definitions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'rawData': serializer.toJson<String>(rawData),
      'definitions': serializer.toJson<String>(definitions),
    };
  }

  CustomEmojiSetEntry copyWith({
    String? id,
    String? rawData,
    String? definitions,
  }) => CustomEmojiSetEntry(
    id: id ?? this.id,
    rawData: rawData ?? this.rawData,
    definitions: definitions ?? this.definitions,
  );
  CustomEmojiSetEntry copyWithCompanion(CustomEmojiSetEntriesCompanion data) {
    return CustomEmojiSetEntry(
      id: data.id.present ? data.id.value : this.id,
      rawData: data.rawData.present ? data.rawData.value : this.rawData,
      definitions: data.definitions.present
          ? data.definitions.value
          : this.definitions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomEmojiSetEntry(')
          ..write('id: $id, ')
          ..write('rawData: $rawData, ')
          ..write('definitions: $definitions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, rawData, definitions);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomEmojiSetEntry &&
          other.id == this.id &&
          other.rawData == this.rawData &&
          other.definitions == this.definitions);
}

class CustomEmojiSetEntriesCompanion
    extends UpdateCompanion<CustomEmojiSetEntry> {
  final Value<String> id;
  final Value<String> rawData;
  final Value<String> definitions;
  final Value<int> rowid;
  const CustomEmojiSetEntriesCompanion({
    this.id = const Value.absent(),
    this.rawData = const Value.absent(),
    this.definitions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomEmojiSetEntriesCompanion.insert({
    required String id,
    required String rawData,
    required String definitions,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       rawData = Value(rawData),
       definitions = Value(definitions);
  static Insertable<CustomEmojiSetEntry> custom({
    Expression<String>? id,
    Expression<String>? rawData,
    Expression<String>? definitions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rawData != null) 'raw_data': rawData,
      if (definitions != null) 'definitions': definitions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomEmojiSetEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? rawData,
    Value<String>? definitions,
    Value<int>? rowid,
  }) {
    return CustomEmojiSetEntriesCompanion(
      id: id ?? this.id,
      rawData: rawData ?? this.rawData,
      definitions: definitions ?? this.definitions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rawData.present) {
      map['raw_data'] = Variable<String>(rawData.value);
    }
    if (definitions.present) {
      map['definitions'] = Variable<String>(definitions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomEmojiSetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('rawData: $rawData, ')
          ..write('definitions: $definitions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomIconSetEntriesTable extends CustomIconSetEntries
    with TableInfo<$CustomIconSetEntriesTable, CustomIconSetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomIconSetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageBytesMeta = const VerificationMeta(
    'imageBytes',
  );
  @override
  late final GeneratedColumn<String> imageBytes = GeneratedColumn<String>(
    'image_bytes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, imageBytes, tags];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_icon_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomIconSetEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('image_bytes')) {
      context.handle(
        _imageBytesMeta,
        imageBytes.isAcceptableOrUnknown(data['image_bytes']!, _imageBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_imageBytesMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomIconSetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomIconSetEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      imageBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_bytes'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $CustomIconSetEntriesTable createAlias(String alias) {
    return $CustomIconSetEntriesTable(attachedDatabase, alias);
  }
}

class CustomIconSetEntry extends DataClass
    implements Insertable<CustomIconSetEntry> {
  final String id;
  final String imageBytes;
  final String tags;
  const CustomIconSetEntry({
    required this.id,
    required this.imageBytes,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['image_bytes'] = Variable<String>(imageBytes);
    map['tags'] = Variable<String>(tags);
    return map;
  }

  CustomIconSetEntriesCompanion toCompanion(bool nullToAbsent) {
    return CustomIconSetEntriesCompanion(
      id: Value(id),
      imageBytes: Value(imageBytes),
      tags: Value(tags),
    );
  }

  factory CustomIconSetEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomIconSetEntry(
      id: serializer.fromJson<String>(json['id']),
      imageBytes: serializer.fromJson<String>(json['imageBytes']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'imageBytes': serializer.toJson<String>(imageBytes),
      'tags': serializer.toJson<String>(tags),
    };
  }

  CustomIconSetEntry copyWith({String? id, String? imageBytes, String? tags}) =>
      CustomIconSetEntry(
        id: id ?? this.id,
        imageBytes: imageBytes ?? this.imageBytes,
        tags: tags ?? this.tags,
      );
  CustomIconSetEntry copyWithCompanion(CustomIconSetEntriesCompanion data) {
    return CustomIconSetEntry(
      id: data.id.present ? data.id.value : this.id,
      imageBytes: data.imageBytes.present
          ? data.imageBytes.value
          : this.imageBytes,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomIconSetEntry(')
          ..write('id: $id, ')
          ..write('imageBytes: $imageBytes, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, imageBytes, tags);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomIconSetEntry &&
          other.id == this.id &&
          other.imageBytes == this.imageBytes &&
          other.tags == this.tags);
}

class CustomIconSetEntriesCompanion
    extends UpdateCompanion<CustomIconSetEntry> {
  final Value<String> id;
  final Value<String> imageBytes;
  final Value<String> tags;
  final Value<int> rowid;
  const CustomIconSetEntriesCompanion({
    this.id = const Value.absent(),
    this.imageBytes = const Value.absent(),
    this.tags = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomIconSetEntriesCompanion.insert({
    required String id,
    required String imageBytes,
    required String tags,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       imageBytes = Value(imageBytes),
       tags = Value(tags);
  static Insertable<CustomIconSetEntry> custom({
    Expression<String>? id,
    Expression<String>? imageBytes,
    Expression<String>? tags,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imageBytes != null) 'image_bytes': imageBytes,
      if (tags != null) 'tags': tags,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomIconSetEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? imageBytes,
    Value<String>? tags,
    Value<int>? rowid,
  }) {
    return CustomIconSetEntriesCompanion(
      id: id ?? this.id,
      imageBytes: imageBytes ?? this.imageBytes,
      tags: tags ?? this.tags,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (imageBytes.present) {
      map['image_bytes'] = Variable<String>(imageBytes.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomIconSetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('imageBytes: $imageBytes, ')
          ..write('tags: $tags, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarkerRecentEntriesTable extends MarkerRecentEntries
    with TableInfo<$MarkerRecentEntriesTable, MarkerRecentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkerRecentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedAtMeta = const VerificationMeta('usedAt');
  @override
  late final GeneratedColumn<int> usedAt = GeneratedColumn<int>(
    'used_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [value, usedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'marker_recents';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarkerRecentEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('used_at')) {
      context.handle(
        _usedAtMeta,
        usedAt.isAcceptableOrUnknown(data['used_at']!, _usedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_usedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {value};
  @override
  MarkerRecentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerRecentEntry(
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      usedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_at'],
      )!,
    );
  }

  @override
  $MarkerRecentEntriesTable createAlias(String alias) {
    return $MarkerRecentEntriesTable(attachedDatabase, alias);
  }
}

class MarkerRecentEntry extends DataClass
    implements Insertable<MarkerRecentEntry> {
  final String value;
  final int usedAt;
  const MarkerRecentEntry({required this.value, required this.usedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['value'] = Variable<String>(value);
    map['used_at'] = Variable<int>(usedAt);
    return map;
  }

  MarkerRecentEntriesCompanion toCompanion(bool nullToAbsent) {
    return MarkerRecentEntriesCompanion(
      value: Value(value),
      usedAt: Value(usedAt),
    );
  }

  factory MarkerRecentEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerRecentEntry(
      value: serializer.fromJson<String>(json['value']),
      usedAt: serializer.fromJson<int>(json['usedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'value': serializer.toJson<String>(value),
      'usedAt': serializer.toJson<int>(usedAt),
    };
  }

  MarkerRecentEntry copyWith({String? value, int? usedAt}) => MarkerRecentEntry(
    value: value ?? this.value,
    usedAt: usedAt ?? this.usedAt,
  );
  MarkerRecentEntry copyWithCompanion(MarkerRecentEntriesCompanion data) {
    return MarkerRecentEntry(
      value: data.value.present ? data.value.value : this.value,
      usedAt: data.usedAt.present ? data.usedAt.value : this.usedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRecentEntry(')
          ..write('value: $value, ')
          ..write('usedAt: $usedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(value, usedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerRecentEntry &&
          other.value == this.value &&
          other.usedAt == this.usedAt);
}

class MarkerRecentEntriesCompanion extends UpdateCompanion<MarkerRecentEntry> {
  final Value<String> value;
  final Value<int> usedAt;
  final Value<int> rowid;
  const MarkerRecentEntriesCompanion({
    this.value = const Value.absent(),
    this.usedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarkerRecentEntriesCompanion.insert({
    required String value,
    required int usedAt,
    this.rowid = const Value.absent(),
  }) : value = Value(value),
       usedAt = Value(usedAt);
  static Insertable<MarkerRecentEntry> custom({
    Expression<String>? value,
    Expression<int>? usedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (value != null) 'value': value,
      if (usedAt != null) 'used_at': usedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarkerRecentEntriesCompanion copyWith({
    Value<String>? value,
    Value<int>? usedAt,
    Value<int>? rowid,
  }) {
    return MarkerRecentEntriesCompanion(
      value: value ?? this.value,
      usedAt: usedAt ?? this.usedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (usedAt.present) {
      map['used_at'] = Variable<int>(usedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRecentEntriesCompanion(')
          ..write('value: $value, ')
          ..write('usedAt: $usedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadHistoryEntriesTable extends DownloadHistoryEntries
    with TableInfo<$DownloadHistoryEntriesTable, DownloadHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadTypeMeta = const VerificationMeta(
    'downloadType',
  );
  @override
  late final GeneratedColumn<String> downloadType = GeneratedColumn<String>(
    'download_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusNameMeta = const VerificationMeta(
    'statusName',
  );
  @override
  late final GeneratedColumn<String> statusName = GeneratedColumn<String>(
    'status_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logsMeta = const VerificationMeta('logs');
  @override
  late final GeneratedColumn<String> logs = GeneratedColumn<String>(
    'logs',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    url,
    destination,
    downloadType,
    statusName,
    errorMessage,
    createdAt,
    completedAt,
    logs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationMeta);
    }
    if (data.containsKey('download_type')) {
      context.handle(
        _downloadTypeMeta,
        downloadType.isAcceptableOrUnknown(
          data['download_type']!,
          _downloadTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadTypeMeta);
    }
    if (data.containsKey('status_name')) {
      context.handle(
        _statusNameMeta,
        statusName.isAcceptableOrUnknown(data['status_name']!, _statusNameMeta),
      );
    } else if (isInserting) {
      context.missing(_statusNameMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('logs')) {
      context.handle(
        _logsMeta,
        logs.isAcceptableOrUnknown(data['logs']!, _logsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      downloadType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_type'],
      )!,
      statusName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_name'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      logs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logs'],
      ),
    );
  }

  @override
  $DownloadHistoryEntriesTable createAlias(String alias) {
    return $DownloadHistoryEntriesTable(attachedDatabase, alias);
  }
}

class DownloadHistoryEntry extends DataClass
    implements Insertable<DownloadHistoryEntry> {
  final String id;
  final String title;
  final String url;
  final String destination;
  final String downloadType;
  final String statusName;
  final String? errorMessage;
  final int createdAt;
  final int? completedAt;
  final String? logs;
  const DownloadHistoryEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.destination,
    required this.downloadType,
    required this.statusName,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.logs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    map['destination'] = Variable<String>(destination);
    map['download_type'] = Variable<String>(downloadType);
    map['status_name'] = Variable<String>(statusName);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || logs != null) {
      map['logs'] = Variable<String>(logs);
    }
    return map;
  }

  DownloadHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DownloadHistoryEntriesCompanion(
      id: Value(id),
      title: Value(title),
      url: Value(url),
      destination: Value(destination),
      downloadType: Value(downloadType),
      statusName: Value(statusName),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      logs: logs == null && nullToAbsent ? const Value.absent() : Value(logs),
    );
  }

  factory DownloadHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadHistoryEntry(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      destination: serializer.fromJson<String>(json['destination']),
      downloadType: serializer.fromJson<String>(json['downloadType']),
      statusName: serializer.fromJson<String>(json['statusName']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      logs: serializer.fromJson<String?>(json['logs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'destination': serializer.toJson<String>(destination),
      'downloadType': serializer.toJson<String>(downloadType),
      'statusName': serializer.toJson<String>(statusName),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<int>(createdAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'logs': serializer.toJson<String?>(logs),
    };
  }

  DownloadHistoryEntry copyWith({
    String? id,
    String? title,
    String? url,
    String? destination,
    String? downloadType,
    String? statusName,
    Value<String?> errorMessage = const Value.absent(),
    int? createdAt,
    Value<int?> completedAt = const Value.absent(),
    Value<String?> logs = const Value.absent(),
  }) => DownloadHistoryEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    url: url ?? this.url,
    destination: destination ?? this.destination,
    downloadType: downloadType ?? this.downloadType,
    statusName: statusName ?? this.statusName,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    logs: logs.present ? logs.value : this.logs,
  );
  DownloadHistoryEntry copyWithCompanion(DownloadHistoryEntriesCompanion data) {
    return DownloadHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      downloadType: data.downloadType.present
          ? data.downloadType.value
          : this.downloadType,
      statusName: data.statusName.present
          ? data.statusName.value
          : this.statusName,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      logs: data.logs.present ? data.logs.value : this.logs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryEntry(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('destination: $destination, ')
          ..write('downloadType: $downloadType, ')
          ..write('statusName: $statusName, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('logs: $logs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    url,
    destination,
    downloadType,
    statusName,
    errorMessage,
    createdAt,
    completedAt,
    logs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadHistoryEntry &&
          other.id == this.id &&
          other.title == this.title &&
          other.url == this.url &&
          other.destination == this.destination &&
          other.downloadType == this.downloadType &&
          other.statusName == this.statusName &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.logs == this.logs);
}

class DownloadHistoryEntriesCompanion
    extends UpdateCompanion<DownloadHistoryEntry> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> url;
  final Value<String> destination;
  final Value<String> downloadType;
  final Value<String> statusName;
  final Value<String?> errorMessage;
  final Value<int> createdAt;
  final Value<int?> completedAt;
  final Value<String?> logs;
  final Value<int> rowid;
  const DownloadHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.destination = const Value.absent(),
    this.downloadType = const Value.absent(),
    this.statusName = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.logs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadHistoryEntriesCompanion.insert({
    required String id,
    required String title,
    required String url,
    required String destination,
    required String downloadType,
    required String statusName,
    this.errorMessage = const Value.absent(),
    required int createdAt,
    this.completedAt = const Value.absent(),
    this.logs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       url = Value(url),
       destination = Value(destination),
       downloadType = Value(downloadType),
       statusName = Value(statusName),
       createdAt = Value(createdAt);
  static Insertable<DownloadHistoryEntry> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? url,
    Expression<String>? destination,
    Expression<String>? downloadType,
    Expression<String>? statusName,
    Expression<String>? errorMessage,
    Expression<int>? createdAt,
    Expression<int>? completedAt,
    Expression<String>? logs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (destination != null) 'destination': destination,
      if (downloadType != null) 'download_type': downloadType,
      if (statusName != null) 'status_name': statusName,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (logs != null) 'logs': logs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadHistoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? url,
    Value<String>? destination,
    Value<String>? downloadType,
    Value<String>? statusName,
    Value<String?>? errorMessage,
    Value<int>? createdAt,
    Value<int?>? completedAt,
    Value<String?>? logs,
    Value<int>? rowid,
  }) {
    return DownloadHistoryEntriesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      destination: destination ?? this.destination,
      downloadType: downloadType ?? this.downloadType,
      statusName: statusName ?? this.statusName,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      logs: logs ?? this.logs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (downloadType.present) {
      map['download_type'] = Variable<String>(downloadType.value);
    }
    if (statusName.present) {
      map['status_name'] = Variable<String>(statusName.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (logs.present) {
      map['logs'] = Variable<String>(logs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('destination: $destination, ')
          ..write('downloadType: $downloadType, ')
          ..write('statusName: $statusName, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('logs: $logs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThumbnailCacheEntriesTable extends ThumbnailCacheEntries
    with TableInfo<$ThumbnailCacheEntriesTable, ThumbnailCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThumbnailCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cacheFileNormalMeta = const VerificationMeta(
    'cacheFileNormal',
  );
  @override
  late final GeneratedColumn<String> cacheFileNormal = GeneratedColumn<String>(
    'cache_file_normal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cacheFileLargeMeta = const VerificationMeta(
    'cacheFileLarge',
  );
  @override
  late final GeneratedColumn<String> cacheFileLarge = GeneratedColumn<String>(
    'cache_file_large',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<int> generatedAt = GeneratedColumn<int>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileHash,
    filePath,
    mtime,
    sizeBytes,
    cacheFileNormal,
    cacheFileLarge,
    kind,
    status,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thumbnail_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ThumbnailCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('cache_file_normal')) {
      context.handle(
        _cacheFileNormalMeta,
        cacheFileNormal.isAcceptableOrUnknown(
          data['cache_file_normal']!,
          _cacheFileNormalMeta,
        ),
      );
    }
    if (data.containsKey('cache_file_large')) {
      context.handle(
        _cacheFileLargeMeta,
        cacheFileLarge.isAcceptableOrUnknown(
          data['cache_file_large']!,
          _cacheFileLargeMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileHash};
  @override
  ThumbnailCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ThumbnailCacheEntry(
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      cacheFileNormal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_file_normal'],
      ),
      cacheFileLarge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_file_large'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generated_at'],
      )!,
    );
  }

  @override
  $ThumbnailCacheEntriesTable createAlias(String alias) {
    return $ThumbnailCacheEntriesTable(attachedDatabase, alias);
  }
}

class ThumbnailCacheEntry extends DataClass
    implements Insertable<ThumbnailCacheEntry> {
  /// MD5 hash of 'file://' + absolute path — the cache key.
  final String fileHash;

  /// Original absolute file path (for debugging and reverse lookups).
  final String filePath;

  /// Source file's last-modified time (ms since epoch) at generation time.
  final int mtime;

  /// Source file's size in bytes at generation time.
  final int sizeBytes;

  /// Path to the 128px cached thumbnail image, or null if not generated.
  final String? cacheFileNormal;

  /// Path to the 256px cached thumbnail image, or null if not generated.
  final String? cacheFileLarge;

  /// Media kind: 'image' or 'video'.
  final String kind;

  /// Cache entry status: 'ready', 'failed', or 'pending'.
  final String status;

  /// Timestamp when this cache entry was generated (ms since epoch).
  final int generatedAt;
  const ThumbnailCacheEntry({
    required this.fileHash,
    required this.filePath,
    required this.mtime,
    required this.sizeBytes,
    this.cacheFileNormal,
    this.cacheFileLarge,
    required this.kind,
    required this.status,
    required this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_hash'] = Variable<String>(fileHash);
    map['file_path'] = Variable<String>(filePath);
    map['mtime'] = Variable<int>(mtime);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || cacheFileNormal != null) {
      map['cache_file_normal'] = Variable<String>(cacheFileNormal);
    }
    if (!nullToAbsent || cacheFileLarge != null) {
      map['cache_file_large'] = Variable<String>(cacheFileLarge);
    }
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['generated_at'] = Variable<int>(generatedAt);
    return map;
  }

  ThumbnailCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return ThumbnailCacheEntriesCompanion(
      fileHash: Value(fileHash),
      filePath: Value(filePath),
      mtime: Value(mtime),
      sizeBytes: Value(sizeBytes),
      cacheFileNormal: cacheFileNormal == null && nullToAbsent
          ? const Value.absent()
          : Value(cacheFileNormal),
      cacheFileLarge: cacheFileLarge == null && nullToAbsent
          ? const Value.absent()
          : Value(cacheFileLarge),
      kind: Value(kind),
      status: Value(status),
      generatedAt: Value(generatedAt),
    );
  }

  factory ThumbnailCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ThumbnailCacheEntry(
      fileHash: serializer.fromJson<String>(json['fileHash']),
      filePath: serializer.fromJson<String>(json['filePath']),
      mtime: serializer.fromJson<int>(json['mtime']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      cacheFileNormal: serializer.fromJson<String?>(json['cacheFileNormal']),
      cacheFileLarge: serializer.fromJson<String?>(json['cacheFileLarge']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      generatedAt: serializer.fromJson<int>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileHash': serializer.toJson<String>(fileHash),
      'filePath': serializer.toJson<String>(filePath),
      'mtime': serializer.toJson<int>(mtime),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'cacheFileNormal': serializer.toJson<String?>(cacheFileNormal),
      'cacheFileLarge': serializer.toJson<String?>(cacheFileLarge),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'generatedAt': serializer.toJson<int>(generatedAt),
    };
  }

  ThumbnailCacheEntry copyWith({
    String? fileHash,
    String? filePath,
    int? mtime,
    int? sizeBytes,
    Value<String?> cacheFileNormal = const Value.absent(),
    Value<String?> cacheFileLarge = const Value.absent(),
    String? kind,
    String? status,
    int? generatedAt,
  }) => ThumbnailCacheEntry(
    fileHash: fileHash ?? this.fileHash,
    filePath: filePath ?? this.filePath,
    mtime: mtime ?? this.mtime,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    cacheFileNormal: cacheFileNormal.present
        ? cacheFileNormal.value
        : this.cacheFileNormal,
    cacheFileLarge: cacheFileLarge.present
        ? cacheFileLarge.value
        : this.cacheFileLarge,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    generatedAt: generatedAt ?? this.generatedAt,
  );
  ThumbnailCacheEntry copyWithCompanion(ThumbnailCacheEntriesCompanion data) {
    return ThumbnailCacheEntry(
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      cacheFileNormal: data.cacheFileNormal.present
          ? data.cacheFileNormal.value
          : this.cacheFileNormal,
      cacheFileLarge: data.cacheFileLarge.present
          ? data.cacheFileLarge.value
          : this.cacheFileLarge,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ThumbnailCacheEntry(')
          ..write('fileHash: $fileHash, ')
          ..write('filePath: $filePath, ')
          ..write('mtime: $mtime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('cacheFileNormal: $cacheFileNormal, ')
          ..write('cacheFileLarge: $cacheFileLarge, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileHash,
    filePath,
    mtime,
    sizeBytes,
    cacheFileNormal,
    cacheFileLarge,
    kind,
    status,
    generatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThumbnailCacheEntry &&
          other.fileHash == this.fileHash &&
          other.filePath == this.filePath &&
          other.mtime == this.mtime &&
          other.sizeBytes == this.sizeBytes &&
          other.cacheFileNormal == this.cacheFileNormal &&
          other.cacheFileLarge == this.cacheFileLarge &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.generatedAt == this.generatedAt);
}

class ThumbnailCacheEntriesCompanion
    extends UpdateCompanion<ThumbnailCacheEntry> {
  final Value<String> fileHash;
  final Value<String> filePath;
  final Value<int> mtime;
  final Value<int> sizeBytes;
  final Value<String?> cacheFileNormal;
  final Value<String?> cacheFileLarge;
  final Value<String> kind;
  final Value<String> status;
  final Value<int> generatedAt;
  final Value<int> rowid;
  const ThumbnailCacheEntriesCompanion({
    this.fileHash = const Value.absent(),
    this.filePath = const Value.absent(),
    this.mtime = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.cacheFileNormal = const Value.absent(),
    this.cacheFileLarge = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThumbnailCacheEntriesCompanion.insert({
    required String fileHash,
    required String filePath,
    required int mtime,
    required int sizeBytes,
    this.cacheFileNormal = const Value.absent(),
    this.cacheFileLarge = const Value.absent(),
    required String kind,
    required String status,
    required int generatedAt,
    this.rowid = const Value.absent(),
  }) : fileHash = Value(fileHash),
       filePath = Value(filePath),
       mtime = Value(mtime),
       sizeBytes = Value(sizeBytes),
       kind = Value(kind),
       status = Value(status),
       generatedAt = Value(generatedAt);
  static Insertable<ThumbnailCacheEntry> custom({
    Expression<String>? fileHash,
    Expression<String>? filePath,
    Expression<int>? mtime,
    Expression<int>? sizeBytes,
    Expression<String>? cacheFileNormal,
    Expression<String>? cacheFileLarge,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<int>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileHash != null) 'file_hash': fileHash,
      if (filePath != null) 'file_path': filePath,
      if (mtime != null) 'mtime': mtime,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (cacheFileNormal != null) 'cache_file_normal': cacheFileNormal,
      if (cacheFileLarge != null) 'cache_file_large': cacheFileLarge,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThumbnailCacheEntriesCompanion copyWith({
    Value<String>? fileHash,
    Value<String>? filePath,
    Value<int>? mtime,
    Value<int>? sizeBytes,
    Value<String?>? cacheFileNormal,
    Value<String?>? cacheFileLarge,
    Value<String>? kind,
    Value<String>? status,
    Value<int>? generatedAt,
    Value<int>? rowid,
  }) {
    return ThumbnailCacheEntriesCompanion(
      fileHash: fileHash ?? this.fileHash,
      filePath: filePath ?? this.filePath,
      mtime: mtime ?? this.mtime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      cacheFileNormal: cacheFileNormal ?? this.cacheFileNormal,
      cacheFileLarge: cacheFileLarge ?? this.cacheFileLarge,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (cacheFileNormal.present) {
      map['cache_file_normal'] = Variable<String>(cacheFileNormal.value);
    }
    if (cacheFileLarge.present) {
      map['cache_file_large'] = Variable<String>(cacheFileLarge.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<int>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThumbnailCacheEntriesCompanion(')
          ..write('fileHash: $fileHash, ')
          ..write('filePath: $filePath, ')
          ..write('mtime: $mtime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('cacheFileNormal: $cacheFileNormal, ')
          ..write('cacheFileLarge: $cacheFileLarge, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $FolderSortPreferencesTable folderSortPreferences =
      $FolderSortPreferencesTable(this);
  late final $PinnedFoldersTable pinnedFolders = $PinnedFoldersTable(this);
  late final $PinnedItemsTable pinnedItems = $PinnedItemsTable(this);
  late final $MetadataCacheEntriesTable metadataCacheEntries =
      $MetadataCacheEntriesTable(this);
  late final $PlaybackMemoryEntriesTable playbackMemoryEntries =
      $PlaybackMemoryEntriesTable(this);
  late final $AudioFavoriteEntriesTable audioFavoriteEntries =
      $AudioFavoriteEntriesTable(this);
  late final $VideoFavoriteEntriesTable videoFavoriteEntries =
      $VideoFavoriteEntriesTable(this);
  late final $ImageFavoriteEntriesTable imageFavoriteEntries =
      $ImageFavoriteEntriesTable(this);
  late final $CustomEmojiSetEntriesTable customEmojiSetEntries =
      $CustomEmojiSetEntriesTable(this);
  late final $CustomIconSetEntriesTable customIconSetEntries =
      $CustomIconSetEntriesTable(this);
  late final $MarkerRecentEntriesTable markerRecentEntries =
      $MarkerRecentEntriesTable(this);
  late final $DownloadHistoryEntriesTable downloadHistoryEntries =
      $DownloadHistoryEntriesTable(this);
  late final $ThumbnailCacheEntriesTable thumbnailCacheEntries =
      $ThumbnailCacheEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    folderSortPreferences,
    pinnedFolders,
    pinnedItems,
    metadataCacheEntries,
    playbackMemoryEntries,
    audioFavoriteEntries,
    videoFavoriteEntries,
    imageFavoriteEntries,
    customEmojiSetEntries,
    customIconSetEntries,
    markerRecentEntries,
    downloadHistoryEntries,
    thumbnailCacheEntries,
  ];
}

typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$FolderSortPreferencesTableCreateCompanionBuilder =
    FolderSortPreferencesCompanion Function({
      required String folderPath,
      required String sortKey,
      Value<int> rowid,
    });
typedef $$FolderSortPreferencesTableUpdateCompanionBuilder =
    FolderSortPreferencesCompanion Function({
      Value<String> folderPath,
      Value<String> sortKey,
      Value<int> rowid,
    });

class $$FolderSortPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $FolderSortPreferencesTable> {
  $$FolderSortPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FolderSortPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderSortPreferencesTable> {
  $$FolderSortPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FolderSortPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderSortPreferencesTable> {
  $$FolderSortPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);
}

class $$FolderSortPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FolderSortPreferencesTable,
          FolderSortPreference,
          $$FolderSortPreferencesTableFilterComposer,
          $$FolderSortPreferencesTableOrderingComposer,
          $$FolderSortPreferencesTableAnnotationComposer,
          $$FolderSortPreferencesTableCreateCompanionBuilder,
          $$FolderSortPreferencesTableUpdateCompanionBuilder,
          (
            FolderSortPreference,
            BaseReferences<
              _$AppDatabase,
              $FolderSortPreferencesTable,
              FolderSortPreference
            >,
          ),
          FolderSortPreference,
          PrefetchHooks Function()
        > {
  $$FolderSortPreferencesTableTableManager(
    _$AppDatabase db,
    $FolderSortPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderSortPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FolderSortPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FolderSortPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> folderPath = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FolderSortPreferencesCompanion(
                folderPath: folderPath,
                sortKey: sortKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderPath,
                required String sortKey,
                Value<int> rowid = const Value.absent(),
              }) => FolderSortPreferencesCompanion.insert(
                folderPath: folderPath,
                sortKey: sortKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FolderSortPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FolderSortPreferencesTable,
      FolderSortPreference,
      $$FolderSortPreferencesTableFilterComposer,
      $$FolderSortPreferencesTableOrderingComposer,
      $$FolderSortPreferencesTableAnnotationComposer,
      $$FolderSortPreferencesTableCreateCompanionBuilder,
      $$FolderSortPreferencesTableUpdateCompanionBuilder,
      (
        FolderSortPreference,
        BaseReferences<
          _$AppDatabase,
          $FolderSortPreferencesTable,
          FolderSortPreference
        >,
      ),
      FolderSortPreference,
      PrefetchHooks Function()
    >;
typedef $$PinnedFoldersTableCreateCompanionBuilder =
    PinnedFoldersCompanion Function({
      required String folderPath,
      required int position,
      Value<int> rowid,
    });
typedef $$PinnedFoldersTableUpdateCompanionBuilder =
    PinnedFoldersCompanion Function({
      Value<String> folderPath,
      Value<int> position,
      Value<int> rowid,
    });

class $$PinnedFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $PinnedFoldersTable> {
  $$PinnedFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PinnedFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $PinnedFoldersTable> {
  $$PinnedFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PinnedFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinnedFoldersTable> {
  $$PinnedFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$PinnedFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PinnedFoldersTable,
          PinnedFolder,
          $$PinnedFoldersTableFilterComposer,
          $$PinnedFoldersTableOrderingComposer,
          $$PinnedFoldersTableAnnotationComposer,
          $$PinnedFoldersTableCreateCompanionBuilder,
          $$PinnedFoldersTableUpdateCompanionBuilder,
          (
            PinnedFolder,
            BaseReferences<_$AppDatabase, $PinnedFoldersTable, PinnedFolder>,
          ),
          PinnedFolder,
          PrefetchHooks Function()
        > {
  $$PinnedFoldersTableTableManager(_$AppDatabase db, $PinnedFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinnedFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinnedFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinnedFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> folderPath = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PinnedFoldersCompanion(
                folderPath: folderPath,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderPath,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PinnedFoldersCompanion.insert(
                folderPath: folderPath,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PinnedFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PinnedFoldersTable,
      PinnedFolder,
      $$PinnedFoldersTableFilterComposer,
      $$PinnedFoldersTableOrderingComposer,
      $$PinnedFoldersTableAnnotationComposer,
      $$PinnedFoldersTableCreateCompanionBuilder,
      $$PinnedFoldersTableUpdateCompanionBuilder,
      (
        PinnedFolder,
        BaseReferences<_$AppDatabase, $PinnedFoldersTable, PinnedFolder>,
      ),
      PinnedFolder,
      PrefetchHooks Function()
    >;
typedef $$PinnedItemsTableCreateCompanionBuilder =
    PinnedItemsCompanion Function({
      required String itemPath,
      required int pinnedAt,
      Value<int> rowid,
    });
typedef $$PinnedItemsTableUpdateCompanionBuilder =
    PinnedItemsCompanion Function({
      Value<String> itemPath,
      Value<int> pinnedAt,
      Value<int> rowid,
    });

class $$PinnedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PinnedItemsTable> {
  $$PinnedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemPath => $composableBuilder(
    column: $table.itemPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PinnedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PinnedItemsTable> {
  $$PinnedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemPath => $composableBuilder(
    column: $table.itemPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PinnedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PinnedItemsTable> {
  $$PinnedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemPath =>
      $composableBuilder(column: $table.itemPath, builder: (column) => column);

  GeneratedColumn<int> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$PinnedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PinnedItemsTable,
          PinnedItem,
          $$PinnedItemsTableFilterComposer,
          $$PinnedItemsTableOrderingComposer,
          $$PinnedItemsTableAnnotationComposer,
          $$PinnedItemsTableCreateCompanionBuilder,
          $$PinnedItemsTableUpdateCompanionBuilder,
          (
            PinnedItem,
            BaseReferences<_$AppDatabase, $PinnedItemsTable, PinnedItem>,
          ),
          PinnedItem,
          PrefetchHooks Function()
        > {
  $$PinnedItemsTableTableManager(_$AppDatabase db, $PinnedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PinnedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PinnedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PinnedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemPath = const Value.absent(),
                Value<int> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PinnedItemsCompanion(
                itemPath: itemPath,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemPath,
                required int pinnedAt,
                Value<int> rowid = const Value.absent(),
              }) => PinnedItemsCompanion.insert(
                itemPath: itemPath,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PinnedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PinnedItemsTable,
      PinnedItem,
      $$PinnedItemsTableFilterComposer,
      $$PinnedItemsTableOrderingComposer,
      $$PinnedItemsTableAnnotationComposer,
      $$PinnedItemsTableCreateCompanionBuilder,
      $$PinnedItemsTableUpdateCompanionBuilder,
      (
        PinnedItem,
        BaseReferences<_$AppDatabase, $PinnedItemsTable, PinnedItem>,
      ),
      PinnedItem,
      PrefetchHooks Function()
    >;
typedef $$MetadataCacheEntriesTableCreateCompanionBuilder =
    MetadataCacheEntriesCompanion Function({
      required String filePath,
      required double aspectRatio,
      required int cachedAt,
      Value<int> rowid,
    });
typedef $$MetadataCacheEntriesTableUpdateCompanionBuilder =
    MetadataCacheEntriesCompanion Function({
      Value<String> filePath,
      Value<double> aspectRatio,
      Value<int> cachedAt,
      Value<int> rowid,
    });

class $$MetadataCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MetadataCacheEntriesTable> {
  $$MetadataCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetadataCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MetadataCacheEntriesTable> {
  $$MetadataCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetadataCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetadataCacheEntriesTable> {
  $$MetadataCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<double> get aspectRatio => $composableBuilder(
    column: $table.aspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$MetadataCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetadataCacheEntriesTable,
          MetadataCacheEntry,
          $$MetadataCacheEntriesTableFilterComposer,
          $$MetadataCacheEntriesTableOrderingComposer,
          $$MetadataCacheEntriesTableAnnotationComposer,
          $$MetadataCacheEntriesTableCreateCompanionBuilder,
          $$MetadataCacheEntriesTableUpdateCompanionBuilder,
          (
            MetadataCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $MetadataCacheEntriesTable,
              MetadataCacheEntry
            >,
          ),
          MetadataCacheEntry,
          PrefetchHooks Function()
        > {
  $$MetadataCacheEntriesTableTableManager(
    _$AppDatabase db,
    $MetadataCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetadataCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetadataCacheEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MetadataCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<double> aspectRatio = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetadataCacheEntriesCompanion(
                filePath: filePath,
                aspectRatio: aspectRatio,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                required double aspectRatio,
                required int cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => MetadataCacheEntriesCompanion.insert(
                filePath: filePath,
                aspectRatio: aspectRatio,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetadataCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetadataCacheEntriesTable,
      MetadataCacheEntry,
      $$MetadataCacheEntriesTableFilterComposer,
      $$MetadataCacheEntriesTableOrderingComposer,
      $$MetadataCacheEntriesTableAnnotationComposer,
      $$MetadataCacheEntriesTableCreateCompanionBuilder,
      $$MetadataCacheEntriesTableUpdateCompanionBuilder,
      (
        MetadataCacheEntry,
        BaseReferences<
          _$AppDatabase,
          $MetadataCacheEntriesTable,
          MetadataCacheEntry
        >,
      ),
      MetadataCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$PlaybackMemoryEntriesTableCreateCompanionBuilder =
    PlaybackMemoryEntriesCompanion Function({
      required String filePath,
      required int positionMs,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackMemoryEntriesTableUpdateCompanionBuilder =
    PlaybackMemoryEntriesCompanion Function({
      Value<String> filePath,
      Value<int> positionMs,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PlaybackMemoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackMemoryEntriesTable> {
  $$PlaybackMemoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackMemoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackMemoryEntriesTable> {
  $$PlaybackMemoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackMemoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackMemoryEntriesTable> {
  $$PlaybackMemoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackMemoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackMemoryEntriesTable,
          PlaybackMemoryEntry,
          $$PlaybackMemoryEntriesTableFilterComposer,
          $$PlaybackMemoryEntriesTableOrderingComposer,
          $$PlaybackMemoryEntriesTableAnnotationComposer,
          $$PlaybackMemoryEntriesTableCreateCompanionBuilder,
          $$PlaybackMemoryEntriesTableUpdateCompanionBuilder,
          (
            PlaybackMemoryEntry,
            BaseReferences<
              _$AppDatabase,
              $PlaybackMemoryEntriesTable,
              PlaybackMemoryEntry
            >,
          ),
          PlaybackMemoryEntry,
          PrefetchHooks Function()
        > {
  $$PlaybackMemoryEntriesTableTableManager(
    _$AppDatabase db,
    $PlaybackMemoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackMemoryEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlaybackMemoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackMemoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackMemoryEntriesCompanion(
                filePath: filePath,
                positionMs: positionMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                required int positionMs,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaybackMemoryEntriesCompanion.insert(
                filePath: filePath,
                positionMs: positionMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackMemoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackMemoryEntriesTable,
      PlaybackMemoryEntry,
      $$PlaybackMemoryEntriesTableFilterComposer,
      $$PlaybackMemoryEntriesTableOrderingComposer,
      $$PlaybackMemoryEntriesTableAnnotationComposer,
      $$PlaybackMemoryEntriesTableCreateCompanionBuilder,
      $$PlaybackMemoryEntriesTableUpdateCompanionBuilder,
      (
        PlaybackMemoryEntry,
        BaseReferences<
          _$AppDatabase,
          $PlaybackMemoryEntriesTable,
          PlaybackMemoryEntry
        >,
      ),
      PlaybackMemoryEntry,
      PrefetchHooks Function()
    >;
typedef $$AudioFavoriteEntriesTableCreateCompanionBuilder =
    AudioFavoriteEntriesCompanion Function({
      required String filePath,
      required int favoritedAt,
      Value<int> rowid,
    });
typedef $$AudioFavoriteEntriesTableUpdateCompanionBuilder =
    AudioFavoriteEntriesCompanion Function({
      Value<String> filePath,
      Value<int> favoritedAt,
      Value<int> rowid,
    });

class $$AudioFavoriteEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AudioFavoriteEntriesTable> {
  $$AudioFavoriteEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioFavoriteEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioFavoriteEntriesTable> {
  $$AudioFavoriteEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioFavoriteEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioFavoriteEntriesTable> {
  $$AudioFavoriteEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$AudioFavoriteEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioFavoriteEntriesTable,
          AudioFavoriteEntry,
          $$AudioFavoriteEntriesTableFilterComposer,
          $$AudioFavoriteEntriesTableOrderingComposer,
          $$AudioFavoriteEntriesTableAnnotationComposer,
          $$AudioFavoriteEntriesTableCreateCompanionBuilder,
          $$AudioFavoriteEntriesTableUpdateCompanionBuilder,
          (
            AudioFavoriteEntry,
            BaseReferences<
              _$AppDatabase,
              $AudioFavoriteEntriesTable,
              AudioFavoriteEntry
            >,
          ),
          AudioFavoriteEntry,
          PrefetchHooks Function()
        > {
  $$AudioFavoriteEntriesTableTableManager(
    _$AppDatabase db,
    $AudioFavoriteEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioFavoriteEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioFavoriteEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AudioFavoriteEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<int> favoritedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioFavoriteEntriesCompanion(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                required int favoritedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioFavoriteEntriesCompanion.insert(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioFavoriteEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioFavoriteEntriesTable,
      AudioFavoriteEntry,
      $$AudioFavoriteEntriesTableFilterComposer,
      $$AudioFavoriteEntriesTableOrderingComposer,
      $$AudioFavoriteEntriesTableAnnotationComposer,
      $$AudioFavoriteEntriesTableCreateCompanionBuilder,
      $$AudioFavoriteEntriesTableUpdateCompanionBuilder,
      (
        AudioFavoriteEntry,
        BaseReferences<
          _$AppDatabase,
          $AudioFavoriteEntriesTable,
          AudioFavoriteEntry
        >,
      ),
      AudioFavoriteEntry,
      PrefetchHooks Function()
    >;
typedef $$VideoFavoriteEntriesTableCreateCompanionBuilder =
    VideoFavoriteEntriesCompanion Function({
      required String filePath,
      required int favoritedAt,
      Value<int> rowid,
    });
typedef $$VideoFavoriteEntriesTableUpdateCompanionBuilder =
    VideoFavoriteEntriesCompanion Function({
      Value<String> filePath,
      Value<int> favoritedAt,
      Value<int> rowid,
    });

class $$VideoFavoriteEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VideoFavoriteEntriesTable> {
  $$VideoFavoriteEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VideoFavoriteEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VideoFavoriteEntriesTable> {
  $$VideoFavoriteEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VideoFavoriteEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VideoFavoriteEntriesTable> {
  $$VideoFavoriteEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$VideoFavoriteEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VideoFavoriteEntriesTable,
          VideoFavoriteEntry,
          $$VideoFavoriteEntriesTableFilterComposer,
          $$VideoFavoriteEntriesTableOrderingComposer,
          $$VideoFavoriteEntriesTableAnnotationComposer,
          $$VideoFavoriteEntriesTableCreateCompanionBuilder,
          $$VideoFavoriteEntriesTableUpdateCompanionBuilder,
          (
            VideoFavoriteEntry,
            BaseReferences<
              _$AppDatabase,
              $VideoFavoriteEntriesTable,
              VideoFavoriteEntry
            >,
          ),
          VideoFavoriteEntry,
          PrefetchHooks Function()
        > {
  $$VideoFavoriteEntriesTableTableManager(
    _$AppDatabase db,
    $VideoFavoriteEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VideoFavoriteEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VideoFavoriteEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$VideoFavoriteEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<int> favoritedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VideoFavoriteEntriesCompanion(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                required int favoritedAt,
                Value<int> rowid = const Value.absent(),
              }) => VideoFavoriteEntriesCompanion.insert(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VideoFavoriteEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VideoFavoriteEntriesTable,
      VideoFavoriteEntry,
      $$VideoFavoriteEntriesTableFilterComposer,
      $$VideoFavoriteEntriesTableOrderingComposer,
      $$VideoFavoriteEntriesTableAnnotationComposer,
      $$VideoFavoriteEntriesTableCreateCompanionBuilder,
      $$VideoFavoriteEntriesTableUpdateCompanionBuilder,
      (
        VideoFavoriteEntry,
        BaseReferences<
          _$AppDatabase,
          $VideoFavoriteEntriesTable,
          VideoFavoriteEntry
        >,
      ),
      VideoFavoriteEntry,
      PrefetchHooks Function()
    >;
typedef $$ImageFavoriteEntriesTableCreateCompanionBuilder =
    ImageFavoriteEntriesCompanion Function({
      required String filePath,
      required int favoritedAt,
      Value<int> rowid,
    });
typedef $$ImageFavoriteEntriesTableUpdateCompanionBuilder =
    ImageFavoriteEntriesCompanion Function({
      Value<String> filePath,
      Value<int> favoritedAt,
      Value<int> rowid,
    });

class $$ImageFavoriteEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ImageFavoriteEntriesTable> {
  $$ImageFavoriteEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImageFavoriteEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageFavoriteEntriesTable> {
  $$ImageFavoriteEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageFavoriteEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageFavoriteEntriesTable> {
  $$ImageFavoriteEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get favoritedAt => $composableBuilder(
    column: $table.favoritedAt,
    builder: (column) => column,
  );
}

class $$ImageFavoriteEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageFavoriteEntriesTable,
          ImageFavoriteEntry,
          $$ImageFavoriteEntriesTableFilterComposer,
          $$ImageFavoriteEntriesTableOrderingComposer,
          $$ImageFavoriteEntriesTableAnnotationComposer,
          $$ImageFavoriteEntriesTableCreateCompanionBuilder,
          $$ImageFavoriteEntriesTableUpdateCompanionBuilder,
          (
            ImageFavoriteEntry,
            BaseReferences<
              _$AppDatabase,
              $ImageFavoriteEntriesTable,
              ImageFavoriteEntry
            >,
          ),
          ImageFavoriteEntry,
          PrefetchHooks Function()
        > {
  $$ImageFavoriteEntriesTableTableManager(
    _$AppDatabase db,
    $ImageFavoriteEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageFavoriteEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageFavoriteEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ImageFavoriteEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filePath = const Value.absent(),
                Value<int> favoritedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageFavoriteEntriesCompanion(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filePath,
                required int favoritedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImageFavoriteEntriesCompanion.insert(
                filePath: filePath,
                favoritedAt: favoritedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImageFavoriteEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageFavoriteEntriesTable,
      ImageFavoriteEntry,
      $$ImageFavoriteEntriesTableFilterComposer,
      $$ImageFavoriteEntriesTableOrderingComposer,
      $$ImageFavoriteEntriesTableAnnotationComposer,
      $$ImageFavoriteEntriesTableCreateCompanionBuilder,
      $$ImageFavoriteEntriesTableUpdateCompanionBuilder,
      (
        ImageFavoriteEntry,
        BaseReferences<
          _$AppDatabase,
          $ImageFavoriteEntriesTable,
          ImageFavoriteEntry
        >,
      ),
      ImageFavoriteEntry,
      PrefetchHooks Function()
    >;
typedef $$CustomEmojiSetEntriesTableCreateCompanionBuilder =
    CustomEmojiSetEntriesCompanion Function({
      required String id,
      required String rawData,
      required String definitions,
      Value<int> rowid,
    });
typedef $$CustomEmojiSetEntriesTableUpdateCompanionBuilder =
    CustomEmojiSetEntriesCompanion Function({
      Value<String> id,
      Value<String> rawData,
      Value<String> definitions,
      Value<int> rowid,
    });

class $$CustomEmojiSetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomEmojiSetEntriesTable> {
  $$CustomEmojiSetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawData => $composableBuilder(
    column: $table.rawData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomEmojiSetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomEmojiSetEntriesTable> {
  $$CustomEmojiSetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawData => $composableBuilder(
    column: $table.rawData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomEmojiSetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomEmojiSetEntriesTable> {
  $$CustomEmojiSetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawData =>
      $composableBuilder(column: $table.rawData, builder: (column) => column);

  GeneratedColumn<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => column,
  );
}

class $$CustomEmojiSetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomEmojiSetEntriesTable,
          CustomEmojiSetEntry,
          $$CustomEmojiSetEntriesTableFilterComposer,
          $$CustomEmojiSetEntriesTableOrderingComposer,
          $$CustomEmojiSetEntriesTableAnnotationComposer,
          $$CustomEmojiSetEntriesTableCreateCompanionBuilder,
          $$CustomEmojiSetEntriesTableUpdateCompanionBuilder,
          (
            CustomEmojiSetEntry,
            BaseReferences<
              _$AppDatabase,
              $CustomEmojiSetEntriesTable,
              CustomEmojiSetEntry
            >,
          ),
          CustomEmojiSetEntry,
          PrefetchHooks Function()
        > {
  $$CustomEmojiSetEntriesTableTableManager(
    _$AppDatabase db,
    $CustomEmojiSetEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomEmojiSetEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CustomEmojiSetEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CustomEmojiSetEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> rawData = const Value.absent(),
                Value<String> definitions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomEmojiSetEntriesCompanion(
                id: id,
                rawData: rawData,
                definitions: definitions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String rawData,
                required String definitions,
                Value<int> rowid = const Value.absent(),
              }) => CustomEmojiSetEntriesCompanion.insert(
                id: id,
                rawData: rawData,
                definitions: definitions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomEmojiSetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomEmojiSetEntriesTable,
      CustomEmojiSetEntry,
      $$CustomEmojiSetEntriesTableFilterComposer,
      $$CustomEmojiSetEntriesTableOrderingComposer,
      $$CustomEmojiSetEntriesTableAnnotationComposer,
      $$CustomEmojiSetEntriesTableCreateCompanionBuilder,
      $$CustomEmojiSetEntriesTableUpdateCompanionBuilder,
      (
        CustomEmojiSetEntry,
        BaseReferences<
          _$AppDatabase,
          $CustomEmojiSetEntriesTable,
          CustomEmojiSetEntry
        >,
      ),
      CustomEmojiSetEntry,
      PrefetchHooks Function()
    >;
typedef $$CustomIconSetEntriesTableCreateCompanionBuilder =
    CustomIconSetEntriesCompanion Function({
      required String id,
      required String imageBytes,
      required String tags,
      Value<int> rowid,
    });
typedef $$CustomIconSetEntriesTableUpdateCompanionBuilder =
    CustomIconSetEntriesCompanion Function({
      Value<String> id,
      Value<String> imageBytes,
      Value<String> tags,
      Value<int> rowid,
    });

class $$CustomIconSetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomIconSetEntriesTable> {
  $$CustomIconSetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomIconSetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomIconSetEntriesTable> {
  $$CustomIconSetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomIconSetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomIconSetEntriesTable> {
  $$CustomIconSetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imageBytes => $composableBuilder(
    column: $table.imageBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);
}

class $$CustomIconSetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomIconSetEntriesTable,
          CustomIconSetEntry,
          $$CustomIconSetEntriesTableFilterComposer,
          $$CustomIconSetEntriesTableOrderingComposer,
          $$CustomIconSetEntriesTableAnnotationComposer,
          $$CustomIconSetEntriesTableCreateCompanionBuilder,
          $$CustomIconSetEntriesTableUpdateCompanionBuilder,
          (
            CustomIconSetEntry,
            BaseReferences<
              _$AppDatabase,
              $CustomIconSetEntriesTable,
              CustomIconSetEntry
            >,
          ),
          CustomIconSetEntry,
          PrefetchHooks Function()
        > {
  $$CustomIconSetEntriesTableTableManager(
    _$AppDatabase db,
    $CustomIconSetEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomIconSetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomIconSetEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CustomIconSetEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> imageBytes = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomIconSetEntriesCompanion(
                id: id,
                imageBytes: imageBytes,
                tags: tags,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String imageBytes,
                required String tags,
                Value<int> rowid = const Value.absent(),
              }) => CustomIconSetEntriesCompanion.insert(
                id: id,
                imageBytes: imageBytes,
                tags: tags,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomIconSetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomIconSetEntriesTable,
      CustomIconSetEntry,
      $$CustomIconSetEntriesTableFilterComposer,
      $$CustomIconSetEntriesTableOrderingComposer,
      $$CustomIconSetEntriesTableAnnotationComposer,
      $$CustomIconSetEntriesTableCreateCompanionBuilder,
      $$CustomIconSetEntriesTableUpdateCompanionBuilder,
      (
        CustomIconSetEntry,
        BaseReferences<
          _$AppDatabase,
          $CustomIconSetEntriesTable,
          CustomIconSetEntry
        >,
      ),
      CustomIconSetEntry,
      PrefetchHooks Function()
    >;
typedef $$MarkerRecentEntriesTableCreateCompanionBuilder =
    MarkerRecentEntriesCompanion Function({
      required String value,
      required int usedAt,
      Value<int> rowid,
    });
typedef $$MarkerRecentEntriesTableUpdateCompanionBuilder =
    MarkerRecentEntriesCompanion Function({
      Value<String> value,
      Value<int> usedAt,
      Value<int> rowid,
    });

class $$MarkerRecentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MarkerRecentEntriesTable> {
  $$MarkerRecentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MarkerRecentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MarkerRecentEntriesTable> {
  $$MarkerRecentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedAt => $composableBuilder(
    column: $table.usedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MarkerRecentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarkerRecentEntriesTable> {
  $$MarkerRecentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get usedAt =>
      $composableBuilder(column: $table.usedAt, builder: (column) => column);
}

class $$MarkerRecentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MarkerRecentEntriesTable,
          MarkerRecentEntry,
          $$MarkerRecentEntriesTableFilterComposer,
          $$MarkerRecentEntriesTableOrderingComposer,
          $$MarkerRecentEntriesTableAnnotationComposer,
          $$MarkerRecentEntriesTableCreateCompanionBuilder,
          $$MarkerRecentEntriesTableUpdateCompanionBuilder,
          (
            MarkerRecentEntry,
            BaseReferences<
              _$AppDatabase,
              $MarkerRecentEntriesTable,
              MarkerRecentEntry
            >,
          ),
          MarkerRecentEntry,
          PrefetchHooks Function()
        > {
  $$MarkerRecentEntriesTableTableManager(
    _$AppDatabase db,
    $MarkerRecentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarkerRecentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarkerRecentEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MarkerRecentEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> value = const Value.absent(),
                Value<int> usedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarkerRecentEntriesCompanion(
                value: value,
                usedAt: usedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String value,
                required int usedAt,
                Value<int> rowid = const Value.absent(),
              }) => MarkerRecentEntriesCompanion.insert(
                value: value,
                usedAt: usedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MarkerRecentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MarkerRecentEntriesTable,
      MarkerRecentEntry,
      $$MarkerRecentEntriesTableFilterComposer,
      $$MarkerRecentEntriesTableOrderingComposer,
      $$MarkerRecentEntriesTableAnnotationComposer,
      $$MarkerRecentEntriesTableCreateCompanionBuilder,
      $$MarkerRecentEntriesTableUpdateCompanionBuilder,
      (
        MarkerRecentEntry,
        BaseReferences<
          _$AppDatabase,
          $MarkerRecentEntriesTable,
          MarkerRecentEntry
        >,
      ),
      MarkerRecentEntry,
      PrefetchHooks Function()
    >;
typedef $$DownloadHistoryEntriesTableCreateCompanionBuilder =
    DownloadHistoryEntriesCompanion Function({
      required String id,
      required String title,
      required String url,
      required String destination,
      required String downloadType,
      required String statusName,
      Value<String?> errorMessage,
      required int createdAt,
      Value<int?> completedAt,
      Value<String?> logs,
      Value<int> rowid,
    });
typedef $$DownloadHistoryEntriesTableUpdateCompanionBuilder =
    DownloadHistoryEntriesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> url,
      Value<String> destination,
      Value<String> downloadType,
      Value<String> statusName,
      Value<String?> errorMessage,
      Value<int> createdAt,
      Value<int?> completedAt,
      Value<String?> logs,
      Value<int> rowid,
    });

class $$DownloadHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadType => $composableBuilder(
    column: $table.downloadType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusName => $composableBuilder(
    column: $table.statusName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logs => $composableBuilder(
    column: $table.logs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadType => $composableBuilder(
    column: $table.downloadType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusName => $composableBuilder(
    column: $table.statusName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logs => $composableBuilder(
    column: $table.logs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadHistoryEntriesTable> {
  $$DownloadHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadType => $composableBuilder(
    column: $table.downloadType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statusName => $composableBuilder(
    column: $table.statusName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logs =>
      $composableBuilder(column: $table.logs, builder: (column) => column);
}

class $$DownloadHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadHistoryEntriesTable,
          DownloadHistoryEntry,
          $$DownloadHistoryEntriesTableFilterComposer,
          $$DownloadHistoryEntriesTableOrderingComposer,
          $$DownloadHistoryEntriesTableAnnotationComposer,
          $$DownloadHistoryEntriesTableCreateCompanionBuilder,
          $$DownloadHistoryEntriesTableUpdateCompanionBuilder,
          (
            DownloadHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $DownloadHistoryEntriesTable,
              DownloadHistoryEntry
            >,
          ),
          DownloadHistoryEntry,
          PrefetchHooks Function()
        > {
  $$DownloadHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $DownloadHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadHistoryEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<String> downloadType = const Value.absent(),
                Value<String> statusName = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> logs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadHistoryEntriesCompanion(
                id: id,
                title: title,
                url: url,
                destination: destination,
                downloadType: downloadType,
                statusName: statusName,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                logs: logs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String url,
                required String destination,
                required String downloadType,
                required String statusName,
                Value<String?> errorMessage = const Value.absent(),
                required int createdAt,
                Value<int?> completedAt = const Value.absent(),
                Value<String?> logs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadHistoryEntriesCompanion.insert(
                id: id,
                title: title,
                url: url,
                destination: destination,
                downloadType: downloadType,
                statusName: statusName,
                errorMessage: errorMessage,
                createdAt: createdAt,
                completedAt: completedAt,
                logs: logs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadHistoryEntriesTable,
      DownloadHistoryEntry,
      $$DownloadHistoryEntriesTableFilterComposer,
      $$DownloadHistoryEntriesTableOrderingComposer,
      $$DownloadHistoryEntriesTableAnnotationComposer,
      $$DownloadHistoryEntriesTableCreateCompanionBuilder,
      $$DownloadHistoryEntriesTableUpdateCompanionBuilder,
      (
        DownloadHistoryEntry,
        BaseReferences<
          _$AppDatabase,
          $DownloadHistoryEntriesTable,
          DownloadHistoryEntry
        >,
      ),
      DownloadHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$ThumbnailCacheEntriesTableCreateCompanionBuilder =
    ThumbnailCacheEntriesCompanion Function({
      required String fileHash,
      required String filePath,
      required int mtime,
      required int sizeBytes,
      Value<String?> cacheFileNormal,
      Value<String?> cacheFileLarge,
      required String kind,
      required String status,
      required int generatedAt,
      Value<int> rowid,
    });
typedef $$ThumbnailCacheEntriesTableUpdateCompanionBuilder =
    ThumbnailCacheEntriesCompanion Function({
      Value<String> fileHash,
      Value<String> filePath,
      Value<int> mtime,
      Value<int> sizeBytes,
      Value<String?> cacheFileNormal,
      Value<String?> cacheFileLarge,
      Value<String> kind,
      Value<String> status,
      Value<int> generatedAt,
      Value<int> rowid,
    });

class $$ThumbnailCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ThumbnailCacheEntriesTable> {
  $$ThumbnailCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheFileNormal => $composableBuilder(
    column: $table.cacheFileNormal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheFileLarge => $composableBuilder(
    column: $table.cacheFileLarge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThumbnailCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ThumbnailCacheEntriesTable> {
  $$ThumbnailCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheFileNormal => $composableBuilder(
    column: $table.cacheFileNormal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheFileLarge => $composableBuilder(
    column: $table.cacheFileLarge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThumbnailCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThumbnailCacheEntriesTable> {
  $$ThumbnailCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get cacheFileNormal => $composableBuilder(
    column: $table.cacheFileNormal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cacheFileLarge => $composableBuilder(
    column: $table.cacheFileLarge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );
}

class $$ThumbnailCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThumbnailCacheEntriesTable,
          ThumbnailCacheEntry,
          $$ThumbnailCacheEntriesTableFilterComposer,
          $$ThumbnailCacheEntriesTableOrderingComposer,
          $$ThumbnailCacheEntriesTableAnnotationComposer,
          $$ThumbnailCacheEntriesTableCreateCompanionBuilder,
          $$ThumbnailCacheEntriesTableUpdateCompanionBuilder,
          (
            ThumbnailCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $ThumbnailCacheEntriesTable,
              ThumbnailCacheEntry
            >,
          ),
          ThumbnailCacheEntry,
          PrefetchHooks Function()
        > {
  $$ThumbnailCacheEntriesTableTableManager(
    _$AppDatabase db,
    $ThumbnailCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThumbnailCacheEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ThumbnailCacheEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ThumbnailCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> fileHash = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> cacheFileNormal = const Value.absent(),
                Value<String?> cacheFileLarge = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThumbnailCacheEntriesCompanion(
                fileHash: fileHash,
                filePath: filePath,
                mtime: mtime,
                sizeBytes: sizeBytes,
                cacheFileNormal: cacheFileNormal,
                cacheFileLarge: cacheFileLarge,
                kind: kind,
                status: status,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileHash,
                required String filePath,
                required int mtime,
                required int sizeBytes,
                Value<String?> cacheFileNormal = const Value.absent(),
                Value<String?> cacheFileLarge = const Value.absent(),
                required String kind,
                required String status,
                required int generatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ThumbnailCacheEntriesCompanion.insert(
                fileHash: fileHash,
                filePath: filePath,
                mtime: mtime,
                sizeBytes: sizeBytes,
                cacheFileNormal: cacheFileNormal,
                cacheFileLarge: cacheFileLarge,
                kind: kind,
                status: status,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThumbnailCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThumbnailCacheEntriesTable,
      ThumbnailCacheEntry,
      $$ThumbnailCacheEntriesTableFilterComposer,
      $$ThumbnailCacheEntriesTableOrderingComposer,
      $$ThumbnailCacheEntriesTableAnnotationComposer,
      $$ThumbnailCacheEntriesTableCreateCompanionBuilder,
      $$ThumbnailCacheEntriesTableUpdateCompanionBuilder,
      (
        ThumbnailCacheEntry,
        BaseReferences<
          _$AppDatabase,
          $ThumbnailCacheEntriesTable,
          ThumbnailCacheEntry
        >,
      ),
      ThumbnailCacheEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$FolderSortPreferencesTableTableManager get folderSortPreferences =>
      $$FolderSortPreferencesTableTableManager(_db, _db.folderSortPreferences);
  $$PinnedFoldersTableTableManager get pinnedFolders =>
      $$PinnedFoldersTableTableManager(_db, _db.pinnedFolders);
  $$PinnedItemsTableTableManager get pinnedItems =>
      $$PinnedItemsTableTableManager(_db, _db.pinnedItems);
  $$MetadataCacheEntriesTableTableManager get metadataCacheEntries =>
      $$MetadataCacheEntriesTableTableManager(_db, _db.metadataCacheEntries);
  $$PlaybackMemoryEntriesTableTableManager get playbackMemoryEntries =>
      $$PlaybackMemoryEntriesTableTableManager(_db, _db.playbackMemoryEntries);
  $$AudioFavoriteEntriesTableTableManager get audioFavoriteEntries =>
      $$AudioFavoriteEntriesTableTableManager(_db, _db.audioFavoriteEntries);
  $$VideoFavoriteEntriesTableTableManager get videoFavoriteEntries =>
      $$VideoFavoriteEntriesTableTableManager(_db, _db.videoFavoriteEntries);
  $$ImageFavoriteEntriesTableTableManager get imageFavoriteEntries =>
      $$ImageFavoriteEntriesTableTableManager(_db, _db.imageFavoriteEntries);
  $$CustomEmojiSetEntriesTableTableManager get customEmojiSetEntries =>
      $$CustomEmojiSetEntriesTableTableManager(_db, _db.customEmojiSetEntries);
  $$CustomIconSetEntriesTableTableManager get customIconSetEntries =>
      $$CustomIconSetEntriesTableTableManager(_db, _db.customIconSetEntries);
  $$MarkerRecentEntriesTableTableManager get markerRecentEntries =>
      $$MarkerRecentEntriesTableTableManager(_db, _db.markerRecentEntries);
  $$DownloadHistoryEntriesTableTableManager get downloadHistoryEntries =>
      $$DownloadHistoryEntriesTableTableManager(
        _db,
        _db.downloadHistoryEntries,
      );
  $$ThumbnailCacheEntriesTableTableManager get thumbnailCacheEntries =>
      $$ThumbnailCacheEntriesTableTableManager(_db, _db.thumbnailCacheEntries);
}
