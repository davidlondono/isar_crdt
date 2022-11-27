// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:isar/isar.dart';
import '../isar_changesync.dart';
import '../utils/sid.dart';

import '../utils/hlc.dart';

class IsarModelProcessor<T extends ChangesyncBaseModel> extends ProcessData {
  final IsarCollection<T> changesyncCollection;
  final T Function() builder;
  IsarModelProcessor(
    this.changesyncCollection, {
    required this.builder,
  });

  @override
  Future<Hlc> canonicalTime() async {
    final entry = await changesyncCollection
        .filter()
        ._hlcIsNotEmpty()
        ._sortByHlc()
        .findFirst();
    if (entry == null) return Hlc.zero(SidUtils.random());
    return Hlc.parse(entry.hlc);
  }

  OperationChange entryToChange(T entry) => entry.toChange();

  T changeToEntry(OperationChange change) => builder()..fromChange(change);

  @override
  Future<List<OperationChange>> queryChanges({
    String? hlcNode,
    Hlc? hlcSince,
  }) async {
    var query = changesyncCollection.filter()._hlcIsNotEmpty();
    if (hlcNode != null) {
      query = query._hlcContains(hlcNode);
    }
    if (hlcSince != null) {
      query = query._hlcGreaterThan(hlcSince.toString());
    }
    final values = await query.findAll();
    return values.map(entryToChange).toList();
  }

  @override
  Future<void> storeChanges(List<OperationChange> changes) async {
    final entries = changes.map(changeToEntry).toList();
    await changesyncCollection.putAll(entries);
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

  QueryBuilder<T, T, QAfterFilterCondition> _hlcContains(String value,
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
