
import '../utils/hlc.dart';

enum ChangesyncOperations {
  insert,
  update,
  delete,
  addLink,
  removeLink,
}
class NewOperationChange {
  // attributes
  final String collection;
  final String sid;
  final String? field;
  final Object? value;
  final ChangesyncOperations operation;

  const NewOperationChange({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
    required this.operation,
  });
  NewOperationChange.insert({
    required this.collection,
    required this.sid,
  }) : operation = ChangesyncOperations.insert, field = null, value = null;

  NewOperationChange.edit({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
  }) : operation = ChangesyncOperations.update;

  NewOperationChange.delete({
    required this.collection,
    required this.sid,
  }) : operation = ChangesyncOperations.delete, field = null, value = null;

  OperationChange withHlc({
    required Hlc hlc,
    required Hlc modified,
  }) =>
      OperationChange(
        collection: collection,
        sid: sid,
        field: field,
        value: value,
        operation: operation,
        hlc: hlc,
        modified: modified,
      );
  
}


class OperationChange extends NewOperationChange {
  final Hlc hlc;
  final Hlc modified;
  const OperationChange({
    required super.operation,
    required super.collection,
    required super.sid,
    required super.field,
    required super.value,
    required this.hlc,
    required this.modified,
  });
}