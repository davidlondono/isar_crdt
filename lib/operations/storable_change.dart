import '../models/base_model.dart';
import '../utils/hlc.dart';
import 'new_change.dart';

class StorableChange {
  const StorableChange({
    required this.change,
    required this.hlc,
    required this.modified,
  });
  final Hlc modified;
  final Hlc hlc;
  final NewOperationChange change;

  static StorableChange fromOperationChange<BM extends CrdtBaseModel>({
    required BM change,
  }) =>
      StorableChange(
        change: change.toOperationChange(),
        hlc: Hlc.parse(change.hlc),
        modified: Hlc.parse(change.modified),
      );

  Map<String, dynamic> toJson() => {
        ...change.toJson(),
        'hlc': hlc.toString(),
        'modified': modified.toString(),
      };
}
