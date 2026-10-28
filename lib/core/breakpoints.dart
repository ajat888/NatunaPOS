// lib/core/breakpoints.dart
import 'package:flutter/widgets.dart';

/// Klasifikasi lebar layar berbasis Material 3 breakpoint.
enum ScreenSize { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();

  static const double mediumMin = 600;
  static const double expandedMin = 900;

  static ScreenSize classify(double width) {
    if (width >= expandedMin) return ScreenSize.expanded;
    if (width >= mediumMin) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static ScreenSize of(BuildContext context) {
    return classify(MediaQuery.sizeOf(context).width);
  }
}

extension ScreenSizeX on ScreenSize {
  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
  bool get isNarrow => this == ScreenSize.compact;
}