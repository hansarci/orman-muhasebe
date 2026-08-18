import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/isletme_model.dart';
import '../models/kayit_model.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fis_lightbox.dart';
import '../widgets/ortak_widgetlar.dart';

/// Bir işletmenin (ör. "Motorcu") o iş kapsamındaki tüm borç geçmişini
/// gösteren ekran. Fiş fotoğrafı EKLEMEK opsiyonel: kamera butonuna
/// basılmazsa Storage'a hiç istek gitmez.
///
/// Geçmiş kayıtlar listesinde bir satıra UZUN BASINCA "Düzenle" ve "Sil"
/// seçenekleri beliriyor (HTML mockup'ta kararlaştırılan tasarım).
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

  /// Hangi kaydın "kabarmış" (uzun basılmış) durumda olduğunu tutar.
  /// Boş bir yere dokununca null'a döner, satır eski haline iner.
  String? _seciliKayitId;

  /// "Hızlı Filtreleme" dropdown'ından seçilen filtre. null = Tümü.
  String? _seciliFiltre;

  static const _filtreSecenekleri = [
    'Fişli Borçlar',
    'Fişsiz Borçlar',
    'Ödenenler',
    'Ödenmeyenler',
  ];

  List<KayitModel> _filtrele(List<KayitModel> kayitlar) {
    switch (_seciliFiltre) {
      case 'Fişli Borçlar':
        return kayitlar.where((k) => !k.odemeMi && k.fotoUrl != null).toList();
      case 'Fişsiz Borçlar':
        return kayitlar.where((k) => !k.odemeMi && k.fotoUrl == null).toList();
      case 'Ödenenler':
        return kayitlar.where((k) => k.odemeMi).toList();
      case 'Ödenmeyenler':
        return kayitlar.where((k) => !k.odemeMi).toList();
      default:
        return kayitlar;
    }
  }

  @override
  void dispose() {
    _tutarController.dispose();
    super.dispose();
  }

  Future<void> _kayitEkle({required bool odemeMi}) async {
    final tutar = double.tryParse(_tutarController.text.trim());
    if (tutar == null || tutar <= 0) return;

    setState(() => _kaydediliyor = true);
    try {
      final KayitKimlikleri kimlikler;
      if (odemeMi) {
        kimlikler = await widget.firestoreService.odemeEkle(
          isId: widget.isId,
          isletmeId: widget.isletmeId,
          tutar: tutar,
        );
      } else {
        kimlikler = await widget.firestoreService.borcEkle(
          isId: widget.isId,
          isletmeId: widget.isletmeId,
          tutar: tutar,
          yerelFotoYolu: _secilenFoto?.path,
        );
      }

      if (!odemeMi && _secilenFoto != null) {
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
        final eslesenler =
            (isletmeListSnap.data ?? []).where((e) => e.id == widget.isletmeId);
        final isletme = eslesenler.isEmpty ? null : eslesenler.first;

        return Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_seciliKayitId != null) setState(() => _seciliKayitId = null);
            },
            child: SafeArea(
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
                    turkceBuyukHarf(isletme?.isim ?? ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: AppColors.yazi,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToplamSatiri(etiket: 'Toplam borç', tutar: isletme?.toplam ?? 0),

                  // Tutar kutusu + kamera aynı satırda
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tutarController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: 'Borç Tutarı'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _KameraButonu(
                        secilenFoto: _secilenFoto,
                        onSecildi: (dosya) => setState(() => _secilenFoto = dosya),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ödeme Yap (solda, yeşil) + Borç ekle (sağda, turuncu) — eşit genişlik
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _kaydediliyor ? null : () => _kayitEkle(odemeMi: true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.panel,
                            side: const BorderSide(color: AppColors.yesilTik, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Ödeme Yap',
                                style: AppTheme.anaButonYazi().copyWith(color: AppColors.yesilTik),
                              ),
                              const SizedBox(width: 8),
                              const Text('✔✔', style: TextStyle(color: AppColors.yesilTik, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _kaydediliyor ? null : () => _kayitEkle(odemeMi: false),
                          style: AppTheme.anaButonStili(),
                          child: _kaydediliyor
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Borç ekle', style: AppTheme.anaButonYazi()),
                                    const SizedBox(width: 8),
                                    const Text('✔✔', style: TextStyle(color: AppColors.yesilTik, fontSize: 13)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cizgi),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _seciliFiltre,
                        isExpanded: true,
                        dropdownColor: AppColors.panel,
                        icon: const Icon(Icons.filter_list, color: AppColors.turuncu, size: 18),
                        hint: const Text(
                          'Hızlı Filtreleme',
                          style: TextStyle(color: AppColors.yaziSoluk, fontSize: 13),
                        ),
                        style: const TextStyle(color: AppColors.yazi, fontSize: 13),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tümü', style: TextStyle(color: AppColors.yaziSoluk)),
                          ),
                          ..._filtreSecenekleri.map(
                            (secenek) => DropdownMenuItem<String?>(
                              value: secenek,
                              child: Text(secenek),
                            ),
                          ),
                        ],
                        onChanged: (yeniDeger) => setState(() => _seciliFiltre = yeniDeger),
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
                        final kayitlar = _filtrele(snapshot.data ?? []);
                        if (kayitlar.isEmpty) {
                          return Center(
                            child: Text(
                              _seciliFiltre == null
                                  ? 'Henüz kayıt yok.'
                                  : 'Bu filtreye uygun kayıt yok.',
                              style: const TextStyle(color: AppColors.yaziSoluk),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: kayitlar.length,
                          itemBuilder: (context, index) {
                            final kayit = kayitlar[index];
                            return _DuzenlenebilirKayitSatiri(
                              kayit: kayit,
                              secili: _seciliKayitId == kayit.id,
                              onUzunBas: () => setState(() => _seciliKayitId = kayit.id),
                              onFotoTikla: kayit.fotoUrl == null
                                  ? null
                                  : () => fisiBuyukGoster(context, kayit.fotoUrl!),
                              onDuzenle: (yeniTutar) async {
                                await widget.firestoreService.kayitDuzenle(
                                  isId: widget.isId,
                                  isletmeId: widget.isletmeId,
                                  kayitId: kayit.id,
                                  eskiTutar: kayit.tutar,
                                  yeniTutar: yeniTutar,
                                  tur: kayit.tur,
                                );
                                setState(() => _seciliKayitId = null);
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
          ),
          ),
        );
      },
    );
  }
}

/// Kamera butonu — metalik gri kenarlık, seçilen fotoğrafı küçük bir
/// önizleme olarak butonun üstünde gösterir.
class _KameraButonu extends StatefulWidget {
  final File? secilenFoto;
  final ValueChanged<File?> onSecildi;

  const _KameraButonu({required this.secilenFoto, required this.onSecildi});

  @override
  State<_KameraButonu> createState() => _KameraButonuState();
}

class _KameraButonuState extends State<_KameraButonu> {
  Future<void> _fotoSecMenusunuAc() async {
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
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (sonuc != null) widget.onSecildi(File(sonuc.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.secilenFoto != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(Icons.check_circle, color: AppColors.yesilTik, size: 20),
          ),
        SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            onPressed: _fotoSecMenusunuAc,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2E31),
              side: const BorderSide(color: Color(0xFF9AA0A6), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: EdgeInsets.zero,
            ),
            child: const Text('📷', style: TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}

/// Geçmiş kayıtlar listesindeki tek satır. Uzun basınca hafif "kabarır"
/// ve "Düzenle" / "Sil" butonları belirir.
class _DuzenlenebilirKayitSatiri extends StatefulWidget {
  final KayitModel kayit;
  final bool secili;
  final VoidCallback onUzunBas;
  final VoidCallback? onFotoTikla;
  final ValueChanged<double> onDuzenle;

  const _DuzenlenebilirKayitSatiri({
    required this.kayit,
    required this.secili,
    required this.onUzunBas,
    required this.onFotoTikla,
    required this.onDuzenle,
  });

  @override
  State<_DuzenlenebilirKayitSatiri> createState() => _DuzenlenebilirKayitSatiriState();
}

class _DuzenlenebilirKayitSatiriState extends State<_DuzenlenebilirKayitSatiri> {
  bool _duzenleniyor = false;
  late TextEditingController _duzenleController;

  @override
  void initState() {
    super.initState();
    _duzenleController = TextEditingController(text: widget.kayit.tutar.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _duzenleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_duzenleniyor) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.turuncu),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _duzenleController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.yazi, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check, color: AppColors.yesilTik, size: 20),
              onPressed: () {
                final yeni = double.tryParse(_duzenleController.text.trim());
                if (yeni != null && yeni > 0) widget.onDuzenle(yeni);
                setState(() => _duzenleniyor = false);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.turuncu, size: 20),
              onPressed: () => setState(() => _duzenleniyor = false),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: widget.onUzunBas,
      onTap: () {}, // Boş dokunuşu "yutar" — üstteki ekran genelindeki
      // GestureDetector'a ulaşmasını engeller, böylece satırın kendisine
      // dokunmak seçimi KAPATMAZ (sadece dışarıya dokunmak kapatır).
      child: AnimatedScale(
        scale: widget.secili ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.secili
                  ? AppColors.turuncu
                  : (widget.kayit.odemeMi
                      ? const Color(0x334CAF6D)
                      : const Color(0x33D9611E)),
            ),
            boxShadow: widget.secili
                ? [const BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (widget.kayit.fotoUrl != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.receipt_long, color: AppColors.yesilTik, size: 18),
                      ),
                    ],
                    Text(tarihFormatla(widget.kayit.tarih), style: const TextStyle(fontSize: 13.5, color: AppColors.yazi)),
                    if (widget.kayit.odemeMi) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x264CAF6D),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ÖDEME',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.yesilTik),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: widget.kayit.odemeMi ? AppColors.yesilTik : AppColors.turuncu,
                      ),
                      children: [
                        TextSpan(text: widget.kayit.odemeMi ? '− ' : ''),
                        TextSpan(text: paraFormatla(widget.kayit.tutar)),
                        const TextSpan(text: ' ₺', style: TextStyle(color: AppColors.yesilTik)),
                      ],
                    ),
                  ),
                  if (widget.secili) ...[
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.turuncu.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() => _duzenleniyor = true),
                        child: const Text('Tutar Düzenle', style: TextStyle(fontSize: 12, color: AppColors.turuncu)),
                      ),
                    ),
                    if (widget.kayit.fotoUrl != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.yesilTik.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: widget.onFotoTikla,
                          child: const Text('Fişi Gör', style: TextStyle(fontSize: 12, color: AppColors.yesilTik)),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
