// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';

import 'package:isar/isar.dart';
import 'writer/writer.dart';
import 'store/store.dart';
import 'store/store_handler.dart';

import 'writer/master/master.dart';
import 'models/operation_change.dart';
import 'utils/hlc.dart';

export 'models/models.dart';
export 'store/master.dart';
export 'isar_extensions.dart';

dynamic _encode(dynamic value) {
  if (value == null) return null;
  if (value is Map) return jsonEncode(value);

  switch (value.runtimeType) {
    case String:
    case int:
    case double:
      return value;
    case bool:
      return value ? 1 : 0;
    case DateTime:
      return value.toUtc().toIso8601String();
    case Hlc:
      return value.toString();
    default:
      throw 'Unsupported type: ${value.runtimeType}';
  }
}

class NoIsarConnected implements Exception {
  NoIsarConnected();
}

class IsarCrdt {
  final CrdtStore store;
  CrdtWriter? writer;
  IsarCrdt({
    required this.store,
    this.writer,
  });

  IsarCrdtStoreHandler _handler(Isar isar) {
    writer ??= IsarMasterCrdtWriter(isar);
    return IsarCrdtStoreHandler(store: store);
  }

  Future<Hlc> _canonicalTime() => store.canonicalTime();

  Future<List<OperationChange>> getChanges(
      {Hlc? modifiedSince, bool onlyModifiedHere = false}) async {
    String? hlcNode;
    if (onlyModifiedHere) {
      final time = await _canonicalTime();
      hlcNode = time.nodeId;
    }

    return store.queryChanges(hlcNode: hlcNode, hlcSince: modifiedSince);
  }

  Future<void> _updateTables({Hlc? since}) async {
    final changes = await getChanges(modifiedSince: since);
    if (changes.isEmpty) return;

    await writer?.upgradeChanges(changes);
  }

  Future<void> clearRebuild() async {
    if (writer == null) throw NoIsarConnected();
    final changes = await getChanges();
    if (changes.isEmpty) return;

    await writer!.writeTxn(() async {
      await writer!.clear();
      await store.storeChanges(changes);
    });

    await writer!.upgradeChanges(changes);
  }

  Future<Hlc> merge(List<Map<String, dynamic>> changeset) async {
    if (writer == null) throw NoIsarConnected();
    final Hlc canonicalTime = changeset.fold<Hlc>(await _canonicalTime(),
        (ct, map) => Hlc.recv(ct, Hlc.parse(map['hlc'])));

    final newChanges = changeset.map((map) {
      final collection = map['collection'] as String;
      final field = map['field'] as String;
      final id = map['id'];
      final value = _encode(map['value']);
      final hlc = map['hlc'];
      return OperationChange(
          collection: collection,
          operation: CrdtOperations.values.byName(map['operation']),
          field: field,
          sid: id,
          value: value,
          hlc: hlc,
          modified: canonicalTime);
    }).toList();
    await writer!.writeTxn(() => store.storeChanges(newChanges));
    await _updateTables(since: canonicalTime);
    return canonicalTime;
  }
}

final Map<String, IsarCrdtStoreHandler> _isarProcessors = {};

extension IsarCrdtExtension on Isar {
  void setCrdt(IsarCrdt crdt) {
    _isarProcessors[name] = crdt._handler(this);
  }

  IsarCrdtStoreHandler? get crdt {
    return _isarProcessors[name];
  }
}
