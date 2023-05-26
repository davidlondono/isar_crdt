import 'package:isar/isar.dart';
import 'package:isar_crdt/isar_crdt.dart';

part 'models.g.dart';

@collection
class CarModel extends CrdtBaseObject {
  Id id = Isar.autoIncrement;
  late String make;
  late String year;
  late String workspace;

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "sid": sid,
      "make": make,
      "year": year,
      "workspace": workspace,
    };
  }

  static CarModel fabric(String number) {
    return CarModel()
      ..make = "make $number"
      ..year = "year $number";
  }
}


@collection
class CrdtModel extends CrdtBaseModel {
}
