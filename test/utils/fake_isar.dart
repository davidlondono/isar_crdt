import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';

class MockIsar extends Mock implements Isar {
  MockIsar();

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback,
      {bool silent = false}) async {
    return callback();
  }

  @override
  Future<void> clear() {
    return super.noSuchMethod(Invocation.method(#clear, []),
        returnValue: Future.value());
  }
}