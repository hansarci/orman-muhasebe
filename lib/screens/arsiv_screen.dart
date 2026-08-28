import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/is_model.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ortak_widgetlar.dart';
import '../widgets/yeni_is_modal.dart';
import 'is_detay_screen.dart';

/// Uygulamanın karşılama ekranı: giriş yapan kullanıcının KENDİ işlerinin
/// (Ballıdağ, Karaçam Yolu vb.) listelendiği arşiv.
///
/// Bir satıra UZUN BASINCA satır kabarır, "Kazanç ekle" ve "PDF Gönder"
/// seçenekleri belirir.
class ArsivScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;

  const ArsivScreen({
    super.key,
    required this.firestoreService,
    required this.photoUploadService,
  });

  @override
  State<ArsivScreen> createState() => _ArsivScreenState();
}

class _ArsivScreenState extends State<ArsivScreen> {
  String? _seciliIsId;
  bool _pdfHazirlaniyor = false;
  late final PdfService _pdfService;

  @override
  void initState() {
    super.initState();
    _pdfService = PdfService(widget.firestoreService);
  }

  Future<void> _kazancEklePenceresiniAc(IsModel is_) async {
    final controller = TextEditingController();
    final tutar = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('${is_.isim} — Kazanç Ekle', style: const TextStyle(color: AppColors.yazi)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [BinlikAyraciFormatter()],
          style: const TextStyle(color: AppColors.yazi),
          decoration: const InputDecoration(hintText: 'Kazanılan Para (₺)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final deger = tutarMetniniSayiyaCevir(controller.text);
              Navigator.of(context).pop(deger);
            },
            child: const Text('Kaydet', style: TextStyle(color: AppColors.yesilTik)),
          ),
        ],
      ),
    );

    if (tutar != null && tutar > 0) {
      widget.firestoreService.gelirEkle(isId: is_.id, tutar: tutar);
    }
    if (mounted) setState(() => _seciliIsId = null);
  }

  Future<void> _pdfPaylas(IsModel is_) async {
    if (_pdfHazirlaniyor) return;
    setState(() {
      _pdfHazirlaniyor = true;
      _seciliIsId = null;
    });
    try {
      await _pdfService.isiPdfOlarakPaylas(is_);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturulamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfHazirlaniyor = false);
    }
  }

  bool _aktariliyor = false;

  Future<void> _eskiVerileriAktar() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Eski Verileri Aktar', style: TextStyle(color: AppColors.yazi)),
        content: const Text(
          'Önceki (giriş yapmadan önceki) tüm işler, işletmeler, kayıtlar '
          've kazançlar bu hesaba kopyalanacak. Bu işlem birkaç dakika '
          'sürebilir ve internet bağlantısı gerektirir. Devam edilsin mi?',
          style: TextStyle(color: AppColors.yaziSoluk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aktar', style: TextStyle(color: AppColors.yesilTik)),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _aktariliyor = true);
    try {
      final sayi = await widget.firestoreService.eskiVerileriAktar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sayi iş başarıyla bu hesaba aktarıldı.'),
            backgroundColor: AppColors.yesilTik,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aktarım sırasında hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _aktariliyor = false);
    }
  }

  Future<void> _cikisYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Çıkış yap', style: TextStyle(color: AppColors.yazi)),
        content: const Text(
          'Hesabından çıkış yapmak istediğine emin misin?',
          style: TextStyle(color: AppColors.yaziSoluk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BORÇ KAYITLARI'),
        actions: [
          if (_pdfHazirlaniyor || _aktariliyor)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Eski verileri bu hesaba aktar',
            onPressed: _aktariliyor ? null : _eskiVerileriAktar,
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: _cikisYap,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_seciliIsId != null) setState(() => _seciliIsId = null);
        },
        child: StreamBuilder<List<IsModel>>(
          stream: widget.firestoreService.islerStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final isler = snapshot.data ?? [];

            if (isler.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Henüz bir iş eklenmedi.\nSağ alttaki + butonuyla ilk işi oluşturabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.yaziSoluk),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: isler.length,
              itemBuilder: (context, index) {
                final is_ = isler[index];
                return _IsSatiri(
                  is_: is_,
                  secili: _seciliIsId == is_.id,
                  onUzunBas: () => setState(() => _seciliIsId = is_.id),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IsDetayScreen(
                          isId: is_.id,
                          firestoreService: widget.firestoreService,
                          photoUploadService: widget.photoUploadService,
                        ),
                      ),
                    );
                  },
                  onKazancEkle: () => _kazancEklePenceresiniAc(is_),
                  onPdfGonder: () => _pdfPaylas(is_),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => yeniIsModalAc(
          context,
          firestoreService: widget.firestoreService,
          photoUploadService: widget.photoUploadService,
        ),
        child: const Text('+', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}

/// Arşivdeki tek bir iş satırı. Uzun basınca "kabarır", tutar yerine
/// "Kazanç ekle" ve "PDF Gönder" butonları belirir. Normal (kısa) tıklama
/// iş detayına götürür.
class _IsSatiri extends StatelessWidget {
  final IsModel is_;
  final bool secili;
  final VoidCallback onUzunBas;
  final VoidCallback onTap;
  final VoidCallback onKazancEkle;
  final VoidCallback onPdfGonder;

  const _IsSatiri({
    required this.is_,
    required this.secili,
    required this.onUzunBas,
    required this.onTap,
    required this.onKazancEkle,
    required this.onPdfGonder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onUzunBas,
      onTap: secili ? () {} : onTap,
      child: AnimatedScale(
        scale: secili ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secili ? AppColors.turuncu : AppColors.cizgi),
            boxShadow: secili
                ? [const BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(is_.isim, style: const TextStyle(fontSize: 14.5, color: AppColors.yazi)),
              if (secili)
                Row(
                  children: [
                    _aksiyonButonu('Kazanç ekle', AppColors.yesilTik, onKazancEkle),
                    const SizedBox(width: 6),
                    _aksiyonButonu('PDF Gönder', AppColors.turuncu, onPdfGonder),
                  ],
                )
              else
                Text(
                  '₺${paraFormatla(is_.toplam)}',
                  style: AppTheme.paraStili(),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Text(metin, style: TextStyle(fontSize: 11, color: renk)),
      ),
    );
  }
}
