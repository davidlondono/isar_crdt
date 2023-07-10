// ignore_for_file: invalid_use_of_protected_member

import 'package:isar/isar.dart';

import '../operations/operations.dart';
import '../operations/storable_change.dart';
import '../utils/hlc.dart';
import 'models.dart';

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
  Map<String, dynamic> toJson() => {
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

  NewOperationChange toOperationChange() => NewOperationChange(
      collection: collection,
      field: field,
      sid: rowId,
      operation: CrdtOperations.fromString(operation),
      value: value,
      workspace: workspace,
    );
}

extension CrdtBaseModelQueryFilter<T extends CrdtBaseModel>
    on QueryBuilder<T, T, QFilterCondition> {
  QueryBuilder<T, T, R> _build<R>(
          QueryBuilderInternal<T> Function(QueryBuilderInternal<T> query)
              transform,) =>
      QueryBuilder.apply<T, T, R>(this, transform);

  QueryBuilder<T, T, QAfterFilterCondition> _addFilterCondition(
          FilterOperation cond,) =>
      _build((query) => query.addFilterCondition(cond));

  QueryBuilder<T, T, QAfterFilterCondition> _addGreaterThan(
          {required String property,
          required Object? value,
          bool include = false,
          bool caseSensitive = true,}) =>
      _addFilterCondition(FilterCondition.greaterThan(
        property: property,
        value: value,
        include: include,
        caseSensitive: caseSensitive,
      ),);

  QueryBuilder<T, T, QAfterFilterCondition> _addEqualTo(
          {required String property,
          required Object? value,
          bool caseSensitive = true,}) =>
      _addFilterCondition(FilterCondition.equalTo(
        property: property,
        value: value,
        caseSensitive: caseSensitive,
      ),);
  QueryBuilder<T, T, QAfterFilterCondition> _addIsNull(
          {required String property,}) =>
      _addFilterCondition(FilterCondition.isNull(
        property: property,
      ),);

  QueryBuilder<T, T, QAfterFilterCondition> _addContains(
          {required String property,
          required String value,
          bool caseSensitive = true,}) =>
      _addFilterCondition(FilterCondition.contains(
        property: 'hlc',
        value: value,
        caseSensitive: caseSensitive,
      ),);

  QueryBuilder<T, T, QAfterSortBy> _addSortBy<R>(
          String propertyName, Sort sort,) =>
      _build((query) => query.addSortBy(propertyName, sort));

  QueryBuilder<T, T, QAfterFilterCondition> hlcIsNotEmpty() =>
      _addGreaterThan(property: 'hlc', value: '');

  QueryBuilder<T, T, QAfterSortBy> sortByHlc() => _addSortBy('hlc', Sort.asc);

  QueryBuilder<T, T, QAfterSortBy> sortByModified() =>
      _addSortBy('modified', Sort.asc);

  QueryBuilder<T, T, QAfterFilterCondition> hlcContains(String value,
          {bool caseSensitive = true,}) =>
      _addContains(property: 'hlc', value: value, caseSensitive: caseSensitive);

  QueryBuilder<T, T, QAfterFilterCondition> hlcGreaterThan(
    Hlc value, {
    bool include = false,
    bool caseSensitive = true,
  }) =>
      _addGreaterThan(
          property: 'hlc',
          value: value.toString(),
          include: include,
          caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> modifiedGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) =>
      _addGreaterThan(
          property: 'modified',
          value: value,
          include: include,
          caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> hlcEqualTo(
    Hlc value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'hlc',
          value: value.toString(),
          caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> collectionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'collection', value: value, caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> rowIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'rowId', value: value, caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> fieldEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) =>
      value == null
          ? _addIsNull(property: 'field')
          : _addEqualTo(
              property: 'field', value: value, caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> valueEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'value', value: value, caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> workspaceEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'workspace', value: value, caseSensitive: caseSensitive,);

            QueryBuilder<T, T, QAfterFilterCondition> idEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'id', value: value, caseSensitive: caseSensitive,);

  QueryBuilder<T, T, QAfterFilterCondition> operationEqualTo(
    CrdtOperations value, {
    bool caseSensitive = true,
  }) =>
      _addEqualTo(
          property: 'operation',
          value: value.value,
          caseSensitive: caseSensitive,);

}
