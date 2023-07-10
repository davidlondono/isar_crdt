import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:isar_crdt/utils/hlc.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import 'package:isar_crdt/isar_crdt.dart';

import 'models/models.dart';

void main() {
  late Isar isar;
  late IsarCrdt crdt;

  final String nodeId = 'test-nodeid';
  final String remoteNodeId = 'test-nodeid-remote';
  final String workspace = 'test-workspace';
  setUpAll(() async {
    // Call the registerChanges() method
    await Isar.initializeIsarCore(download: true);

    final dartToolDir = path.join(Directory.current.path, '.dart_tool');
    final testTempPath = path.join(dartToolDir, 'test', 'tmp');
    await Directory(testTempPath).create(recursive: true);
    isar = await Isar.open(
      [CarModelSchema, CrdtModelSchema],
      directory: testTempPath,
    );

    crdt = IsarCrdt.master(
        crdtCollection: isar.crdtModels,
        builder: () => Future.value(CrdtModel()),
        sidGenerator: () => 'sid',
        nodeId: nodeId);
    isar.setCrdt(crdt);
  });
  setUp(() async {
    return isar.writeTxn(() => isar.clear());
  });
  group("crdt merge insert", () {
    test('should insert a model', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: Hlc.now(remoteNodeId),
        )
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);
      expect(cars[0].make, 'Toyota');
      expect(cars[0].year, '2020');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });

    test('should insert only one with the same insert sid', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      const jsonCar2 = {
        "make": "Hunday",
        "year": "2022",
      };
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: Hlc.now(remoteNodeId),
        ),
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar2),
              workspace: workspace),
          hlc: Hlc.now(remoteNodeId),
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);
      expect(cars[0].make, 'Hunday');
      expect(cars[0].year, '2022');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });

    test('should store non repeated changes', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      const jsonCar2 = {
        "make": "Hunday",
        "year": "2022",
      };

      final time = Hlc.now(remoteNodeId);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.delete(
              collection: 'CarModel', sid: 'car-sid-1', workspace: workspace),
          hlc: time,
        ),
        MergableChange(
          change: NewOperationChange.delete(
              collection: 'CarModel', sid: 'car-sid-2', workspace: workspace),
          hlc: time,
        ),
      ]);
      final count1 = await isar.crdtModels.where().count();
      expect(count1, 2);

      await crdt.merge([
        MergableChange(
          change: NewOperationChange.delete(
              collection: 'CarModel', sid: 'car-sid-2', workspace: workspace),
          hlc: time,
        ),
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-3',
              value: jsonEncode(jsonCar2),
              workspace: workspace),
          hlc: time,
        ),
      ]);

      final count2 = await isar.crdtModels.where().count();

      expect(count2, 3);

      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);
      expect(cars[0].make, 'Hunday');
      expect(cars[0].year, '2022');
      expect(cars[0].sid, 'car-sid-3');
      expect(cars[0].workspace, workspace);
    });

    test('should insert multiple with differnet sid', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      const jsonCar2 = {
        "make": "Hunday",
        "year": "2022",
      };
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: Hlc.zero(remoteNodeId),
        ),
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-2',
              value: jsonEncode(jsonCar2),
              workspace: workspace),
          hlc: Hlc.now(remoteNodeId),
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 2);

      expect(cars[0].make, 'Toyota');
      expect(cars[0].year, '2020');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);

      expect(cars[1].make, 'Hunday');
      expect(cars[1].year, '2022');
      expect(cars[1].sid, 'car-sid-2');
      expect(cars[0].workspace, workspace);
    });
  });

  group('update operation', () {
    test('should update multiple with separated merge', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      final initialTime = Hlc.now(remoteNodeId);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'make',
              value: jsonEncode("Hunday"),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'year',
              value: jsonEncode("2022"),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);

      expect(cars[0].make, 'Hunday');
      expect(cars[0].year, '2022');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });

    test('should update multiple with separated merge', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      final initialTime = Hlc.now(remoteNodeId);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
      ]);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'make',
              value: jsonEncode("Hunday"),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
      ]);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'year',
              value: jsonEncode("2022"),
              workspace: workspace),
          hlc: initialTime.increment(),
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);

      expect(cars[0].make, 'Hunday');
      expect(cars[0].year, '2022');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });

    test('should update fields and avoid old updates', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      final initialTime = Hlc.now(remoteNodeId);
      final time1 = initialTime.increment();
      final time2 = time1.increment();
      final time3 = time2.increment();
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: initialTime,
        ),
      ]);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'make',
              value: jsonEncode("Hunday"),
              workspace: workspace),
          hlc: time3,
        ),
      ]);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'make',
              value: jsonEncode("Fake"),
              workspace: workspace),
          hlc: time2,
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);

      expect(cars[0].make, 'Hunday');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });

    test('merge 2 remote edit changes', () async {
      const jsonCar = {
        "make": "Toyota",
        "year": "2020",
      };
      final firstTime = Hlc.now(remoteNodeId);
      final secondTime = firstTime.add(Duration(seconds: 10));
      final thirdTime = secondTime.add(Duration(seconds: 10));
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.insert(
              collection: 'CarModel',
              sid: 'car-sid-1',
              value: jsonEncode(jsonCar),
              workspace: workspace),
          hlc: firstTime,
        ),
      ]);
      await crdt.merge([
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'make',
              value: jsonEncode("Hunday"),
              workspace: workspace),
          hlc: secondTime,
        ),
        MergableChange(
          change: NewOperationChange.edit(
              collection: 'CarModel',
              sid: 'car-sid-1',
              field: 'year',
              value: jsonEncode("2022"),
              workspace: workspace),
          hlc: thirdTime,
        ),
      ]);
      final cars = await isar.carModels.where().findAll();
      expect(cars.length, 1);

      expect(cars[0].make, 'Hunday');
      expect(cars[0].sid, 'car-sid-1');
      expect(cars[0].workspace, workspace);
    });
  });
}
