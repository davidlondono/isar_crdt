// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';

import 'package:isar/isar.dart';

import 'changes/isar_write_changes.dart';
import 'models/operation_change.dart';
import 'utils/hlc.dart';

export 'models/models.dart';
export 'isar_model_processor/isar_model_processor.dart';

abstract class ProcessData {
  Future<Hlc> canonicalTime();
  Future<List<OperationChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  });
  Future<void> storeChanges(List<OperationChange> changes);
}

class IsarChangesSync {
  final Isar isar;
  final ProcessData processor;
  const IsarChangesSync({
    required this.isar,
    required this.processor,
  });

  Future<Hlc> _canonicalTime() => processor.canonicalTime();

  Future<List<OperationChange>> getChanges(
      {Hlc? modifiedSince, bool onlyModifiedHere = false}) async {
    String? hlcNode;
    if (onlyModifiedHere) {
      final time = await _canonicalTime();
      hlcNode = time.nodeId;
    }

    return processor.queryChanges(hlcNode: hlcNode, hlcSince: modifiedSince);
  }

  Future<void> _updateTables({Hlc? since}) async {
    final changes = await getChanges(modifiedSince: since);
    if (changes.isEmpty) return;

    await IsarWriteChanges(isar).upgradeChanges(changes);
  }

  Future<Hlc> merge(List<Map<String, dynamic>> changeset) async {
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
          operation: ChangesyncOperations.values.byName(map['operation']),
          field: field,
          sid: id,
          value: value,
          hlc: hlc,
          modified: canonicalTime);
    }).toList();
    await processor.storeChanges(newChanges);
    // TODO filter out changes that are already in the database
    await _updateTables(since: canonicalTime);
    return canonicalTime;
  }

  Future<void> saveChanges(
      Isar isar, List<NewOperationChange> changes) async {
    final canonical = await _canonicalTime();
    final hlc = Hlc.send(canonical);

    final newChanges = changes
        .map((change) => change.withHlc(hlc: hlc, modified: canonical))
        .toList();

    await processor.storeChanges(newChanges);
  }
}

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
