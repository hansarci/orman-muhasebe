import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Giriş / Kayıt Ol ekranı — RUMUZ (kullanıcı adı) ile.
///
/// Firebase Authentication e-posta/şifre dışında gerçek bir "kullanıcı
/// adı" girişi desteklemiyor. Bunu basitçe çözmek için: kullanıcının
/// yazdığı kullanıcı adı, arka planda otomatik "kullaniciadi@ormanmuhasebe.local"
/// gibi sahte bir e-postaya çevrilip Firebase'e öyle gönderiliyor —
/// kullanıcı hiçbir zaman e-posta görmüyor/yazmıyor.
///
/// Şifre SADECE RAKAMLARDAN oluşuyor (numara klavyesiyle giriliyor) —
/// sahada hızlı giriş için harf klavyesinden daha pratik.
class GirisScreen extends StatefulWidget {
  const GirisScreen({super.key});

  @override
  State<GirisScreen> createState() => _GirisScreenState();
}

class _GirisScreenState extends State<GirisScreen> {
  final _kullaniciAdiController = TextEditingController();
  final _sifreController = TextEditingController();

  /// true = "Kayıt Ol" modu, false = "Giriş Yap" modu.
  bool _kayitModu = false;
  bool _yukleniyor = false;
  String? _hataMesaji;

  @override
  void dispose() {
    _kullaniciAdiController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  /// "Mehmet Usta" -> "mehmet-usta@ormanmuhasebe.local" gibi, kullanıcı
  /// adını Firebase'in kabul edeceği sahte ama geçerli bir e-postaya çevirir.
  String _kullaniciAdiniSahteEpostayaCevir(String kullaniciAdi) {
    final tr = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    };
    var sonuc = kullaniciAdi.trim().toLowerCase();
    tr.forEach((k, v) => sonuc = sonuc.replaceAll(k, v));
    sonuc = sonuc.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    sonuc = sonuc.replaceAll(RegExp(r'^-+|-+$'), '');
    return '$sonuc@ormanmuhasebe.local';
  }

  String _hatayiTurkceyeCevir(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Kullanıcı adı geçersiz karakterler içeriyor — sadece harf/rakam kullan.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu kullanıcı adıyla kayıtlı bir hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kullanıcı adı veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu kullanıcı adı zaten kullanılıyor — "Giriş Yap"ı dene ya da başka bir kullanıcı adı seç.';
      case 'weak-password':
        return 'Şifre çok kısa — en az 6 rakam olmalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Giriş/kayıt için internet gerekiyor.';
      default:
        return 'Bir hata oluştu: ${e.message ?? e.code}';
    }
  }

  Future<void> _gonder() async {
    final kullaniciAdi = _kullaniciAdiController.text.trim();
    final sifre = _sifreController.text;

    if (kullaniciAdi.isEmpty || sifre.isEmpty) {
      setState(() => _hataMesaji = 'Kullanıcı adı ve şifre boş bırakılamaz.');
      return;
    }
    if (kullaniciAdi.replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ]'), '').isEmpty) {
      setState(() => _hataMesaji = 'Kullanıcı adı en az bir harf/rakam içermeli.');
      return;
    }

    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
    });

    final sahteEposta = _kullaniciAdiniSahteEpostayaCevir(kullaniciAdi);

    try {
      if (_kayitModu) {
        final sonuc = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: sahteEposta,
          password: sifre,
        );
        // Kullanıcı adını, PDF/ekranlarda ileride "kim ekledi" gibi
        // ihtiyaçlar için görüntü adı olarak da kaydediyoruz.
        await sonuc.user?.updateDisplayName(kullaniciAdi);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: sahteEposta,
          password: sifre,
        );
      }
      // Başarılıysa main.dart'taki StreamBuilder otomatik olarak
      // ArsivScreen'e geçecek — burada elle bir yönlendirme gerekmiyor.
    } on FirebaseAuthException catch (e) {
      setState(() => _hataMesaji = _hatayiTurkceyeCevir(e));
    } catch (e) {
      setState(() => _hataMesaji = 'Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _moduDegistir() {
    setState(() {
      _kayitModu = !_kayitModu;
      _hataMesaji = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Orman Muhasebe',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    letterSpacing: 0.5,
                    color: AppColors.yazi,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: _kullaniciAdiController,
                    textAlign: TextAlign.center,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    style: const TextStyle(color: AppColors.yazi),
                    decoration: InputDecoration(
                      hintText: _kayitModu ? 'Kullanıcı Adı Oluştur' : 'Kullanıcı Adı',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: _sifreController,
                    textAlign: TextAlign.center,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.yazi),
                    decoration: InputDecoration(
                      hintText: _kayitModu
                          ? 'Şifre Oluştur (En az 6 karakter)'
                          : 'Şifrenizi Giriniz',
                    ),
                  ),
                ),
                if (_hataMesaji != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hataMesaji!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _yukleniyor ? null : _gonder,
                    style: AppTheme.anaButonStili(),
                    child: _yukleniyor
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _kayitModu ? 'Kayıt Ol' : 'Giriş Yap',
                            style: AppTheme.anaButonYazi(),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                // İnce çerçeveli, yazı genişliğinde geçiş linki — tam
                // genişlik dolgusu YOK, sadece yazının etrafını sarıyor.
                OutlinedButton(
                  onPressed: _yukleniyor ? null : _moduDegistir,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.turuncu, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _kayitModu
                        ? 'Zaten hesabın var mı? Giriş Yap'
                        : 'Hesabın yok mu? Kayıt Ol',
                    style: const TextStyle(color: AppColors.turuncu, fontSize: 13),
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
