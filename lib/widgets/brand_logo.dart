import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandLogo extends StatelessWidget {
  final double width;
  final double? height;
  final bool full;

  const BrandLogo({super.key, this.width = 84, this.height, this.full = false});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      full ? 'assets/brand/logo-full.svg' : 'assets/brand/logo-mark.svg',
      width: width,
      height: height ?? width,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Icon(Icons.groups_2, size: width),
    );
  }
}
