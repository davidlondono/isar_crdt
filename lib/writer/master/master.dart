// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';

import "package:collection/collection.dart";
import 'package:isar/isar.dart';
// ignore: implementation_imports
import 'package:isar/src/common/isar_links_common.dart' show IsarLinksCommon;
import 'package:isar_crdt/operations/storable_change.dart';
import '../writer.dart';
import '../../isar_crdt.dart';

abstract class _Transaction {
  final List<StorableChange> changes;
  Future<void> run();
  _Transaction({
    required this.changes,
  });
}

class _DeleteTransaction extends _Transaction {
  final IsarCollection<dynamic> collection;
  final List<String> sids;
  _DeleteTransaction({
    required this.collection,
    required this.sids,
    required super.changes,
  });

  @override
  Future<void> run() => collection.deleteByIndex("sid", sids);
}

class _UpdateTransaction extends _Transaction {
  final IsarCollection<dynamic> collection;
  final List<Map<String, dynamic>> json;
  _UpdateTransaction({
    required this.collection,
    required this.json,
    required super.changes,
  });

  @override
  Future<void> run() async {
    await collection.importJson(json);
  }
}

enum _SyncOperationType {
  add,
  remove,
}

class _SyncOperation {
  String sid;
  String field;
  _SyncOperationType type;
  _SyncOperation({
    required this.sid,
    required this.field,
    required this.type,
  });
}

class _SyncLinksTransaction extends _Transaction {
  QueryBuilder<CrdtBaseObject, CrdtBaseObject, QAfterFilterCondition> query;
  List<_SyncOperation> operations;

  List<IsarLinks<dynamic>> linksToSave = <IsarLinks<dynamic>>[];

  _SyncLinksTransaction({
    required this.query,
    required this.operations,
    required super.changes,
  });

  Future<void> prepare() async {
    final object = await query.findFirst();

    final linksMap = {
      for (var field in operations.map((e) => e.field))
        field: object!.getLinks(field)
    };

    final byField = operations.groupListsBy((element) => element.field);

    for (final mapOperation in byField.entries) {
      final field = mapOperation.key;
      final operations = mapOperation.value;
      final links = linksMap[field];
      if (links == null) {
        throw Exception("Links not found");
      }
      final sids = operations.map((e) => e.sid).toList();
      if (links is IsarLinksCommon<CrdtBaseObject>) {
        final objects =
            await links.targetCollection._queryBySids(sids).findAll();

        for (final operation in operations) {
          final obj = objects
              .firstWhereOrNull((element) => element.sid == operation.sid);
          if (obj == null) {
            throw Exception("Object not found");
          }
          if (operation.type == _SyncOperationType.add) {
            links.add(obj);
          } else {
            links.remove(obj);
          }
        }
      } else {
        throw Exception("Unsupported links type");
      }
    }

    linksToSave = linksMap.values.whereNotNull().toList();
  }

  @override
  Future<void> run() async {
    if (linksToSave.isEmpty) {
      await prepare();
    }
    for (final links in linksToSave) {
      await links.save();
    }
  }
}

class IsarMasterCrdtWriter extends CrdtWriter {
  final Isar isar;

  const IsarMasterCrdtWriter(this.isar);

  List<_DeleteTransaction> _mapDeleteTransactions(
      List<StorableChange> deleteChanges) {
    final deleteGrouped =
        deleteChanges.groupListsBy((element) => element.change.collection);

    return deleteGrouped.entries.map((changeMap) {
      final sids = changeMap.value.map((e) => e.change.sid).toList();
      final isarCollection = changeMap.value.first.getCollection(isar);
      return _DeleteTransaction(
          collection: isarCollection!, sids: sids, changes: changeMap.value);
    }).toList();
  }

  Future<List<_UpdateTransaction>> _mapInsertTransactions(
      List<StorableChange> insertChanges,
      List<StorableChange> updatesInsertedChanges) async {
    final transactions = List<_UpdateTransaction>.empty(growable: true);
    for (final element in insertChanges
        .groupListsBy((element) => element.change.collection)
        .entries) {
      final collection = element.key;
      final isarCollection = isar.getCollectionByNameInternal(collection);
      final sids = element.value.map((e) => e.change.sid).toList();
      final objects = await isarCollection!._exportJsonFromSids(sids);

      final jsons = element.value.map((e) {
        final json =
            objects.firstWhereOrNull((js) => js["sid"] == e.change.sid) ??
                <String, dynamic>{
                  "sid": e.change.sid,
                  "workspace": e.change.workspace,
                };

        if (e.change.value == null)
          throw Exception(
              "Value is null for $element on collection $collection and sid ${e.change.sid}");
        json.addAll(jsonDecode(e.change.value.toString()));
        final entries = updatesInsertedChanges
            .where((element) =>
                element.change.sid == e.change.sid &&
                element.change.collection == e.change.collection)
            .map((element) {
          return MapEntry(element.change.field!,
              jsonDecode(element.change.value.toString()));
        });

        final mapEntries = Map.fromEntries(entries);
        json.addAll(mapEntries);
        return json;
      }).toList();

      transactions.add(_UpdateTransaction(
          collection: isarCollection, json: jsons, changes: element.value));
    }
    return transactions;
  }

