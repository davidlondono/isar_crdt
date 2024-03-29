import '../operations/storable_change.dart';

abstract class CrdtWriter {
  const CrdtWriter();
  Future<void> upgradeChanges(List<StorableChange> records);

  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false});
  Future<void> clear();
}
