import 'package:flutter/material.dart';

/// Root navigator — clear pushed routes (login/profile) on auth change.
final GlobalKey<NavigatorState> sanchivaNavKey = GlobalKey<NavigatorState>();

/// Pop until AppGate home so login/logout UI updates without pressing Back.
void clearNavStack() {
  final nav = sanchivaNavKey.currentState;
  if (nav == null) return;
  nav.popUntil((route) => route.isFirst);
}
