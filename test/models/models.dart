import 'package:isar/isar.dart';
import 'package:isar_changesync/models/changesync_base_object.dart';

part 'models.g.dart';

@collection
class CarModel extends ChangesyncBaseObject {
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

  static CarModel fabric(String number) {
    return CarModel()
      ..make = "make $number"
      ..year = "year $number";
  }
}
