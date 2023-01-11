import '../models/operation_change.dart';

abstract class CrdtWriter {
  Future<void> upgradeChanges(List<OperationChange> records);

  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false});
  Future<void> clear();
  const CrdtWriter();
}