  @override
  Future<void> upgradeChanges(List<StorableChange> records) async {
    if (records.isEmpty) return;

    final transactions = List<_Transaction>.empty(growable: true);

    /// Delete records transaction
    final deletedSplit = records.splitByOperation(CrdtOperations.delete);

    final deleteTransactions = _mapDeleteTransactions(deletedSplit.matched);

    transactions.addAll(deleteTransactions);
    // filter not deleted elements
    final recordsNotDeletedSplit = deletedSplit.unmatched.splitMatch((record) {
      return deletedSplit.matched.any((deletedRecord) =>
          deletedRecord.change.collection == record.change.collection &&
          deletedRecord.change.sid == record.change.sid);
    });

    /// Insert records transaction
    final insertSplit = recordsNotDeletedSplit.unmatched
        .splitByOperation(CrdtOperations.insert);

    final updatedInsertSplit = insertSplit.unmatched.splitMatch((record) =>
        record.change.operation == CrdtOperations.update &&
        insertSplit.matched
            .any((inserted) => inserted.change.sid == record.change.sid));

    final insertTransactions = await _mapInsertTransactions(
        insertSplit.matched, updatedInsertSplit.matched);

    transactions.addAll(insertTransactions);

    final updatesSplit =
        updatedInsertSplit.unmatched.splitByOperation(CrdtOperations.update);
    final updateEntries = updatesSplit.matched
        .groupListsBy((element) => element.change.collection)
        .entries;
    for (final entry in updateEntries) {
      final collection = entry.key;
      final isarCollection = isar.getCollectionByNameInternal(collection);

      final sids = entry.value.map((e) => e.change.sid).toSet().toList();
      final objects = await isarCollection!._exportJsonFromSids(sids);

      final jsons = entry.value
          .groupListsBy((element) => element.change.sid)
          .entries
          .map((e) {
        final json = objects.firstWhereOrNull((js) => js["sid"] == e.key) ??
            <String, dynamic>{
              "sid": e.key,
            };

        for (final element in e.value.sortedBy((element) => element.hlc)) {
          json[element.change.field!] = element.change.value;
        }
        return json;
      }).toList();

      transactions.add(_UpdateTransaction(
          collection: isarCollection, json: jsons, changes: entry.value));
    }
    final linkedSplit = updatesSplit.unmatched
        .splitByOperations([CrdtOperations.addLink, CrdtOperations.removeLink]);

    final linkedCleanSplit = linkedSplit.matched.splitMatch((linkChange) =>
        !deletedSplit.matched.any((deletedChange) =>
            linkChange.change.value == deletedChange.change.sid));

    final linksByColection = linkedCleanSplit.matched
        .groupListsBy((element) => element.change.collection)
        .entries;
    for (final linkedMaped in linksByColection) {
      final collection = linkedMaped.key;
      final isarCollection = isar.getCollectionByNameInternal(collection)
          as IsarCollection<CrdtBaseObject>?;

      final linkedByField = linkedMaped.value
          .groupListsBy((element) => element.change.sid)
          .entries;
      // final sids = linkedByField.map((e) => e.key).toList();
      for (final linkedFieldMap in linkedByField) {
        final sid = linkedFieldMap.key;
        final query = isarCollection!._queryBySids([sid]);

        final linkedClean = linkedFieldMap.value.where((change) {
          return !linkedFieldMap.value.where((element) {
            return change.change.sid == element.change.sid &&
                change.change.field == element.change.field &&
                change.change.value == element.change.value &&
                element.change.operation != change.change.operation;
          }).any((element) {
            return element.hlc > change.hlc;
          });
        }).toList();
        transactions.add(_SyncLinksTransaction(operations: [
          for (final record in linkedClean)
            _SyncOperation(
                type: record.change.operation == CrdtOperations.addLink
                    ? _SyncOperationType.add
                    : _SyncOperationType.remove,
                field: record.change.field!,
                sid: record.change.value as String)
        ], query: query, changes: linkedClean));
      }
    }
    await isar.writeTxn(() async {
      try {
        for (final transaction in transactions) {
          await transaction.run();
        }
      } catch (e, stackTrace) {
        print(stackTrace);
        print(e);
      }
    });
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) {
    return isar.writeTxn(callback, silent: silent);
  }

  @override
  Future<void> clear() {
    return isar.clear();
  }
}

extension _CollectionsOperations<OC extends NewOperationChange>
    on Iterable<StorableChange> {
  ListMatch<StorableChange> splitByOperation(CrdtOperations operation) {
    return splitMatch((element) => element.change.operation == operation);
  }

  ListMatch<StorableChange> splitByOperations(List<CrdtOperations> operations) {
    return splitMatch(
        (element) => operations.contains(element.change.operation));
  }
}

extension _IsarCollectionSid<T> on IsarCollection<T> {
  QueryBuilder<T, T, QAfterFilterCondition> _queryBySids(List<String> sids) {
    final filterSids = FilterGroup.or([
      for (final sid in sids)
        FilterCondition.equalTo(
          property: 'sid',
          value: sid,
        )
    ]);
    return QueryBuilder.apply<T, T, QAfterFilterCondition>(where(), (query) {
      return query.copyWith(
          filterGroupType: FilterGroupType.or, filter: filterSids);
    });
  }

  Future<List<Map<String, dynamic>>> _exportJsonFromSids(List<String> sids) =>
      _queryBySids(sids).exportJson();
}

extension EE<OC extends NewOperationChange> on StorableChange {
  IsarCollection<dynamic>? getCollection(Isar isar) {
    return isar.getCollectionByNameInternal(change.collection);
  }
}
