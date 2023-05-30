// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import 'package:isar_crdt/operations/storable_change.dart';
import 'store.dart';
import '../isar_crdt.dart';

import '../utils/hlc.dart';

class IsarMasterCrdtStore<T extends CrdtBaseModel> extends CrdtStore {
  final IsarCollection<T> crdtCollection;
  @override
  final String nodeId;
  final Future<T> Function() builder;
  final String Function() sidGenerator;

  IsarMasterCrdtStore(
    this.crdtCollection, {
    required this.nodeId,
    required this.builder,
    required this.sidGenerator,
  });

  @override
  Future<Hlc> canonicalTime() async {
    final entry = await crdtCollection.filter().sortByModified().findFirst();
    if (entry == null) return Hlc.zero(nodeId);
    return Hlc.parse(entry.modified);
  }

  @override
  Hlc canonicalTimeSync() {
    final entry = crdtCollection.filter().sortByModified().findFirstSync();
    if (entry == null) return Hlc.zero(nodeId);
    return Hlc.parse(entry.modified);
  }

  StorableChange _entryToChange(T entry) =>
      StorableChange.fromOperationChange(change: entry);

  Future<T> _changeToEntry(StorableChange change) async {
    final changeBuild = await builder();
    changeBuild.fromChange(change);
    return changeBuild;
  }

  @override
  Future<List<StorableChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  }) async {
    var query = crdtCollection.filter().hlcIsNotEmpty();
    if (hlcNode != null) {
      query = query.hlcContains(hlcNode);
    }
    if (hlcSince != null) {
      query = query.modifiedGreaterThan(hlcSince.toString());
    }
    final values = await query.findAll();
    return values.map(_entryToChange).toList();
  }

  @override
  Stream<List<StorableChange>> watchChanges({
    String? hlcNode,
    Hlc? hlcSince,
  }) {
    var query = crdtCollection.filter().hlcIsNotEmpty();
    if (hlcNode != null) {
      query = query.hlcContains(hlcNode);
    }
    if (hlcSince != null) {
      query = query.hlcGreaterThan(hlcSince.toString());
    }
    final values = query.watch(fireImmediately: true);
    return values.map((e) => e.map(_entryToChange).toList());
  }

  @override
  Future<List<StorableChange>> storeChanges(List<StorableChange> changes) async {
    final found = await crdtCollection.filter().anyOf(
        changes,
        (q, element) {
          return q
            .operationEqualTo(element.change.operation)
            .rowIdEqualTo(element.change.sid)
            .fieldEqualTo(element.change.field)
            .workspaceEqualTo(element.change.workspace)
            .collectionEqualTo(element.change.collection)
            .hlcEqualTo(element.hlc);
        }).findAll();

    final storableChanges = changes.where((change) {
      if (found.isEmpty) return true;
      return !found.any((crdtChange) {
        if (crdtChange.workspace != change.change.workspace) return false;
        if (crdtChange.collection != change.change.collection) return false;
        if (crdtChange.rowId != change.change.sid) return false;
        if (crdtChange.field != change.change.field) return false;
        if (crdtChange.value != change.change.value.toString()) return false;
        if (crdtChange.operation != change.change.operation.value) return false;
        if (Hlc.parse(crdtChange.hlc) != change.hlc) return false;
        return true;
      });
    }).toList();
    final entries = await Future.wait(storableChanges.map(_changeToEntry));
    await crdtCollection.putAll(entries);
    return storableChanges;
  }

  @override
  String generateRandomSid() {
    return sidGenerator();
  }

  @override
  Future<List<StorableChange>> filterStoredChanges(
      List<StorableChange> records) async {
    final changes = records.map((e) => e.change).toList();

    changes.where((element) => element.operation != CrdtOperations.delete);

    final query = crdtCollection
        .filter()
        .group((q) => q.operationEqualTo(CrdtOperations.delete))
        .or()
        .group((q) => q
            .operationEqualTo(CrdtOperations.insert)
            .or()
            .operationEqualTo(CrdtOperations.update));

    final crdtChanges = await query.findAll();

    return records.where((storable) {
      final change = storable.change;
      if (change.operation != CrdtOperations.update) return true;
      final shouldCancel = crdtChanges.any((element) {
        if (element.workspace != change.workspace) return false;
        if (element.collection != change.collection) return false;
        if (element.rowId != change.sid) return false;
        if (element.field != change.field) return false;
        if (Hlc.parse(element.hlc) > storable.hlc) return true;
        return false;
      });
      return !shouldCancel;
    }).toList();
  }
}
