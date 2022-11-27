
import 'dart:convert';

import 'utils/sid.dart' show SidUtils;

import 'package:isar/isar.dart';
import 'package:isar/src/common/isar_links_common.dart' show IsarLinksCommon;

import 'isar_changesync.dart';

final List<IsarChangesSync> _isarProcessors = [];

extension IsarC on Isar {
  registerChanges(IsarChangesSync processor) {
    _isarProcessors.add(processor);
  }
}

extension IsarLinksImplChanges<T extends ChangesyncBaseObject> on IsarLinksCommon<T> {
  Future<void> _saveChanges() async {

    final sourceId = requireAttached();
    final obj = await sourceCollection.get(sourceId);
    final sid = targetCollection.getSid(obj);
    final entriesAdd = addedObjects
        .map((obj) => NewOperationChange(
            collection: sourceCollection.name,
            field: linkName,
            sid: sid,
            operation: ChangesyncOperations.addLink,
            value: targetCollection.getSid(obj)))
        .toList();

    final entriesRemove = removedObjects
        .map((obj) => NewOperationChange(
            collection: sourceCollection.name,
            field: linkName,
            sid: sid,
            operation: ChangesyncOperations.removeLink,
            value: targetCollection.getSid(obj)))
        .toList();

    await targetCollection._saveNewOperationChange([...entriesAdd, ...entriesRemove]);
    return save();
  }
}

extension IsarLinksChanges<T extends ChangesyncBaseObject> on IsarLinks<T> {
  Future<void> saveChanges() {
    final aa = this;
    
    if (aa is IsarLinksCommon<T>) {
      return aa._saveChanges();
    }
    return save();
  }
}
extension CollectionSchemaSid<T> on CollectionSchema<T> {
  get sidName => 'sid';
}
extension IsarCollectionChanges<T extends ChangesyncBaseObject> on IsarCollection<T> {
  String getSid(obj) => obj.sid;
  Map<String, dynamic> toJson(T obj) =>
      jsonDecode(jsonEncode(obj)) as Map<String, dynamic>;

  Map<String, dynamic> difference(
      Map<String, dynamic> older, Map<String, dynamic> newer) {
    final diff = Map<String, dynamic>.from(newer);
    older.forEach((key, value) {
      if (newer[key] == value) {
        diff.remove(key);
      }
    });
    return diff;
  }

  List<NewOperationChange> _getInsertEntries(List<String> ids) =>
      ids.map((id) => NewOperationChange.insert(collection: schema.name, sid: id)).toList();

  Iterable<NewOperationChange> _getEditEntriesMap(
          String id, Map<String, dynamic> json) =>
      json.keys
          .where((key) => json[key] != null)
          .where((key) => key != "id")
          .where((key) => key != "sid")
          .map((key) => NewOperationChange.edit(
              collection: schema.name, sid: id, field: key, value: json[key]));

  Iterable<NewOperationChange> _getEditEntries(T object) {
    final objId = getSid(object);
    try {
      final json = toJson(object);
      return _getEditEntriesMap(objId, json);
    } catch (e) {
      print(e);
      print('implement toJson: $object');
    }
    return <NewOperationChange>[];
  }

  Future<bool> deleteChanges(int id) async {
    final deleted = await deleteAllChanges([id]);
    return deleted == 1;
  }

  Future<int> deleteAllChanges(List<int> ids) async {
    final objs = await getAll(ids);
    final deletedEntries = objs
        .map((obj) => NewOperationChange.delete(collection: schema.name, sid: getSid(obj)))
        .toList();

    await _saveNewOperationChange(deletedEntries);

    return deleteAll(ids);
  }

  Future<int> putChanges(T object) async {
    return (await putAllChanges([object])).first;
  }

  Future<List<int>> putAllChanges(List<T> elements) async {
    for (final element in elements) {
      if (element.sid.isEmpty) {
        element.sid = SidUtils.random();
      }
    }
    final elementsMatch =
        elements.splitMatch((e) => schema.getId(e) == Isar.autoIncrement);
    final newElements = elementsMatch.matched;
    await putAll(newElements);
    final newSids = newElements.map(getSid).toList();

    final insertEntries = _getInsertEntries(newSids);
    final newEditEntries =
        newElements.map((e) => _getEditEntries(e)).expand((element) => element).toList();

    final updateElements = elementsMatch.unmatched;
    final elementsFound = await filter().anyOf(updateElements, (q, T id) {
      return q.idEqualTo(schema.getId(id));
    }).exportJson();

    final updatedElementJsons = updateElements.map((e) => toJson(e));
    final oldEditEntries = updatedElementJsons.map((toUpdate) {
      schema.idName;
      final id = toUpdate[schema.sidName] as String;
      final found = elementsFound.firstWhere(
          (element) => element[schema.idName] == toUpdate[schema.idName]);

      return _getEditEntriesMap(id, difference(found, toUpdate));
    }).expand((element) => element).toList();

    final allEntries = [...insertEntries, ...newEditEntries, ...oldEditEntries];
    await _saveNewOperationChange(allEntries);
    putAll(updateElements);
    return elements.map((e) => schema.getId(e)).toList();
  }

  Future<void> _saveNewOperationChange(List<NewOperationChange> changes) async {
    for (var processor in _isarProcessors) {
      await processor.saveChanges(changes);
    }
  }
}

extension AllQueryFilter<T> on QueryBuilder<T, T, QFilterCondition> {
  QueryBuilder<T, T, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }
}

extension SplitMatch<T> on Iterable<T> {
  ListMatch<T> splitMatch(bool Function(T element) matchFunction) {
    final listMatch = ListMatch<T>();

    for (final element in this) {
      if (matchFunction(element)) {
        listMatch.matched.add(element);
      } else {
        listMatch.unmatched.add(element);
      }
    }

    return listMatch;
  }
}

class ListMatch<T> {
  List<T> matched = <T>[];
  List<T> unmatched = <T>[];
}
