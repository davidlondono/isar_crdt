import 'dart:convert';

import 'package:collection/collection.dart';

import '../utils/hlc.dart';
import 'operations.dart';

bool isSameType<S, T>() => S == T;

dynamic _encode(dynamic value) {
  if (value == null) return null;
  if (value is Map) return jsonEncode(value);

  switch (value.runtimeType) {
    case String:
    case int:
    case double:
      return value;
    case bool:
      return value ? 1 : 0;
    case DateTime:
      return value.toUtc().toIso8601String();
    case Hlc:
      return value.toString();
    default:
      throw 'Unsupported type: ${value.runtimeType}';
  }
}

class NewOperationChange {
  // attributes
  final String collection;
  final String sid;
  final String? field;
  final String? value;
  final CrdtOperations operation;
  final String? workspace;

  const NewOperationChange({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
    required this.operation,
    required this.workspace,
  });
  NewOperationChange.insert({
    required this.collection,
    required this.sid,
    required this.value,
    required this.workspace,
  })  : operation = CrdtOperations.insert,
        field = null;

  NewOperationChange.edit({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
    required this.workspace,
  }) : operation = CrdtOperations.update;

  NewOperationChange.delete({
    required this.collection,
    required this.sid,
    required this.workspace,
  })  : operation = CrdtOperations.delete,
        field = null,
        value = null;

  NewOperationChange.fromJson(
    Map<String, dynamic> map,
  )   : collection = map['collection'] as String,
        field = map['field'] as String,
        sid = map['id'] as String,
        workspace = map['workspace'] as String,
        value = _encode(map['value']),
        operation = CrdtOperations.values.byName(map['operation']);

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
      "operation": operation.name,
    };
  }

  @override
  String toString() {
    return 'NewOperationChange(collection: $collection, sid: $sid, field: $field, value: $value, operation: $operation)';
  }
}
