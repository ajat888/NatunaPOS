import 'package:flutter/material.dart';

class LandscapeWrapper extends StatelessWidget {
  final Widget child;

  const LandscapeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isPortrait = mediaQuery.orientation == Orientation.portrait;

    // Jika layar vertikal (seperti di browser HP), paksa putar 90 derajat
    if (isPortrait) {
      return RotatedBox(
        quarterTurns: 1,
        child: MediaQuery(
          // Menukar nilai lebar dan tinggi agar widget di dalamnya merasa sedang di landscape
          data: mediaQuery.copyWith(
            size: Size(mediaQuery.size.height, mediaQuery.size.width),
          ),
          child: child,
        ),
      );
    }
    
    // Jika sudah horizontal (seperti di Android APK), tampilkan normal
    return child;
  }
}