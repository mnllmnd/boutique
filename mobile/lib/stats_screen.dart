import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final List debts;
  final List clients;
  final double totalUnpaid;

  const StatsScreen({
    super.key,
    required this.debts,
    required this.clients,
    required this.totalUnpaid,
  });

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = colors.background;
    final textColor = isDark ? Colors.white : Colors.black;
    final textColorSecondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💎 CARTE DE STATISTIQUES PREMIUM
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.08),
                    Colors.orange.withOpacity(0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.15),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stat 1: Total clients
                  _buildStatCard(
                    icon: Icons.people_outline,
                    label: 'CLIENTS',
                    value: clients.length.toString(),
                    color: Colors.orange,
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.orange.withOpacity(0.1),
                  ),
                  // Stat 2: Dettes actives
                  _buildStatCard(
                    icon: Icons.receipt_long,
                    label: 'DETTES',
                    value: debts.length.toString(),
                    color: Colors.orange,
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.orange.withOpacity(0.1),
                  ),
                  // Stat 3: Impayées
                  _buildStatCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'IMPAYÉES',
                    value: totalUnpaid.toStringAsFixed(0),
                    color: totalUnpaid > 0 ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Résumé détaillé',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              label: 'Total clients',
              value: clients.length.toString(),
              icon: Icons.people_outline,
              textColor: textColor,
              textColorSecondary: textColorSecondary,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              label: 'Total dettes',
              value: debts.length.toString(),
              icon: Icons.receipt_long,
              textColor: textColor,
              textColorSecondary: textColorSecondary,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              label: 'Dettes impayées',
              value: totalUnpaid.toStringAsFixed(0),
              icon: Icons.warning_amber_rounded,
              textColor: textColor,
              textColorSecondary: textColorSecondary,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required String label,
    required String value,
    required IconData icon,
    required Color textColor,
    required Color textColorSecondary,
    required bool isDark,
  }) {
    final cardBgColor = isDark ? const Color(0xFF151718) : Colors.grey[100];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
