import '../utils/hlc.dart';
import 'new_change.dart';

class MergableChange {

  const MergableChange({
    required this.change,
    required this.hlc,
  });
  final Hlc hlc;
  final NewOperationChange change;
}
