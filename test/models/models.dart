import 'package:isar/isar.dart';

part 'models.g.dart';

@collection
class CarModel {
  Id id = Isar.autoIncrement;
  late String name;
}
