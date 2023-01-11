import 'package:isar_crdt/isar_crdt.dart';
import 'package:mockito/mockito.dart';

class FMockIsarCrdt extends Mock implements IsarCrdt {
  FMockIsarCrdt();
  // Implement the required methods with mock behavior

  @override
  Future<void> saveChanges(List<NewOperationChange> changes) {
    return super.noSuchMethod(Invocation.method(#saveChanges, []),
        returnValue: Future.value());
  }
}
