// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import 'store.dart';
import '../isar_crdt.dart';
import '../utils/sid.dart';

import '../utils/hlc.dart';

class IsarMasterCrdtStore<T extends CrdtBaseModel> extends CrdtStore {
  final IsarCollection<T> crdtCollection;
  final T Function() builder;
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

  OperationChange _entryToChange(T entry) => entry.toChange();

  T _changeToEntry(OperationChange change) => builder()..fromChange(change);

  @override
  Future<List<OperationChange>> queryChanges({
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
  Future<void> storeChanges(List<OperationChange> changes) async {
    final entries = changes.map(_changeToEntry).toList();
    await crdtCollection.putAll(entries);
  }

  @override
  String generateRandomSid() {
    return sidGenerator();
  }
}
