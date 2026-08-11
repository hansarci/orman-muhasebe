import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../screens/is_detay_screen.dart';

/// Sağ alttaki yeşil + butonuyla açılan, sadeleştirilmiş yeni iş paneli.
/// HTML mockup'ta kararlaştırılan yeni tasarım: sabit "YENİ İŞ OLUŞTUR"
/// başlığı, altında iş adı kutusu, altında tek "İşi Başlat" butonu.
/// İşletme/tutar/fiş fotoğrafı burada YOK — "İşi Başlat"a basınca boş
/// bir iş açılıyor ve direkt o işin detay sayfasına geçiliyor.
Future<void> yeniIsModalAc(
  BuildContext context, {
  required FirestoreService firestoreService,
  required PhotoUploadService photoUploadService,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _YeniIsPaneli(
      firestoreService: firestoreService,
      photoUploadService: photoUploadService,
    ),
  );
}

class _YeniIsPaneli extends StatefulWidget {
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;

  const _YeniIsPaneli({
    required this.firestoreService,
    required this.photoUploadService,
  });

  @override
  State<_YeniIsPaneli> createState() => _YeniIsPaneliState();
}

class _YeniIsPaneliState extends State<_YeniIsPaneli> {
  final _isAdiController = TextEditingController();
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _isAdiController.dispose();
    super.dispose();
  }

  Future<void> _isiBaslat() async {
    final isAdi = _isAdiController.text.trim();
    if (isAdi.isEmpty) return;

    setState(() => _kaydediliyor = true);

    try {
      final isId = await widget.firestoreService.bosIsOlustur(isAdi: isAdi);

      if (!mounted) return;
      Navigator.of(context).pop(); // Paneli kapat.

      // Yeni açılan boş işin detayına direkt geç.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IsDetayScreen(
            isId: isId,
            firestoreService: widget.firestoreService,
            photoUploadService: widget.photoUploadService,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          color: AppColors.zemin,
          border: Border(top: BorderSide(color: AppColors.turuncu, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'YENİ İŞ OLUŞTUR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    letterSpacing: 0.5,
                    color: AppColors.yazi,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.yaziSoluk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _isAdiController,
              autofocus: true,
              style: const TextStyle(color: AppColors.yazi),
              decoration: const InputDecoration(hintText: 'İş Adı'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _kaydediliyor ? null : _isiBaslat,
              style: AppTheme.anaButonStili(),
              child: _kaydediliyor
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('İşi Başlat', style: AppTheme.anaButonYazi()),
                        const SizedBox(width: 10),
                        const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
