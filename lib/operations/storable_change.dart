import '../models/base_model.dart';
import '../utils/hlc.dart';
import 'new_change.dart';

class StorableChange {
  final Hlc modified;
  final Hlc hlc;
  final NewOperationChange change;
  const StorableChange({
    required this.change,
    required this.hlc,
    required this.modified,
  });

  static StorableChange fromOperationChange<BM extends CrdtBaseModel>({
    required BM change,
  }) {
    return StorableChange(
      change: change.toOperationChange(),
      hlc: Hlc.parse(change.hlc),
      modified: Hlc.parse(change.modified),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...change.toJson(),
      "hlc": hlc.toString(),
      "modified": modified.toString(),
    };
  }
}
