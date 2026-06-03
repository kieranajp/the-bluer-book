import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently selected bottom-nav tab index. Lifted out of AppShell so any
/// widget in the tree can hop to a different tab (e.g. "view meal plan"
/// from the home carousel).
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);
