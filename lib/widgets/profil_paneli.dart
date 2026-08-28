import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ortak_widgetlar.dart';
import '../screens/sifre_degistir_screen.dart';

/// Arşiv ekranının sağ üstündeki profil ikonuyla açılan yan panel
/// (endDrawer). Hesap bilgisi, "Son giriş" zamanı, İstatistikler, Şifre
/// Değiştir, Çıkış Yap ve Hesabı Sil burada toplanıyor.
class ProfilPaneli extends StatefulWidget {
  final FirestoreService firestoreService;

  const ProfilPaneli({super.key, required this.firestoreService});

  @override
  State<ProfilPaneli> createState() => _ProfilPaneliState();
}

class _ProfilPaneliState extends State<ProfilPaneli> {
  bool _hesapSiliniyor = false;

  /// "Turhan Sarıcı" -> "TS", "mehmetusta" -> "M" gibi rozet harflerini
  /// üretir. En fazla iki kelimenin baş harfi alınır.
  String _baslangicHarfleri(String isim) {
    final kelimeler =
        isim.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) return '?';
    if (kelimeler.length == 1) return kelimeler[0][0].toUpperCase();
    return (kelimeler[0][0] + kelimeler[1][0]).toUpperCase();
  }

  Future<void> _istatistikleriGoster() async {
    Navigator.of(context).pop(); // Paneli kapat.

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, double>>(
        future: widget.firestoreService.tumZamanIstatistikleriGetir(),
        builder: (context, snapshot) {
          return AlertDialog(
            backgroundColor: AppColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.turuncu, width: 2),
            ),
            title: const Text('İstatistikler', style: TextStyle(color: AppColors.yazi)),
            content: !snapshot.hasData
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tüm zamanlardaki işlerinizde:',
                        style: TextStyle(color: AppColors.yaziSoluk, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      _istatistikSatiri('Toplam Kazanç', snapshot.data!['kazanc']!, AppColors.turuncu),
                      _istatistikSatiri('Toplam Masraf', snapshot.data!['masraf']!, Colors.redAccent),
                      _istatistikSatiri('Kâr', snapshot.data!['kar']!, AppColors.yesilTik, cizgiYok: true),
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat', style: TextStyle(color: AppColors.yaziSoluk)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _istatistikSatiri(String etiket, double tutar, Color renk, {bool cizgiYok = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: cizgiYok
            ? null
            : const Border(bottom: BorderSide(color: AppColors.cizgi)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket, style: const TextStyle(color: AppColors.yazi, fontSize: 13.5)),
          Text(
            '₺${paraFormatla(tutar)}',
            style: TextStyle(color: renk, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _sifreDegistirEkraninaGit() {
    Navigator.of(context).pop(); // Paneli kapat.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SifreDegistirScreen()),
    );
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
      // authStateChanges akışı main.dart'ta otomatik olarak Giriş
      // ekranına döndürecek — burada elle bir yönlendirme gerekmiyor.
    }
  }

  Future<void> _hesabiSilOnayiniGoster() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Text('Hesabı Sil', style: TextStyle(color: AppColors.yazi)),
        content: const Text(
          'Emin misiniz? Mevcut verileriniz bir daha geri gelmeyecek.',
          style: TextStyle(color: AppColors.yaziSoluk),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.yaziSoluk)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _hesapSiliniyor = true);
    try {
      await widget.firestoreService.tumVerileriSil();
      await FirebaseAuth.instance.currentUser?.delete();
      // Hesap silinince authStateChanges akışı otomatik olarak Giriş
      // ekranına dönecek.
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Güvenlik nedeniyle önce çıkış yapıp tekrar giriş '
                'yapman, sonra hesabını silmen gerekiyor. (Verilerin zaten silindi.)',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 8),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.message ?? e.code}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _hesapSiliniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = FirebaseAuth.instance.currentUser;
    final adSoyad = kullanici?.displayName?.trim().isNotEmpty == true
        ? kullanici!.displayName!.trim()
        : 'Kullanıcı';
    final sonGiris = kullanici?.metadata.lastSignInTime;
    final sonGirisMetni =
        sonGiris != null ? DateFormat('dd.MM.yyyy, HH:mm').format(sonGiris) : '—';

    return Drawer(
      backgroundColor: AppColors.zemin,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.turuncu, width: 2),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.panel,
                      border: Border.all(color: AppColors.turuncu, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _baslangicHarfleri(adSoyad),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        color: AppColors.turuncu,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: AppColors.yaziSoluk),
                            children: [
                              const TextSpan(text: 'Giriş yapan hesap: '),
                              TextSpan(
                                text: adSoyad,
                                style: const TextStyle(
                                  fontFamily: 'Oswald',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: AppColors.yazi,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Son giriş: $sonGirisMetni',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.yaziSoluk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _menuOgesi(
                icon: Icons.bar_chart_rounded,
                metin: 'İstatistikler',
                onTap: _istatistikleriGoster,
              ),
              _menuOgesi(
                icon: Icons.lock_outline,
                metin: 'Şifre Değiştir',
                onTap: _sifreDegistirEkraninaGit,
              ),
              _menuOgesi(
                icon: Icons.logout,
                metin: 'Çıkış Yap',
                onTap: _cikisYap,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppColors.cizgi, height: 1),
              ),
              _menuOgesi(
                icon: Icons.delete_outline,
                metin: 'Hesabı Sil',
                renk: Colors.redAccent,
                yukleniyor: _hesapSiliniyor,
                onTap: _hesapSiliniyor ? null : _hesabiSilOnayiniGoster,
              ),
              const Spacer(),
              const Center(
                child: Text(
                  'Orman Muhasebe · v1.0',
                  style: TextStyle(fontSize: 11, color: AppColors.yaziSoluk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuOgesi({
    required IconData icon,
    required String metin,
    required VoidCallback? onTap,
    Color renk = AppColors.yazi,
    bool yukleniyor = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: yukleniyor
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 19, color: renk),
              ),
              const SizedBox(width: 12),
              Text(metin, style: TextStyle(fontSize: 14, color: renk)),
            ],
          ),
        ),
      ),
    );
  }
}
