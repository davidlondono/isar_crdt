import 'package:test/test.dart';
import 'package:isar_crdt/changes/isar_write_changes.dart';
import 'package:isar_crdt/utils/hlc.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:isar_crdt/isar_crdt.dart';

import 'isar_crdt_test.mocks.dart';
import 'utils/fake_isar.dart';

final operationMock = OperationChange(
    collection: 'CarModel',
    field: 'ee',
    hlc: Hlc.zero('mock'),
    modified: Hlc.zero("nodeId"),
    operation: CrdtOperations.addLink,
    sid: "",
    value: "ee");

@GenerateMocks([
  ProcessData,
  IsarWriteChanges
], customMocks: [
  // MockSpec<Isar>(as: #FakeIsar)
])
void main() {
  final processor = MockProcessData();
  final writer = MockIsarWriteChanges();
  final isar = MockIsar();
  late IsarCrdt crdt;
  setUpAll(() async {
    // await Isar.initializeIsarCore(download: true);
    crdt =
        IsarCrdt(isar: isar, processor: processor, writer: writer);
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
      final changes = await crdt.getChanges();
      verify(processor.queryChanges(hlcNode: null, hlcSince: null));
      expect(changes, [operationMock]);
    });

    test('changes since date', () async {
      final hlsModified = Hlc.now('hlsModified');
      final changes = await crdt.getChanges(modifiedSince: hlsModified);
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

      final changes = await crdt.getChanges(onlyModifiedHere: true);

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

      await crdt.clearRebuild();

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
