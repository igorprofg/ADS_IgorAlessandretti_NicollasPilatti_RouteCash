import 'package:flutter/material.dart';

class PlatformIcon extends StatelessWidget {
  final String platformName;
  final double size;

  const PlatformIcon({super.key, required this.platformName, this.size = 40});

  String? _assetForPlatform() {
    final nome = platformName.trim().toLowerCase();

    switch (nome) {
      case 'uber':
        return 'assets/platforms/uber.png';

      case '99':
        return 'assets/platforms/99.png';

      case 'indrive':
      case 'in drive':
        return 'assets/platforms/indrive.png';

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetForPlatform();

    if (asset != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Image.asset(asset, fit: BoxFit.contain),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_car_outlined,
        size: size * 0.55,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
