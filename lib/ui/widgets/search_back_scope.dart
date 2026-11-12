import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/search_helper.dart';

/// Makes system Back (Android) close the search field instead of leaving the app. The search
/// field replaces the app-bar title without pushing a route, so with nothing to pop Back would
/// exit. While searching, [canPop] is false and Back calls `setSearchStatus(false)`.
class SearchBackScope extends StatelessWidget {
  final Widget child;
  const SearchBackScope({super.key, required this.child});

  /// Back may leave the screen only when the search field is not open.
  static bool canPop({required bool searching}) => !searching;

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchHelper>(
      builder: (context, searchHelper, child) => PopScope(
        canPop: canPop(searching: SearchHelper.calculatingSearchResults),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && SearchHelper.calculatingSearchResults) {
            searchHelper.setSearchStatus(false);
          }
        },
        child: child!,
      ),
      child: child,
    );
  }
}
