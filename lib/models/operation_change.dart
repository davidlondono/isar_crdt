import 'package:collection/collection.dart';

import '../utils/hlc.dart';

enum ChangesyncOperations {
  insert,
  update,
  delete,
  addLink,
  removeLink,
}

bool isSameType<S, T>() => S == T;

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
    required this.value,
  })  : operation = ChangesyncOperations.insert,
        field = null;

  NewOperationChange.edit({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
  }) : operation = ChangesyncOperations.update;

  NewOperationChange.delete({
    required this.collection,
    required this.sid,
  })  : operation = ChangesyncOperations.delete,
        field = null,
        value = null;

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

  @override
  bool operator ==(Object other) {
    if (other is! NewOperationChange) return false;
    if (collection != other.collection) return false;
    if (sid != other.sid) return false;
    if (field != other.field) return false;
    if (!equalValue(other.value)) return false;
    if (operation != other.operation) return false;
    return true;
  }

  equalValue(Object? value) {
    // if (value.runtimeType != this.value.runtimeType) return false;
    if (value is String ||
        value is int ||
        value is double ||
        value is bool ||
        value is DateTime ||
        value is Hlc ||
        value == null) {
      return value == this.value;
    }
    if (value is List) {
      return ListEquality().equals(value, this.value as List);
    }
    if (value is Map) {
      return MapEquality().equals(value, this.value as Map);
    }
    if (value is Set) {
      return SetEquality().equals(value, this.value as Set);
    }

    return false;
  }

  @override
  int get hashCode {
    return Object.hashAll([collection, sid, field, value, operation]);
  }

  Map<String, dynamic> toJson() {
    return {
      "collection": collection,
      "sid": sid,
      "field": field,
      "value": value,
      "operation": operation,
    };
  }

  @override
  String toString() {
    return 'NewOperationChange(collection: $collection, sid: $sid, field: $field, value: $value, operation: $operation)';
  }
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
