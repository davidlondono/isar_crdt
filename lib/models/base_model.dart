// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:isar_crdt/models/models.dart';
import 'package:isar_crdt/operations/operations.dart';
import 'package:isar_crdt/operations/storable_change.dart';

abstract class CrdtBaseModel {
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
  late String? workspace;
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
      'workspace': workspace,
    };
  }

  void fromChange(StorableChange sc) {
    collection = sc.change.collection;
    field = sc.change.field;
    rowId = sc.change.sid;
    operation = sc.change.operation.name;
    value = sc.change.value.toString();
    hlc = sc.hlc.toString();
    modified = sc.modified.toString();
    workspace = sc.change.workspace;
  }

  NewOperationChange toOperationChange() {
    return NewOperationChange(
      collection: collection,
      field: field,
      sid: rowId,
      operation: CrdtOperations.fromString(operation),
      value: value,
      workspace: workspace,
    );
  }
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
