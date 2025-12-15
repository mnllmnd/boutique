import 'package:flutter/material.dart';

/// Widget pour afficher le logo Boutique (lotus)
class BoutiqueLogo extends StatelessWidget {
  final double size;

  const BoutiqueLogo({
    super.key,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/logo.jpeg',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Affiche le logo avec un texte "Boutique" dessous
class BoutiqueLogoWithText extends StatelessWidget {
  final double logoSize;
  final double textSize;
  final bool showText;

  const BoutiqueLogoWithText({
    super.key,
    this.logoSize = 100,
    this.textSize = 28,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BoutiqueLogo(size: logoSize),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'Boutique',
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Logo pour la barre de navigation / header
class LogoSmall extends StatelessWidget {
  final VoidCallback? onTap;

  const LogoSmall({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final widget = SizedBox(
      width: 40,
      height: 40,
      child: Image.asset(
        'assets/logo.jpeg',
        fit: BoxFit.contain,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }
}

