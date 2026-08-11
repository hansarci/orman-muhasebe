import 'dart:io';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import 'fis_foto_secici.dart';

/// Sağ alttaki yeşil + butonuyla açılan, ekranı tam kaplayan yeni iş kaydı
/// paneli. Üstteki alan hem başlık hem de doğrudan yazılabilir iş-adı
/// girişi olarak çalışır (kullanıcının kararlaştırdığı tasarım).
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
  final _isletmeAdiController = TextEditingController();
  final _tutarController = TextEditingController();
  final _fotoKey = GlobalKey<FisFotoSeciciState>();
  File? _secilenFoto;
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _isAdiController.dispose();
    _isletmeAdiController.dispose();
    _tutarController.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final isAdi = _isAdiController.text.trim();
    final isletmeAdi = _isletmeAdiController.text.trim();
    final tutar = double.tryParse(_tutarController.text.trim());

    if (isAdi.isEmpty || isletmeAdi.isEmpty || tutar == null || tutar <= 0) {
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      final kimlikler = await widget.firestoreService.yeniIsOlustur(
        isAdi: isAdi,
        isletmeAdi: isletmeAdi,
        tutar: tutar,
        yerelFotoYolu: _secilenFoto?.path,
      );

      if (_secilenFoto != null) {
        await widget.photoUploadService.kuyrugaEkle(
          secilenFoto: _secilenFoto!,
          isId: kimlikler.isId,
          isletmeId: kimlikler.isletmeId,
          kayitId: kimlikler.kayitId,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Panel ekranın tamamını kaplıyor (sabit yükseklik), kaydırma YOK.
    // Butonlar içerik listesinin en başında (üstte) durduğu için klavye
    // açılsa bile görünür kalıyorlar — alttaki boş alan basitçe klavyenin
    // arkasında kalıyor, önemli değil.
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _isAdiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: AppColors.yazi,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'İŞ ADI',
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.cizgi),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.cizgi),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.turuncu),
                      ),
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.yaziSoluk),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _isletmeAdiController,
                    decoration: const InputDecoration(hintText: 'İşletme Adı'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tutarController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Tutar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FisFotoSecici(
              key: _fotoKey,
              onSecildi: (dosya) => _secilenFoto = dosya,
              anaButon: OutlinedButton(
                onPressed: _kaydediliyor ? null : _kaydet,
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
                          Text('Masraf kaydı oluştur', style: AppTheme.anaButonYazi()),
                          const SizedBox(width: 10),
                          const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
