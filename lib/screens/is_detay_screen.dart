import 'dart:io';
import 'package:flutter/material.dart';
import '../models/is_model.dart';
import '../models/isletme_model.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fis_foto_secici.dart';
import '../widgets/ortak_widgetlar.dart';
import 'isletme_detay_screen.dart';

/// Bir işin (ör. "Ballıdağ") içindeki işletmeleri listeleyen ve yeni bir
/// işletme+tutar kaydı eklemeyi sağlayan ekran. Header'da hep iş adı
/// sabit durur — alttaki gövdede tekrar yazılmaz.
///
/// Fiş fotoğrafı EKLEMEK opsiyonel: kamera butonuna basılmazsa hiçbir
/// Storage işlemi tetiklenmez, kayıt fotoğrafsız kaydedilir.
class IsDetayScreen extends StatefulWidget {
  final String isId;
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;

  const IsDetayScreen({
    super.key,
    required this.isId,
    required this.firestoreService,
    required this.photoUploadService,
  });

  @override
  State<IsDetayScreen> createState() => _IsDetayScreenState();
}

class _IsDetayScreenState extends State<IsDetayScreen> {
  final _isletmeAdiController = TextEditingController();
  final _tutarController = TextEditingController();
  File? _secilenFoto;
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _isletmeAdiController.dispose();
    _tutarController.dispose();
    super.dispose();
  }

  Future<void> _masrafEkle() async {
    final isletmeAdi = _isletmeAdiController.text.trim();
    final tutar = double.tryParse(_tutarController.text.trim());
    if (isletmeAdi.isEmpty || tutar == null || tutar <= 0) return;

    setState(() => _kaydediliyor = true);
    try {
      final kimlikler = await widget.firestoreService.isletmeyeKayitEkle(
        isId: widget.isId,
        isletmeAdi: isletmeAdi,
        tutar: tutar,
        yerelFotoYolu: _secilenFoto?.path,
      );

      // Sadece fotoğraf gerçekten seçildiyse Storage'a yükleme dener.
      if (_secilenFoto != null) {
        await widget.photoUploadService.kuyrugaEkle(
          secilenFoto: _secilenFoto!,
          isId: kimlikler.isId,
          isletmeId: kimlikler.isletmeId,
          kayitId: kimlikler.kayitId,
        );
      }

      _isletmeAdiController.clear();
      _tutarController.clear();
      setState(() => _secilenFoto = null);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IsModel>(
      stream: widget.firestoreService.isStream(widget.isId),
      builder: (context, isSnap) {
        final is_ = isSnap.data;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(turkceBuyukHarf(is_?.isim ?? '')),
                const Text(
                  'MASRAF KAYITLARI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: AppColors.yaziSoluk,
                  ),
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToplamSatiri(etiket: 'Toplam masraf', tutar: is_?.toplam ?? 0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _isletmeAdiController,
                        textCapitalization: TextCapitalization.sentences,
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
                  onSecildi: (dosya) => _secilenFoto = dosya,
                  anaButon: OutlinedButton(
                    onPressed: _kaydediliyor ? null : _masrafEkle,
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
                              Text('Masraf ekle', style: AppTheme.anaButonYazi()),
                              const SizedBox(width: 10),
                              const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'İŞLETMELER',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: AppColors.yaziSoluk,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<IsletmeModel>>(
                    stream: widget.firestoreService.isletmelerStream(widget.isId),
                    builder: (context, snapshot) {
                      final isletmeler = snapshot.data ?? [];
                      if (isletmeler.isEmpty) {
                        return const Center(
                          child: Text(
                            'Henüz işletme eklenmedi.',
                            style: TextStyle(color: AppColors.yaziSoluk),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: isletmeler.length,
                        itemBuilder: (context, index) {
                          final isletme = isletmeler[index];
                          return KayitSatiri(
                            isim: isletme.isim,
                            tutar: isletme.toplam,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => IsletmeDetayScreen(
                                    isId: widget.isId,
                                    isletmeId: isletme.id,
                                    firestoreService: widget.firestoreService,
                                    photoUploadService: widget.photoUploadService,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
