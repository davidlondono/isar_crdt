enum CrdtOperations {
  insert('insert'),
  update('update'),
  delete('delete'),
  addLink('addLink'),
  removeLink('removeLink');

  const CrdtOperations(this.value);
  factory CrdtOperations.fromString(String value) =>
      CrdtOperations.values.firstWhere((element) => element.value == value);

  final String value;
}
