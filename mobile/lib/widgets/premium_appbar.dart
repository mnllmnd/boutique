import 'package:flutter/material.dart';

/// 🎨 AppBar Premium avec gradient et des effets subtils
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onLeadingPressed;
  final bool showDivider;
  final Color? backgroundColor;
  final bool hasSearchBar;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const PremiumAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.onLeadingPressed,
    this.showDivider = true,
    this.backgroundColor,
    this.hasSearchBar = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        hasSearchBar ? 140 : 70,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor ?? (isDark ? const Color(0xFF0F0F12) : Colors.white),
            backgroundColor ?? (isDark ? const Color(0xFF1A1A1E) : const Color(0xFFFAFAFA)),
          ],
        ),
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(isDark ? 0.08 : 0.1),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Leading
                  if (leading != null)
                    GestureDetector(
                      onTap: onLeadingPressed,
                      child: leading!,
                    )
                  else if (onLeadingPressed != null)
                    GestureDetector(
                      onTap: onLeadingPressed,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),

                  // Titre et sous-titre
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white54 : Colors.black54,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  if (actions != null && actions!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...actions!.asMap().entries.map((e) {
                          if (e.key > 0) {
                            return const SizedBox(width: 12);
                          }
                          return e.value;
                        }),
                      ],
                    ),
                ],
              ),
            ),

            // Barre de recherche (optionnelle)
            if (hasSearchBar && searchController != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildSearchBar(context, isDark),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.1 : 0.08),
          width: 1,
        ),
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white38 : Colors.black38,
            size: 20,
          ),
          suffixIcon: searchController!.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    searchController!.clear();
                    onSearchClear?.call();
                  },
                  child: Icon(
                    Icons.clear_rounded,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

/// 🎨 Widget pour les stats affichées dans le header
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              if (isLoading)
                SizedBox(
                  width: 40,
                  height: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color.withOpacity(0.5),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
