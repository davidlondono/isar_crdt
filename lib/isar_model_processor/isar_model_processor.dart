// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import 'package:isar_changesync/isar_changesync.dart';
import 'package:isar_changesync/models/changesync_base_model.dart';
import 'package:isar_changesync/utils/sid.dart';

import '../models/operation_change.dart';
import '../utils/hlc.dart';

class IsarModelProcessor<T extends ChangesyncBaseModel> extends ProcessData {
  final IsarCollection<T> changesyncCollection;
  IsarModelProcessor(this.changesyncCollection);

  @override
  Future<Hlc> canonicalTime() async {
    final entry =
        await changesyncCollection.filter()._hlcIsNotEmpty()._sortByHlc().findFirst();
    if (entry == null) return Hlc.zero(SidUtils.random());
    return Hlc.parse(entry.hlc);
  }

  OperationChange entryToChange(T entry) => entry.toChange();

  T changeToEntry(OperationChange change) => ChangesyncBaseModel.fromChange(change);

  @override
  Future<List<OperationChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  }) {
    var query = changesyncCollection.filter()._hlcIsNotEmpty();
    if (hlcNode != null) {
      query = query._hlcContains(hlcNode);
    }
    if (hlcSince != null) {
      query = query._hlcGreaterThan(hlcSince.toString());
    }
    return query.findAll().then((value) => value.map(entryToChange).toList());
  }

  @override
  Future<void> storeChanges(List<OperationChange> changes) async {
    await changesyncCollection.isar
        .writeTxn(() => changesyncCollection.putAll(changes.map(changeToEntry).toList()));
  }
}

extension ChangesyncBaseModelQueryFilter<T extends ChangesyncBaseModel>
    on QueryBuilder<T, T, QFilterCondition> {
  QueryBuilder<T, T, QAfterFilterCondition> _hlcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.greaterThan(
        property: 'hlc',
        value: '',
      ));
    });
  }

  QueryBuilder<T, T, QAfterSortBy> _sortByHlc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy('hlc', Sort.asc);
    });
  }

    QueryBuilder<T, T, QAfterFilterCondition> _hlcContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'hlc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }
  QueryBuilder<T, T, QAfterFilterCondition> _hlcGreaterThan(
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
