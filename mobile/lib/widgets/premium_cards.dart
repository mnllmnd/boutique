import 'package:flutter/material.dart';
import 'premium_components.dart';
import 'premium_styles.dart';

/// 🎨 Carte de dette premium avec tous les composants
class PremiumDebtCard extends StatelessWidget {
  final Map debt;
  final String clientName;
  final String? clientPhone;
  final VoidCallback onTap;
  final VoidCallback? onAddPayment;
  final VoidCallback? onAddAddition;
  final bool showPhone;

  const PremiumDebtCard({
    super.key,
    required this.debt,
    required this.clientName,
    this.clientPhone,
    required this.onTap,
    this.onAddPayment,
    this.onAddAddition,
    this.showPhone = true,
  });

  bool get isDebtPaid {
    final remaining = (debt['remaining'] as double?) ?? 0.0;
    return remaining <= 0;
  }

  double get progressValue {
    final amount = (debt['amount'] as num?)?.toDouble() ?? 1.0;
    final remaining = (debt['remaining'] as num?)?.toDouble() ?? 0.0;
    final paid = amount - remaining;
    return (paid / amount).clamp(0.0, 1.0);
  }

  String get statusLabel {
    if (isDebtPaid) return 'Complètement payé';
    final remaining = (debt['remaining'] as double?) ?? 0.0;
    if (remaining > 0) return 'En attente de paiement';
    return 'Remboursé';
  }

  Color get statusColor {
    if (isDebtPaid) return const Color(0xFF2DB89A);
    return const Color(0xFFF77F00);
  }

  Color get statusColorBg {
    if (isDebtPaid) return const Color(0xFF2DB89A);
    return const Color(0xFFF77F00);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec nom et badge statut
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: PremiumTextStyles.headingM(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showPhone && clientPhone != null && clientPhone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        clientPhone!,
                        style: PremiumTextStyles.captionL(context),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PremiumBadge(
                label: statusLabel,
                backgroundColor: statusColorBg,
                icon: isDebtPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
              ),
            ],
          ),

          const SizedBox(height: 16),
          PremiumDivider(padding: EdgeInsets.zero),
          const SizedBox(height: 16),

          // Montant et progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: PremiumTextStyles.captionL(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(debt['amount'] as num?)?.toStringAsFixed(0) ?? '0'} F',
                    style: PremiumTextStyles.displayL(context),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Restant',
                    style: PremiumTextStyles.captionL(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(debt['remaining'] as num?)?.toStringAsFixed(0) ?? '0'} F',
                    style: PremiumTextStyles.bodyL(context).copyWith(
                      color: isDebtPaid ? const Color(0xFF2DB89A) : const Color(0xFFF77F00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barre de progression
          AnimatedProgressBar(
            progress: progressValue,
            color: isDebtPaid ? const Color(0xFF2DB89A) : const Color(0xFF7C3AED),
            height: 6,
          ),

          const SizedBox(height: 12),

          // Texte de progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progressValue * 100).toStringAsFixed(0)}% payé',
                style: PremiumTextStyles.captionS(context),
              ),
              if (!isDebtPaid)
                Text(
                  '${((1 - progressValue) * 100).toStringAsFixed(0)}% restant',
                  style: PremiumTextStyles.captionS(context),
                ),
            ],
          ),

          const SizedBox(height: 16),
          PremiumDivider(padding: EdgeInsets.zero),
          const SizedBox(height: 16),

          // Boutons d'action
          if (onAddPayment != null || onAddAddition != null)
            Row(
              children: [
                if (onAddPayment != null) ...[
                  Expanded(
                    child: _buildActionButton(
                      label: 'Paiement',
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFF2DB89A),
                      onTap: onAddPayment!,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onAddAddition != null) ...[
                  Expanded(
                    child: _buildActionButton(
                      label: 'Ajouter',
                      icon: Icons.add_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: onAddAddition!,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎨 Carte client premium
class PremiumClientCard extends StatelessWidget {
  final Map client;
  final double totalRemaining;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PremiumClientCard({
    super.key,
    required this.client,
    required this.totalRemaining,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  Color _getAvatarColor() {
    final name = client['name'] ?? 'Client';
    final hash = name.hashCode;
    const colors = [
      Color(0xFF6B5B95),
      Color(0xFF88A86C),
      Color(0xFF9B8B7E),
      Color(0xFF7B9DBE),
      Color(0xFFA69B84),
      Color(0xFF8B7F9A),
      Color(0xFF7F9F9D),
      Color(0xFF9B8B70),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials() {
    final name = client['name'] ?? 'C';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return 'C';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = _getAvatarColor();
    final initials = _getInitials();

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withOpacity(0.15),
              border: Border.all(
                color: avatarColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: avatarColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client['name'] ?? 'Client',
                  style: PremiumTextStyles.headingS(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  totalRemaining > 0
                      ? '${totalRemaining.toStringAsFixed(0)} F à percevoir'
                      : 'Solde zéro',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: totalRemaining > 0
                        ? const Color(0xFF2DB89A)
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          // Menu actions
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (ctx) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}

/// 🎨 Section de statut premium
class PremiumStatusSection extends StatelessWidget {
  final String title;
  final List<StatItem> items;
  final Color accentColor;

  const PremiumStatusSection({
    super.key,
    required this.title,
    required this.items,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: PremiumTextStyles.headingM(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((e) {
          if (e.key > 0) {
            return Column(
              children: [
                const SizedBox(height: 8),
                _buildStatItem(context, e.value),
              ],
            );
          }
          return _buildStatItem(context, e.value);
        }),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, StatItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          item.label,
          style: PremiumTextStyles.bodyM(context),
        ),
        Text(
          item.value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: item.color,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class StatItem {
  final String label;
  final String value;
  final Color color;

  StatItem({
    required this.label,
    required this.value,
    this.color = const Color(0xFF7C3AED),
  });
}
