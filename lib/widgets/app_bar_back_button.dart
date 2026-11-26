import 'package:flutter/material.dart';

Widget? appBarBackButton(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null ||
      !route.impliesAppBarDismissal ||
      (route is PageRoute && route.fullscreenDialog)) {
    return null;
  }
  return IconButton(
    icon: Semantics(
      label: MaterialLocalizations.of(context).backButtonTooltip,
      excludeSemantics: true,
      child: const BackButtonIcon(),
    ),
    onPressed: () => Navigator.maybePop(context),
  );
}
