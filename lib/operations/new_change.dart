import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../utils/hlc.dart';
import 'operations.dart';

@immutable
class NewOperationChange {
  const NewOperationChange({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
    required this.operation,
    required this.workspace,
  });
  const NewOperationChange.insert({
    required this.collection,
    required this.sid,
    required this.value,
    required this.workspace,
  })  : operation = CrdtOperations.insert,
        field = null;

  const NewOperationChange.edit({
    required this.collection,
    required this.sid,
    required this.field,
    required this.value,
    required this.workspace,
  }) : operation = CrdtOperations.update;

  const NewOperationChange.delete({
    required this.collection,
    required this.sid,
    required this.workspace,
  })  : operation = CrdtOperations.delete,
        field = null,
        value = null;

  // attributes
  final String collection;
  final String sid;
  final String? field;
  final String? value;
  final CrdtOperations operation;
  final String? workspace;

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

  bool equalValue(Object? value) {
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
      return const ListEquality().equals(value, this.value! as List);
    }
    if (value is Map) {
      return const MapEquality().equals(value, this.value! as Map);
    }
    if (value is Set) {
      return const SetEquality().equals(value, this.value! as Set);
    }

    return false;
  }

  @override
  int get hashCode => Object.hashAll(
        [collection, sid, field, value, operation],
      );

  Map<String, dynamic> toJson() => {
        'collection': collection,
        'sid': sid,
        'field': field,
        'value': value,
        'operation': operation.name,
      };
}
