import 'package:isar_crdt/operations/storable_change.dart';
import 'package:isar_crdt/store/store.dart';
import 'package:isar_crdt/utils/hlc.dart';
import 'package:isar_crdt/writer/writer.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:isar_crdt/isar_crdt.dart';

import 'isar_crdt_test.mocks.dart';
import 'utils/fake_isar.dart';

final operationMock = StorableChange(
  change: NewOperationChange(
      collection: 'CarModel',
      field: 'ee',
      operation: CrdtOperations.addLink,
      sid: "",
      value: "ee",
      workspace: "workspace"),
  hlc: Hlc.zero('mock'),
  modified: Hlc.zero("nodeId"),
);

@GenerateMocks([
  CrdtStore,
  CrdtWriter
], customMocks: [
  // MockSpec<Isar>(as: #FakeIsar)
])
void main() {
  final store = MockCrdtStore();
  final writer = MockCrdtWriter();
  final isar = MockIsar();
  late IsarCrdt crdt;

  final String nodeId = 'test-nodeid';
  setUpAll(() async {
    // await Isar.initializeIsarCore(download: true);
    crdt = IsarCrdt(store: store, writer: writer);
  });
  setUp(() {
    reset(store);
    reset(writer);
    when(store.nodeId).thenReturn(nodeId);
    when(writer.writeTxn(any)).thenAnswer(
      (realInvocation) {
        final ee = realInvocation.positionalArguments[0] as Function();
        return ee();
      },
    );
    when(store.queryChanges(
            hlcNode: anyNamed('hlcNode'), hlcSince: anyNamed('hlcSince')))
        .thenAnswer((realInvocation) async => [operationMock]);
  });
  group("getChanges", () {
    test('get all changes', () async {
      final changes = await crdt.getChanges();
      verify(store.queryChanges(hlcNode: null, hlcSince: null));
      expect(changes, [operationMock]);
    });

    test('changes since date', () async {
      final hlsModified = Hlc.now('hlsModified');
      final changes = await crdt.getChanges(modifiedSince: hlsModified);
      expect(
          verify(store.queryChanges(
                  hlcNode: null,
                  hlcSince: captureThat(same(hlsModified), named: "hlcSince")))
              .captured,
          [hlsModified]);
      expect(changes, [operationMock]);
    });
    test('changes onlyModifiedHere', () async {
      final changes = await crdt.getChanges(onlyModifiedHere: true);

      verifyNever(store.canonicalTime());
      expect(
          verify(store.queryChanges(
                  hlcNode:
                      captureThat(same(nodeId), named: "hlcNode"),
                  hlcSince: null))
              .captured,
          [nodeId]);
      expect(changes, [operationMock]);
    });
  });
  group("clearRebuild", () {
    test('changes onlyModifiedHere', () async {
      when(writer.upgradeChanges(any)).thenAnswer((_) async => []);
      when(isar.clear()).thenAnswer((realInvocation) async {});
      when(store.storeChanges(any)).thenAnswer((realInvocation) async {});

      await crdt.clearRebuild();

      verify(writer.clear());
      expect(verify(store.storeChanges(captureAny)).captured, [
        [operationMock]
      ]);
      expect(verify(writer.upgradeChanges(captureAny)).captured, [
        [operationMock]
      ]);
    });
  });
}
