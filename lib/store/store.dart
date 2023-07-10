import 'dart:async';

import '../operations/storable_change.dart';

import '../utils/hlc.dart';

abstract class CrdtStore {
  const CrdtStore();
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

  Future<List<StorableChange>> filterStoredChanges(
    List<StorableChange> records,
  );

  Future<List<StorableChange>> storeChanges(List<StorableChange> changes);
  String generateRandomSid();

  String get nodeId;
}
