// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';

import 'models/base_model.dart';
import 'operations/merge_change.dart';
import 'operations/storable_change.dart';
import 'store/master.dart';
import 'store/store.dart';
import 'store/store_handler.dart';
import 'utils/hlc.dart';
import 'writer/master/master.dart';
import 'writer/writer.dart';

export 'isar_extensions.dart';
export 'models/models.dart';
export 'operations/merge_change.dart';
export 'operations/operations.dart';
export 'store/master.dart';

class NoIsarConnected implements Exception {
  NoIsarConnected();
}

class IsarCrdt {
  IsarCrdt({
    required this.store,
    this.writer,
  });
  final CrdtStore store;
  CrdtWriter? writer;

  static IsarCrdt master<T extends CrdtBaseModel>({
    required IsarCollection<T> crdtCollection,
    required Future<T> Function() builder,
    required String Function() sidGenerator,
    required String nodeId,
  }) =>
      IsarCrdt(
        store: IsarMasterCrdtStore(
          crdtCollection,
          builder: builder,
          sidGenerator: sidGenerator,
          nodeId: nodeId,
        ),
      );

  IsarCrdtStoreHandler _handler(Isar isar) {
    writer ??= IsarMasterCrdtWriter(isar);
    return IsarCrdtStoreHandler(store: store);
  }

  Future<Hlc> _canonicalTime() => store.canonicalTime();
  String nodeIdSync() => store.nodeId;

  Future<List<StorableChange>> getChanges({
    Hlc? modifiedSince,
    bool onlyModifiedHere = false,
  }) async {
    String? hlcNode;
    if (onlyModifiedHere) {
      hlcNode = store.nodeId;
    }

    return store.queryChanges(hlcNode: hlcNode, hlcSince: modifiedSince);
  }

  Stream<List<StorableChange>> watchChanges({
    Hlc? modifiedSince,
    bool onlyModifiedHere = false,
  }) {
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
    final initialTime = await _canonicalTime();
    final uniqueTimes = changeset.map((e) => e.hlc).toSet().toList();

    final canonicalTime = uniqueTimes.fold(
      initialTime,
      (canonicalTime, remote) => canonicalTime.merge(remote),
    );
    final storableChanges = changeset
        .map(
          (map) => StorableChange(
            change: map.change,
            hlc: map.hlc,
            modified: canonicalTime,
          ),
        )
        .toList();
    final storedChanges =
        await writer!.writeTxn(() => store.storeChanges(storableChanges));
    await _updateTables(storedChanges);
    return canonicalTime;
  }
}

final Map<String, IsarCrdtStoreHandler> _isarProcessors = {};

extension IsarCrdtExtension on Isar {
  void setCrdt(IsarCrdt crdt) {
    _isarProcessors[name] = crdt._handler(this);
  }

  IsarCrdtStoreHandler? get crdt => _isarProcessors[name];
}
