import 'package:test/test.dart';
import 'package:isar/isar.dart';
import 'package:isar_changesync/changes/isar_write_changes.dart';
import 'package:isar_changesync/utils/hlc.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:isar_changesync/isar_changesync.dart';

import 'isar_changesync_test.mocks.dart';

final operationMock = OperationChange(
    collection: 'CarModel',
    field: 'ee',
    hlc: Hlc.zero('mock'),
    modified: Hlc.zero("nodeId"),
    operation: ChangesyncOperations.addLink,
    sid: "",
    value: "ee");

class FakeIsar extends Mock implements Isar {
  FakeIsar();

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback,
      {bool silent = false}) async {
    return callback();
  }

  @override
  Future<void> clear() {
    return super.noSuchMethod(Invocation.method(#clear, []),
        returnValue: Future.value());
    // return Future.value();
  }
}

@GenerateMocks([
  ProcessData,
  IsarWriteChanges
], customMocks: [
  // MockSpec<Isar>(as: #FakeIsar)
])
void main() {
  final processor = MockProcessData();
  final writer = MockIsarWriteChanges();
  final isar = FakeIsar();
  late IsarChangesSync changesSync;
  setUpAll(() async {
    // await Isar.initializeIsarCore(download: true);
    changesSync =
        IsarChangesSync(isar: isar, processor: processor, writer: writer);
  });
  setUp(() {
    reset(processor);
    reset(writer);
    when(processor.queryChanges(
            hlcNode: anyNamed('hlcNode'), hlcSince: anyNamed('hlcSince')))
        .thenAnswer((realInvocation) async => [operationMock]);
  });
  group("getChanges", () {
    test('get all changes', () async {
      final changes = await changesSync.getChanges();
      verify(processor.queryChanges(hlcNode: null, hlcSince: null));
      expect(changes, [operationMock]);
    });

    test('changes since date', () async {
      final hlsModified = Hlc.now('hlsModified');
      final changes = await changesSync.getChanges(modifiedSince: hlsModified);
      expect(
          verify(processor.queryChanges(
                  hlcNode: null,
                  hlcSince: captureThat(same(hlsModified), named: "hlcSince")))
              .captured,
          [hlsModified]);
      expect(changes, [operationMock]);
    });
    test('changes onlyModifiedHere', () async {
      final canonicalTime = Hlc.now('canonicalTime');
      when(processor.canonicalTime()).thenAnswer((_) async => canonicalTime);

      final changes = await changesSync.getChanges(onlyModifiedHere: true);

      expect(
          verify(processor.queryChanges(
                  hlcNode:
                      captureThat(same(canonicalTime.nodeId), named: "hlcNode"),
                  hlcSince: null))
              .captured,
          [canonicalTime.nodeId]);
      expect(changes, [operationMock]);
    });
  });
  group("clearRebuild", () {
    test('changes onlyModifiedHere', () async {
      when(writer.upgradeChanges(any)).thenAnswer((_) async => []);
      when(isar.clear()).thenAnswer((realInvocation) async {});
      when(processor.storeChanges(any)).thenAnswer((realInvocation) async {});

      await changesSync.clearRebuild();

      verify(isar.clear());
      expect(verify(processor.storeChanges(captureAny)).captured, [
        [operationMock]
      ]);
      expect(verify(writer.upgradeChanges(captureAny)).captured, [
        [operationMock]
      ]);
    });
  });
}
