


import 'package:isar_changesync/isar_changesync.dart';
import 'package:mockito/mockito.dart';

class FMockIsarChangesSync extends Mock implements  IsarChangesSync {
  FMockIsarChangesSync();
  // Implement the required methods with mock behavior

   @override
  Future<void> saveChanges(List<NewOperationChange> changes) {
    return super.noSuchMethod(Invocation.method(#saveChanges, []),
        returnValue: Future.value());
  }
}