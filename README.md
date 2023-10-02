<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->


<h1 align="center">Isar Crdt</h1>
addon to add crdt capabilities to isar


## Features
- Pure Dart
- Save changes on collection

## Getting started

### 1. Add to pubspec.yaml

```yaml
dependencies:
  isar_crdt: ^0.0.1
```
## Usage

1. extend your models with CrdtBaseObject
- add toJson function and add all the fields you want to sync (include id and sid)
2. Create a model to store the crdt changes and extends with CrdtBaseObject
- no need to add anything
```dart
// models
@collection
class CarModel extends CrdtBaseObject {
  Id id = Isar.autoIncrement;
  late String make;
  late String year;

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "sid": sid,
      "make": make,
      "year": year,
    };
  }
}

@collection
class CrdtEntry extends CrdtBaseObject {}
```
3. add the models including the crdt model to the isar instance
4. create a changesync instance and add it to the isar instance
```dart
   final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
      [CarModelSchema, CrdtEntrySchema],
      dir: dir.path,
    );


  final changesSync = IsarCrdt(
    store: IsarMasterCrdtStore(
      isar.crdtEntrys,
      nodeId: "", // change to your own nodeId
      builder: () => CrdtEntry(),
      sidGenerator: () => uuid.v4(),
    ),
  );
  isar.setCrdt(changesSync);
```

5. don't forget to import the packages as they are required as the example shown here above
   ```dart
import 'package:uuid/uuid.dart';
import 'package:isar/isar.dart';
import 'package:isar_crdt/isar_crdt.dart';
import 'package:path_provider/path_provider.dart';
```



## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
