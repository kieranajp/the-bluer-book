import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently selected bottom-nav tab index. Lifted out of AppShell so any
/// widget in the tree can hop to a different tab (e.g. "view meal plan"
/// from the home carousel).
final selectedTabProvider = StateProvider<int>((ref) => 0);
