import 'package:flutter/material.dart';
import '../models/isci_model.dart';
import '../screens/gecmis_kayit_ekle_screen.dart';
import '../services/firestore_service.dart';
import '../services/isci_pdf_service.dart';
import '../theme/app_theme.dart';
import 'ortak_widgetlar.dart';

/// Arşiv ekranının sol üstündeki "İşçiler" ikonuyla açılan yan panel
/// (drawer). Üstte "+ İşçi Ekle" ve "Geçmiş Kayıt Ekle", altında ince bir
/// çizgi, çizginin altında işçi listesi.
class IscilerPaneli extends StatefulWidget {
  final FirestoreService firestoreService;

  const IscilerPaneli({super.key, required this.firestoreService});

  @override
  State<IscilerPaneli> createState() => _IscilerPaneliState();
}

class _IscilerPaneliState extends State<IscilerPaneli> {
  String? _seciliIsciId;
  late final IsciPdfService _pdfService;
  bool _pdfHazirlaniyor = false;

  @override
  void initState() {
    super.initState();
    _pdfService = IsciPdfService(widget.firestoreService);
  }

  Future<void> _isciEklePenceresiniAc() async {
    final isimController = TextEditingController();
    final ucretController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('İşçi Ekle', style: TextStyle(color: AppColors.yazi)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: isimController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.yazi),
              decoration: const InputDecoration(hintText: 'İşçi Adı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ucretController,
              keyboardType: TextInputType.number,
              inputFormatters: [BinlikAyraciFormatter()],
              style: const TextStyle(color: AppColors.yazi),
              decoration: const InputDecoration(hintText: 'Günlük Ücreti'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final isim = isimController.text.trim();
              final ucret = tutarMetniniSayiyaCevir(ucretController.text);
              if (isim.isEmpty || ucret == null || ucret <= 0) return;
              widget.firestoreService.isciEkle(isim: isim, gunlukUcret: ucret);
              Navigator.of(context).pop();
            },
            child: const Text('İşçiyi Ekle', style: TextStyle(color: AppColors.yesilTik)),
          ),
        ],
      ),
    );
  }

  void _gecmisKayitEkraninaGit() {
    Navigator.of(context).pop(); // Paneli kapat.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GecmisKayitEkleScreen(firestoreService: widget.firestoreService),
      ),
    );
  }

  Future<void> _isciGeldiMiSor(IsciModel isci) async {
    final geldi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
        title: Text(isci.isim, style: const TextStyle(color: AppColors.yazi)),
        content: const Text(
          'Bugün işe geldi mi?',
          style: TextStyle(color: AppColors.yaziSoluk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hayır', style: TextStyle(color: AppColors.yaziSoluk)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet', style: TextStyle(color: AppColors.yesilTik)),
          ),
        ],
      ),
    );
    if (geldi == true) {
      widget.firestoreService.isciKayitEkle(
        isciId: isci.id,
        tutar: isci.gunlukUcret,
        tur: 'gelis',
      );
    }
  }

  Future<void> _odemeYapPenceresiniAc(IsciModel isci) async {
    final tutarController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
        title: Text('${isci.isim} — Ödeme Yap', style: const TextStyle(color: AppColors.yazi)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.yaziSoluk, fontSize: 13),
                children: [
                  const TextSpan(text: 'Ödenmemiş kazanç: '),
                  TextSpan(
                    text: '₺${paraFormatla(isci.kazanc)}',
                    style: const TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.w600,
                      color: AppColors.yesilTik,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tutarController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [BinlikAyraciFormatter()],
              style: const TextStyle(color: AppColors.yazi),
              decoration: const InputDecoration(hintText: 'Ödenecek Tutar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final tutar = tutarMetniniSayiyaCevir(tutarController.text);
              if (tutar == null || tutar <= 0) return;
              widget.firestoreService.isciKayitEkle(
                isciId: isci.id,
                tutar: tutar,
                tur: 'odeme',
              );
              Navigator.of(context).pop();
            },
            child: const Text('Ödemeyi Kaydet', style: TextStyle(color: AppColors.yesilTik)),
          ),
        ],
      ),
    );
  }

  Future<void> _pdfGoster(IsciModel isci) async {
    if (_pdfHazirlaniyor) return;
    setState(() {
      _pdfHazirlaniyor = true;
      _seciliIsciId = null;
    });
    try {
      await _pdfService.isciyiPdfOlarakPaylas(isci);

      // Tamamen ödenmiş (kazanç sıfırlanmış) bir işçinin PDF'i
      // gönderildikten sonra, listeden otomatik kaldırılır.
      if (isci.kazanc <= 0) {
        await widget.firestoreService.isciSil(isci.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isci.isim} tamamen ödendi, listeden kaldırıldı.'),
              backgroundColor: AppColors.yesilTik,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfHazirlaniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.zemin,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.turuncu, width: 2),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_seciliIsciId != null) setState(() => _seciliIsciId = null);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: _isciEklePenceresiniAc,
                  style: AppTheme.anaButonStili(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: AppColors.turuncu, size: 18),
                      const SizedBox(width: 6),
                      Text('İşçi Ekle', style: AppTheme.anaButonYazi().copyWith(fontStyle: FontStyle.normal)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton(
                    onPressed: _gecmisKayitEkraninaGit,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.yaziSoluk),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      '🕓 Geçmiş Kayıt Ekle',
                      style: TextStyle(color: AppColors.yaziSoluk, fontSize: 11.5),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Opacity(
                    opacity: 0.4,
                    child: Divider(color: AppColors.cizgi, height: 1),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<IsciModel>>(
                    stream: widget.firestoreService.iscilerStream(),
                    builder: (context, snapshot) {
                      final isciler = snapshot.data ?? [];
                      if (isciler.isEmpty) {
                        return const Center(
                          child: Text(
                            'Henüz işçi eklenmedi.',
                            style: TextStyle(color: AppColors.yaziSoluk, fontSize: 12.5),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: isciler.length,
                        itemBuilder: (context, index) {
                          final isci = isciler[index];
                          return _IsciSatiri(
                            isci: isci,
                            secili: _seciliIsciId == isci.id,
                            pdfHazirlaniyor: _pdfHazirlaniyor && _seciliIsciId == null,
                            onKisaTikla: () => _isciGeldiMiSor(isci),
                            onUzunBas: () => setState(() => _seciliIsciId = isci.id),
                            onOdemeYap: () => _odemeYapPenceresiniAc(isci),
                            onPdfGoster: () => _pdfGoster(isci),
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
  }
}

/// İşçi listesindeki tek satır. Kısa tıklama "işe geldi mi?" sorusunu
/// açar; uzun basınca satır kabarıp "Ödeme Yap" / "PDF Göster" butonları
/// belirir (arşivdeki iş satırlarıyla aynı mantık).
class _IsciSatiri extends StatelessWidget {
  final IsciModel isci;
  final bool secili;
  final bool pdfHazirlaniyor;
  final VoidCallback onKisaTikla;
  final VoidCallback onUzunBas;
  final VoidCallback onOdemeYap;
  final VoidCallback onPdfGoster;

  const _IsciSatiri({
    required this.isci,
    required this.secili,
    required this.pdfHazirlaniyor,
    required this.onKisaTikla,
    required this.onUzunBas,
    required this.onOdemeYap,
    required this.onPdfGoster,
  });

  String _baslangicHarfleri(String isim) {
    final kelimeler =
        isim.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) return '?';
    if (kelimeler.length == 1) return kelimeler[0][0].toUpperCase();
    return (kelimeler[0][0] + kelimeler[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: secili ? () {} : onKisaTikla,
      onLongPress: onUzunBas,
      child: AnimatedScale(
        scale: secili ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.turuncu.withOpacity(0.12))),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.panel,
                  border: Border.all(color: AppColors.turuncu, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _baslangicHarfleri(isci.isim),
                  style: const TextStyle(
                    fontFamily: 'Oswald',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.turuncu,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isci.isim,
                  style: const TextStyle(fontSize: 14, color: AppColors.yazi),
                ),
              ),
              if (!secili)
                Text(
                  '₺${paraFormatla(isci.kazanc)}',
                  style: const TextStyle(
                    fontFamily: 'Oswald',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppColors.yesilTik,
                  ),
                )
              else
                Row(
                  children: [
                    _aksiyonButonu('Ödeme Yap', AppColors.yesilTik, onOdemeYap),
                    const SizedBox(width: 6),
                    pdfHazirlaniyor
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _aksiyonButonu('PDF Göster', AppColors.turuncu, onPdfGoster),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aksiyonButonu(String metin, Color renk, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: renk.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(metin, style: TextStyle(fontSize: 10.5, color: renk)),
      ),
    );
  }
}
