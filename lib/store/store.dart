import 'dart:async';

import 'package:isar_crdt/operations/storable_change.dart';

import '../utils/hlc.dart';

abstract class CrdtStore {
  Future<Hlc> canonicalTime();
  Hlc canonicalTimeSync();
  Future<List<StorableChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  });
  Stream<List<StorableChange>> watchChanges({
    String? hlcNode,
    Hlc? hlcSince,
  });
  Future<void> storeChanges(List<StorableChange> changes);
  String generateRandomSid();

  String get nodeId;

  const CrdtStore();
}
