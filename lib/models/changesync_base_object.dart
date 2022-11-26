

import 'package:isar/isar.dart';

abstract class ChangesyncBaseObject {
  String sid = "";
  Map<String, dynamic> toJson();

  IsarLink<dynamic>? getLink(String link) {
    throw UnimplementedError();
  }
  IsarLinks<dynamic>? getLinks(String link) {
    throw UnimplementedError();
  }
}