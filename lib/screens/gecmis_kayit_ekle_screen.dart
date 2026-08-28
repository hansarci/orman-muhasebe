import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coklu_secim_takvimi.dart';
import '../widgets/ortak_widgetlar.dart';

/// Başka bir yerde tutulan eski işçi kayıtlarını, tarihiyle birlikte
/// uygulamaya aktarmak için kullanılan ekran. İşçi adı serbestçe
/// yazılır — aynı isim zaten varsa ona eklenir, yoksa yeni işçi olarak
/// oluşturulur. Takvimden işaretlenen HER gün için, girilen günlük
/// ücret üzerinden ayrı bir "geldi" kaydı düşülür.
class GecmisKayitEkleScreen extends StatefulWidget {
  final FirestoreService firestoreService;

  const GecmisKayitEkleScreen({super.key, required this.firestoreService});

  @override
  State<GecmisKayitEkleScreen> createState() => _GecmisKayitEkleScreenState();
}

class _GecmisKayitEkleScreenState extends State<GecmisKayitEkleScreen> {
  final _isimController = TextEditingController();
  final _ucretController = TextEditingController();
  Set<DateTime> _seciliGunler = {};
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _isimController.dispose();
    _ucretController.dispose();
    super.dispose();
  }

  Future<void> _kaydiEkle() async {
    final isim = _isimController.text.trim();
    final ucret = tutarMetniniSayiyaCevir(_ucretController.text);

    if (isim.isEmpty) {
      _hataGoster('İşçi adını girmen gerekiyor.');
      return;
    }
    if (ucret == null || ucret <= 0) {
      _hataGoster('Geçerli bir günlük ücret girmen gerekiyor.');
      return;
    }
    if (_seciliGunler.isEmpty) {
      _hataGoster('Takvimden en az bir gün işaretlemen gerekiyor.');
      return;
    }

    setState(() => _kaydediliyor = true);
    try {
      var isciId = (await widget.firestoreService.isciIsimleBul(isim))?.id;
      isciId ??= widget.firestoreService.isciEkle(isim: isim, gunlukUcret: ucret);

      for (final gun in _seciliGunler) {
        widget.firestoreService.isciKayitEkle(
          isciId: isciId,
          tutar: ucret,
          tur: 'gelis',
          tarih: gun,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$isim için ${_seciliGunler.length} günlük kayıt eklendi.'),
            backgroundColor: AppColors.yesilTik,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GEÇMİŞ KAYIT EKLE')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'İşçinin adını ve günlük ücretini gir, geldiği günleri '
                'takvimden işaretle.',
                style: TextStyle(color: AppColors.yaziSoluk, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _isimController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.yazi),
                decoration: const InputDecoration(hintText: 'İşçi Adı'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ucretController,
                keyboardType: TextInputType.number,
                inputFormatters: [BinlikAyraciFormatter()],
                style: const TextStyle(color: AppColors.yazi),
                decoration: const InputDecoration(hintText: 'Günlük Ücreti'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cizgi),
                ),
                child: CokluSecimTakvimi(
                  secilenGunler: _seciliGunler,
                  onDegisti: (yeni) => setState(() => _seciliGunler = yeni),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _kaydediliyor ? null : _kaydiEkle,
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
                          Text('Kaydı Ekle', style: AppTheme.anaButonYazi()),
                          const SizedBox(width: 10),
                          const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
