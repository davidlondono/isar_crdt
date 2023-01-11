// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:isar/isar.dart';

import 'operation_change.dart';
import '../utils/hlc.dart';

class CrdtBaseModel {
  CrdtBaseModel();
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

  // static CrdtBaseModel fromChange(OperationChange change) => CrdtBaseModel()
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
        operation: CrdtOperations.values.byName(operation),
        value: value != null ? jsonDecode(value!) : null,
        hlc: Hlc.parse(hlc),
        modified: Hlc.parse(modified),
      );
}

extension CrdtBaseModelQueryFilter<T extends CrdtBaseModel>
    on QueryBuilder<T, T, QFilterCondition> {
  QueryBuilder<T, T, QAfterFilterCondition> hlcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.greaterThan(
        property: 'hlc',
        value: '',
      ));
    });
  }

  QueryBuilder<T, T, QAfterSortBy> sortByHlc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy('hlc', Sort.asc);
    });
  }

  QueryBuilder<T, T, QAfterFilterCondition> hlcContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hlc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<T, T, QAfterFilterCondition> hlcGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hlc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }
}
