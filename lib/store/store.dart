import 'dart:async';

import '../models/operation_change.dart';
import '../utils/hlc.dart';

abstract class CrdtStore {
  Future<Hlc> canonicalTime();
  Future<List<OperationChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  });
  Future<void> storeChanges(List<OperationChange> changes);
  String generateRandomSid();

  const CrdtStore();
}
