import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandIcon extends StatelessWidget {
  final String asset;
  final double size;
  final IconData fallback;

  const BrandIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.fallback = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => Icon(fallback, size: size),
    );
  }
}
