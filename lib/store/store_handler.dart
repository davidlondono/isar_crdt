import '../operations/new_change.dart';
import '../operations/storable_change.dart';
import 'store.dart';

class IsarCrdtStoreHandler {
  const IsarCrdtStoreHandler({
    required this.store,
  });
  final CrdtStore store;

  String generateRandomSid() => store.generateRandomSid();

  Future<void> saveChanges(List<NewOperationChange> changes) async {
    final canonical = await store.canonicalTime();
    final hlc = canonical.increment();

    final newChanges = changes
        .map((change) =>
            StorableChange(change: change, hlc: hlc, modified: canonical),)
        .toList();

    await store.storeChanges(newChanges);
  }
}
