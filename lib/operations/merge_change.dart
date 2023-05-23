import '../utils/hlc.dart';
import 'new_change.dart';

class MergableChange {
  final Hlc hlc;
  final NewOperationChange change;

  const MergableChange({
    required this.change,
    required this.hlc,
  });
}
