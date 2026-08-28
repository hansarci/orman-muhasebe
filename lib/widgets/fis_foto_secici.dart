import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// Kamera/galeri ile fiş fotoğrafı seçme + ana aksiyon butonunu (Masraf
/// ekle vb.) yan yana gösteren ortak widget. Fotoğraf eklemek opsiyonel:
/// kamera butonuna basılmazsa Storage'a hiç istek gitmez.
class FisFotoSecici extends StatefulWidget {
  final ValueChanged<File?> onSecildi;
  final Widget anaButon;

  const FisFotoSecici({
    super.key,
    required this.onSecildi,
    required this.anaButon,
  });

  @override
  State<FisFotoSecici> createState() => FisFotoSeciciState();
}

class FisFotoSeciciState extends State<FisFotoSecici> {
  File? _secilenDosya;

  void temizle() {
    setState(() => _secilenDosya = null);
    widget.onSecildi(null);
  }

  Future<void> _fotoSec() async {
    final secim = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.turuncu),
              title: const Text('Kameradan çek', style: TextStyle(color: AppColors.yazi)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.turuncu),
              title: const Text('Galeriden seç', style: TextStyle(color: AppColors.yazi)),
              subtitle: const Text(
                'Ör. WhatsApp\'tan gelen fiş fotoğrafı',
                style: TextStyle(color: AppColors.yaziSoluk, fontSize: 11.5),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (secim == null) return;

    final secici = ImagePicker();
    final sonuc = await secici.pickImage(
      source: secim,
      imageQuality: 70, // Zayıf sinyalde yükleme boyutunu küçük tutmak için.
      maxWidth: 1600,
    );
    if (sonuc == null) return;
    final dosya = File(sonuc.path);
    setState(() => _secilenDosya = dosya);
    widget.onSecildi(dosya);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_secilenDosya != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cizgi),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.yesilTik, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Fiş seçildi',
                    style: TextStyle(color: AppColors.yazi, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: temizle,
                    child: const Text(
                      '✕ Fişi kaldır',
                      style: TextStyle(color: AppColors.yaziSoluk, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 64,
              child: OutlinedButton(
                onPressed: _fotoSec,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2E31),
                  side: const BorderSide(color: Color(0xFF9AA0A6), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(56, 64),
                ),
                child: const Text('📷', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 64,
                child: widget.anaButon,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
