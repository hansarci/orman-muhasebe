import 'dart:io';
import 'package:flutter/material.dart';
import '../models/isletme_model.dart';
import '../models/kayit_model.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fis_foto_secici.dart';
import '../widgets/fis_lightbox.dart';
import '../widgets/ortak_widgetlar.dart';

/// Bir işletmenin (ör. "Motorcu") o iş kapsamındaki tüm borç geçmişini
/// gösteren ve yeni borç eklemeyi sağlayan en alt seviye ekran. Header'da
/// hep üstteki iş adı sabit kalır (kullanıcı kararı) — bu ekran sadece
/// işletme adını gövdede başlık olarak gösterir.
class IsletmeDetayScreen extends StatefulWidget {
  final String isId;
  final String isletmeId;
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;

  const IsletmeDetayScreen({
    super.key,
    required this.isId,
    required this.isletmeId,
    required this.firestoreService,
    required this.photoUploadService,
  });

  @override
  State<IsletmeDetayScreen> createState() => _IsletmeDetayScreenState();
}

class _IsletmeDetayScreenState extends State<IsletmeDetayScreen> {
  final _tutarController = TextEditingController();
  File? _secilenFoto;
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _tutarController.dispose();
    super.dispose();
  }

  Future<void> _borcEkle() async {
    final tutar = double.tryParse(_tutarController.text.trim());
    if (tutar == null || tutar <= 0) return;

    setState(() => _kaydediliyor = true);
    try {
      final kimlikler = await widget.firestoreService.borcEkle(
        isId: widget.isId,
        isletmeId: widget.isletmeId,
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

      _tutarController.clear();
      setState(() => _secilenFoto = null);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IsletmeModel>>(
      stream: widget.firestoreService.isletmelerStream(widget.isId),
      builder: (context, isletmeListSnap) {
        final eslesenler = (isletmeListSnap.data ?? [])
            .where((e) => e.id == widget.isletmeId);
        final isletme = eslesenler.isEmpty ? null : eslesenler.first;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.turuncu),
                        ),
                        child: const Text('← Geri'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isletme?.isim.toUpperCase() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: AppColors.yazi,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToplamSatiri(etiket: 'Toplam borç', tutar: isletme?.toplam ?? 0),
                  TextField(
                    controller: _tutarController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Borç Tutarı'),
                  ),
                  const SizedBox(height: 16),
                  FisFotoSecici(
                    onSecildi: (dosya) => _secilenFoto = dosya,
                    anaButon: OutlinedButton(
                      onPressed: _kaydediliyor ? null : _borcEkle,
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
                                Text('Borç ekle', style: AppTheme.anaButonYazi()),
                                const SizedBox(width: 10),
                                const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'GEÇMİŞ KAYITLAR',
                    style: TextStyle(fontSize: 12, letterSpacing: 1, color: AppColors.yaziSoluk),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<KayitModel>>(
                      stream: widget.firestoreService.kayitlarStream(widget.isId, widget.isletmeId),
                      builder: (context, snapshot) {
                        final kayitlar = snapshot.data ?? [];
                        if (kayitlar.isEmpty) {
                          return const Center(
                            child: Text('Henüz kayıt yok.', style: TextStyle(color: AppColors.yaziSoluk)),
                          );
                        }
                        return ListView.builder(
                          itemCount: kayitlar.length,
                          itemBuilder: (context, index) {
                            final kayit = kayitlar[index];
                            return GecmisKayitSatiri(
                              tarih: kayit.tarih,
                              tutar: kayit.tutar,
                              fotoUrl: kayit.fotoUrl,
                              fotoBekliyor: kayit.fotoBekliyor,
                              onFotoTikla: kayit.fotoUrl == null
                                  ? null
                                  : () => fisiBuyukGoster(context, kayit.fotoUrl!),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
