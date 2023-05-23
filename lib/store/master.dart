// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import 'package:isar_crdt/operations/storable_change.dart';
import 'store.dart';
import '../isar_crdt.dart';
import '../utils/sid.dart';

import '../utils/hlc.dart';

class IsarMasterCrdtStore<T extends CrdtBaseModel> extends CrdtStore {
  final IsarCollection<T> crdtCollection;
  final Future<T> Function() builder;
  final String Function() sidGenerator;

  IsarMasterCrdtStore(
    this.crdtCollection, {
    required this.builder,
    required this.sidGenerator,
  });

  @override
  Future<Hlc> canonicalTime() async {
    final entry =
        await crdtCollection.filter().hlcIsNotEmpty().sortByHlc().findFirst();
    if (entry == null) return Hlc.zero(SidUtils.random());
    return Hlc.parse(entry.hlc);
  }

  @override
  Hlc canonicalTimeSync() {
    final entry =
        crdtCollection.filter().hlcIsNotEmpty().sortByHlc().findFirstSync();
    if (entry == null) return Hlc.zero(SidUtils.random());
    return Hlc.parse(entry.hlc);
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
      query = query.hlcGreaterThan(hlcSince.toString());
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
  Future<void> storeChanges(List<StorableChange> changes) async {
    final entries = await Future.wait(changes.map(_changeToEntry));
    await crdtCollection.putAll(entries);
  }

  @override
  String generateRandomSid() {
    return sidGenerator();
  }
}
