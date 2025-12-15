import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Simple lotus logo in SVG
const String _logoSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 50 20 Q 40 35 40 50 Q 40 65 50 75 Q 60 65 60 50 Q 60 35 50 20" fill="currentColor"/>
  <path d="M 30 40 Q 20 50 20 65 Q 25 75 40 75 Q 45 65 40 50 Q 35 45 30 40" fill="currentColor" opacity="0.8"/>
  <path d="M 70 40 Q 80 50 80 65 Q 75 75 60 75 Q 55 65 60 50 Q 65 45 70 40" fill="currentColor" opacity="0.8"/>
  <circle cx="50" cy="50" r="8" fill="currentColor"/>
</svg>''';

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
      child: SvgPicture.string(
        _logoSvg,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.primary,
          BlendMode.srcIn,
        ),
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
      child: SvgPicture.string(
        _logoSvg,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.primary,
          BlendMode.srcIn,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }
}

