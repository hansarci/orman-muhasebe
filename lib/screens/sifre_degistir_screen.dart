import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Profil panelinden açılan "Şifre Değiştir" ekranı. Mevcut şifre
/// SORULMUYOR — kullanıcı zaten giriş yapmış (oturumu açık) olduğu için
/// buna gerek yok, sadece yeni şifre + tekrarı isteniyor. Şifre sadece
/// rakamlardan oluşuyor (numara klavyesiyle giriliyor).
class SifreDegistirScreen extends StatefulWidget {
  const SifreDegistirScreen({super.key});

  @override
  State<SifreDegistirScreen> createState() => _SifreDegistirScreenState();
}

class _SifreDegistirScreenState extends State<SifreDegistirScreen> {
  final _yeniSifreController = TextEditingController();
  final _yeniSifreTekrarController = TextEditingController();
  bool _yukleniyor = false;
  String? _hataMesaji;
  bool _basarili = false;

  @override
  void dispose() {
    _yeniSifreController.dispose();
    _yeniSifreTekrarController.dispose();
    super.dispose();
  }

  Future<void> _sifreyiDegistir() async {
    final yeniSifre = _yeniSifreController.text;
    final tekrar = _yeniSifreTekrarController.text;

    setState(() {
      _hataMesaji = null;
      _basarili = false;
    });

    if (yeniSifre.isEmpty || tekrar.isEmpty) {
      setState(() => _hataMesaji = 'Tüm alanları doldurman gerekiyor.');
      return;
    }
    if (yeniSifre.length < 6) {
      setState(() => _hataMesaji = 'Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (yeniSifre != tekrar) {
      setState(() => _hataMesaji = 'Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _yukleniyor = true);
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(yeniSifre);
      _yeniSifreController.clear();
      _yeniSifreTekrarController.clear();
      setState(() => _basarili = true);
    } on FirebaseAuthException catch (e) {
      String mesaj;
      switch (e.code) {
        case 'requires-recent-login':
          mesaj = 'Güvenlik nedeniyle önce çıkış yapıp tekrar giriş yapman, '
              'sonra şifreni değiştirmen gerekiyor.';
          break;
        case 'weak-password':
          mesaj = 'Şifre çok kısa — en az 6 rakam olmalı.';
          break;
        case 'network-request-failed':
          mesaj = 'İnternet bağlantısı yok.';
          break;
        default:
          mesaj = 'Bir hata oluştu: ${e.message ?? e.code}';
      }
      setState(() => _hataMesaji = mesaj);
    } catch (e) {
      setState(() => _hataMesaji = 'Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ŞİFRE DEĞİŞTİR')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _yeniSifreController,
                  textAlign: TextAlign.center,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.yazi),
                  decoration: const InputDecoration(hintText: 'Yeni Şifre (En az 6 karakter)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _yeniSifreTekrarController,
                  textAlign: TextAlign.center,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.yazi),
                  decoration: const InputDecoration(hintText: 'Yeni Şifre (Tekrar)'),
                ),
                if (_hataMesaji != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hataMesaji!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ],
                if (_basarili) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Şifren başarıyla değiştirildi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.yesilTik, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _yukleniyor ? null : _sifreyiDegistir,
                  style: AppTheme.anaButonStili(),
                  child: _yukleniyor
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Şifreyi Değiştir', style: AppTheme.anaButonYazi()),
                            const SizedBox(width: 10),
                            const Text('✔✔', style: TextStyle(color: AppColors.yesilTik)),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Şifreni değiştirdikten sonra tekrar giriş yapman '
                  'gerekmez, aynı oturumda devam edersin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.yaziSoluk, fontSize: 11.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
