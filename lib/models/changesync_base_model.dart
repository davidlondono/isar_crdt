import 'dart:convert';

import 'package:isar/isar.dart';

import 'operation_change.dart';
import '../utils/hlc.dart';

class ChangesyncBaseModel {
  ChangesyncBaseModel();
  Id id = Isar.autoIncrement;
  // attributes
  late String collection;
  late String rowId;
  String? field;
  String? value;
  late String operation;
  @Index()
  late String hlc;
  late String modified;
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection': collection,
      'rowId': rowId,
      'field': field,
      'operation': operation,
      'value': value,
      'hlc': hlc,
      'modified': modified,
    };
  }

  // static ChangesyncBaseModel fromChange(OperationChange change) => ChangesyncBaseModel()
  //   ..fromChange(change);

  void fromChange(OperationChange change) {
    collection = change.collection;
    field = change.field;
    rowId = change.sid;
    operation = change.operation.name;
    value = jsonEncode(change.value);
    hlc = change.hlc.toString();
    modified = change.modified.toString();
  }

  OperationChange toChange() => OperationChange(
        collection: collection,
        field: field,
        sid: rowId,
        operation: ChangesyncOperations.values.byName(operation),
        value: value != null ? jsonDecode(value!) : null,
        hlc: Hlc.parse(hlc),
        modified: Hlc.parse(modified),
      );
}
