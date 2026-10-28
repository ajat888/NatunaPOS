import 'package:flutter/widgets.dart';
class MainMenuScope extends InheritedWidget {
  final VoidCallback openMenu;

  const MainMenuScope({
    super.key,
    required this.openMenu,
    required super.child,
  });

  static MainMenuScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainMenuScope>();

  @override
  bool updateShouldNotify(MainMenuScope oldWidget) => false;
}