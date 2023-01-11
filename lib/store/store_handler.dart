import '../utils/hlc.dart';

import '../models/operation_change.dart';
import 'store.dart';

class IsarCrdtStoreHandler {
  final CrdtStore store;
  const IsarCrdtStoreHandler({
    required this.store,
  });

  String generateRandomSid() => store.generateRandomSid();

  Future<void> saveChanges(List<NewOperationChange> changes) async {
    final canonical = await store.canonicalTime();
    final hlc = Hlc.send(canonical);

    final newChanges = changes
        .map((change) => change.withHlc(hlc: hlc, modified: canonical))
        .toList();

    // TODO filter out changes that are already in the database

    await store.storeChanges(newChanges);
  }
}
