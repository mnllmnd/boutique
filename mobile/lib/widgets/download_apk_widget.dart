import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadAPKWidget extends StatefulWidget {
  const DownloadAPKWidget({super.key});

  @override
  State<DownloadAPKWidget> createState() => _DownloadAPKWidgetState();
}

class _DownloadAPKWidgetState extends State<DownloadAPKWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _downloadAPK() async {
    setState(() => _isDownloading = true);

    try {
      final url = Uri.parse(
        'https://boutique-mocha.vercel.app/downloads/boutique-mobile.apk',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F1113),
            const Color(0xFF1A1D20),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo avec animation
          ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
            ),
            child: SizedBox(
              width: 120,
              height: 120,
              child: SvgPicture.asset(
                'assets/logo.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'BOUTIQUE Mobile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Text(
            'Gestion de Dettes & Crédits',
            style: TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Download button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isDownloading ? null : _downloadAPK,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                        strokeWidth: 2,
                      ),
                    )
                  else
                    const Icon(Icons.download_rounded, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _isDownloading ? 'Téléchargement...' : 'Télécharger l\'APK',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  color: Color(0xFF7C3AED),
                  size: 18,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Version: 1.0.0\nTaille: ~50 MB',
                    style: TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
