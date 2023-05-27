// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import 'package:isar_crdt/operations/merge_change.dart';
import 'package:isar_crdt/operations/storable_change.dart';
import 'models/base_model.dart';
import 'store/master.dart';
import 'writer/writer.dart';
import 'store/store.dart';
import 'store/store_handler.dart';

import 'writer/master/master.dart';
import 'utils/hlc.dart';

export 'models/models.dart';
export 'store/master.dart';
export 'isar_extensions.dart';
export 'operations/merge_change.dart';
export 'operations/operations.dart';

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

  static IsarCrdt master<T extends CrdtBaseModel>({
    required IsarCollection<T> crdtCollection,
    required Future<T> Function() builder,
    required String Function() sidGenerator,
    required String nodeId,
  }) {
    return IsarCrdt(
        store: IsarMasterCrdtStore(
      crdtCollection,
      builder: builder,
      sidGenerator: sidGenerator,
      nodeId: nodeId,
    ));
  }

  IsarCrdtStoreHandler _handler(Isar isar) {
    writer ??= IsarMasterCrdtWriter(isar);
    return IsarCrdtStoreHandler(store: store);
  }

  Future<Hlc> _canonicalTime() => store.canonicalTime();
  String nodeIdSync() => store.nodeId;

  Future<List<StorableChange>> getChanges(
      {Hlc? modifiedSince, bool onlyModifiedHere = false}) async {
    String? hlcNode;
    if (onlyModifiedHere) {
      hlcNode = store.nodeId;
    }

    return store.queryChanges(hlcNode: hlcNode, hlcSince: modifiedSince);
  }

  Stream<List<StorableChange>> watchChanges(
      {Hlc? modifiedSince, bool onlyModifiedHere = false}) {
    String? hlcNode;
    if (onlyModifiedHere) {
      hlcNode = store.nodeId;
    }

    return store.watchChanges(hlcNode: hlcNode, hlcSince: modifiedSince);
  }

  Future<void> _updateTables(List<StorableChange> changes) async {
    if (changes.isEmpty) return;
    final filteredChanges = await store.filterStoredChanges(changes);
    await writer?.upgradeChanges(filteredChanges);
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

  Future<Hlc> merge(List<MergableChange> changeset) async {
    if (writer == null) throw NoIsarConnected();
    var initialTime = await _canonicalTime();
    final uniqueTimes = changeset.map((e) => e.hlc).toSet().toList();

    final canonicalTime = uniqueTimes.fold(initialTime, (canonicalTime, remote) {
      try {
        return canonicalTime.merge(remote);
      } on DuplicateNodeException {
        return remote;
      }
    });
    final storableChanges = changeset
        .map((map) => StorableChange(
            change: map.change, hlc: map.hlc, modified: canonicalTime))
        .toList();
    await writer!.writeTxn(() => store.storeChanges(storableChanges));
    await _updateTables(storableChanges);
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
