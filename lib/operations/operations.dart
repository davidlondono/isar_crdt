enum CrdtOperations {
  insert('insert'),
  update('update'),
  delete('delete'),
  addLink('addLink'),
  removeLink('removeLink');

  const CrdtOperations(this.value);
  final String value;

  factory CrdtOperations.fromString(String value) {
    return CrdtOperations.values
        .firstWhere((element) => element.value == value);
  }
}
