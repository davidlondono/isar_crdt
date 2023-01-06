import 'dart:convert';
import 'package:meta/meta.dart';

import 'utils/sid.dart' show SidUtils;

import 'package:isar/isar.dart';
// ignore: implementation_imports
import 'package:isar/src/common/isar_links_common.dart' show IsarLinksCommon;

import 'isar_changesync.dart';

final Map<Isar, IsarChangesSync> _isarProcessors = {};



extension IsarC on Isar {
  registerChanges(IsarChangesSync processor) {
    _isarProcessors[this] = processor;
  }
    
  @visibleForTesting
  Iterable<IsarChangesSync> getProcessors() {
    return _isarProcessors.values;
  }

  IsarChangesSync? get processor {
    return _isarProcessors[this];
  }
}

extension IsarLinksImplChanges<T extends ChangesyncBaseObject>
    on IsarLinksCommon<T> {
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

    await targetCollection
        ._saveNewOperationChange([...entriesAdd, ...entriesRemove]);
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

extension IsarCollectionChanges<T extends ChangesyncBaseObject>
    on IsarCollection<T> {
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


  Iterable<NewOperationChange> _getEditEntriesMap(
          String id, Map<String, dynamic> json) =>
      json.keys
          .where((key) => json[key] != null)
          .where((key) => key != "id")
          .where((key) => key != "sid")
          .map((key) => NewOperationChange.edit(
              collection: schema.name, sid: id, field: key, value: json[key]));

  NewOperationChange _getInsertEntry(T object) {
    final objId = getSid(object);
    try {
      final json = toJson(object);
        json.remove(schema.idName);
        json.remove("sid");
      return NewOperationChange.insert(collection: schema.name, sid: objId, value: json);
    } catch (e) {
      throw Exception("object $object needs to implements toJson() to work");
    }
  }

  Future<bool> deleteChanges(int id) async {
    final deleted = await deleteAllChanges([id]);
    return deleted == 1;
  }

  Future<int> deleteAllChanges(List<int> ids) async {
    final objs = await getAll(ids);
    final deletedEntries = objs
        .map((obj) => NewOperationChange.delete(
            collection: name, sid: getSid(obj)))
        .toList();

    await _saveNewOperationChange(deletedEntries);

    return deleteAll(ids);
  }

  Future<int> putChanges(T object) async {
    return (await putAllChanges([object])).first;
  }

  Future<List<int>> putAllChanges(List<T> elements) async {
    if(isar.processor == null) {
      return putAll(elements);
    }
    for (final element in elements) {
      if (element.sid.isEmpty) {
        element.sid = isar.processor!.generateRandomSid();
      }
    }
    final elementsMatch =
        elements.splitMatch((e) => schema.getId(e) == Isar.autoIncrement);
    final newElements = elementsMatch.matched;
    await putAll(newElements);
    final insertEntries = newElements
        .map((e) => _getInsertEntry(e))
        .toList();

    final updateElements = elementsMatch.unmatched;
    final elementsFound = await filter()
    .anyOf(updateElements, (q, T id) {
      return q.idEqualTo(schema.getId(id));
    }).exportJson();

    final updatedElementJsons = updateElements.map((e) => toJson(e));
    final oldEditEntries = updatedElementJsons
        .map((toUpdate) {
          schema.idName;
          final id = toUpdate[schema.sidName] as String;
          final found = elementsFound.firstWhere(
              (element) => element[schema.idName] == toUpdate[schema.idName]);

          return _getEditEntriesMap(id, difference(found, toUpdate));
        })
        .expand((element) => element)
        .toList();

    final allEntries = [...insertEntries, ...oldEditEntries];
    await _saveNewOperationChange(allEntries);
    await putAll(updateElements);
    return elements.map((e) => schema.getId(e)).toList();
  }

  Future<void> _saveNewOperationChange(List<NewOperationChange> changes) async {
    isar.processor?.saveChanges(changes);
  }
}

extension AllQueryFilter<T> on QueryBuilder<T, T, QFilterCondition> {
  QueryBuilder<T, T, QAfterFilterCondition> idEqualTo(Id value) {
    // ignore: invalid_use_of_protected_member
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
