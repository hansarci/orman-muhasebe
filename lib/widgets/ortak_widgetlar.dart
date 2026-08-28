import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

final _paraFormat = NumberFormat.decimalPattern('tr_TR');

/// Ana sayfadaki iş satırları ve iş detayındaki işletme satırları için
/// ortak görünüm: solda isim, sağda turuncu tutar.
class KayitSatiri extends StatelessWidget {
  final String isim;
  final double tutar;
  final VoidCallback onTap;

  const KayitSatiri({
    super.key,
    required this.isim,
    required this.tutar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cizgi),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isim, style: const TextStyle(fontSize: 14.5, color: AppColors.yazi)),
                Text('₺${_paraFormat.format(tutar)}', style: AppTheme.paraStili()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Toplam masraf: 4.200 ₺" satırı — beyaz etiket, yeşil miktar, yeşil ₺.
class ToplamSatiri extends StatelessWidget {
  final String etiket;
  final double tutar;

  const ToplamSatiri({super.key, required this.etiket, required this.tutar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.yazi),
            children: [
              TextSpan(text: '$etiket: '),
              TextSpan(
                text: '${_paraFormat.format(tutar)} ',
                style: const TextStyle(color: AppColors.yesilTik),
              ),
              const TextSpan(text: '₺', style: TextStyle(color: AppColors.yesilTik)),
            ],
          ),
        ),
      ),
    );
  }
}

String tarihFormatla(DateTime tarih) => DateFormat('dd.MM.yyyy').format(tarih);

String paraFormatla(double tutar) => _paraFormat.format(tutar);

/// Dart'ın standart `toUpperCase()`'i Türkçe'ye uygun değil — "iş" gibi
/// kelimelerdeki noktalı küçük "i"yi yanlışlıkla noktasız "I" yapıyor
/// (doğrusu "İ" olmalı). Sayfa başlıkları gibi Türkçe metinleri büyük
/// harfe çevirirken bunun yerine bu fonksiyon kullanılmalı.
String turkceBuyukHarf(String metin) {
  return metin.replaceAll('i', 'İ').toUpperCase();
}

/// Tutar kutularına yazarken otomatik binlik nokta koyar: "400000" yazınca
/// anında "400.000" gösterir — kullanıcının sıfırları saymasına gerek
/// kalmaz. Kuruş/ondalık desteklemez, sadece tam sayı (Türk Lirası'nda
/// pratikte yeterli).
class BinlikAyraciFormatter extends TextInputFormatter {
  static final _format = NumberFormat.decimalPattern('tr_TR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rakamlar = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rakamlar.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final yeniMetin = _format.format(int.parse(rakamlar));
    return TextEditingValue(
      text: yeniMetin,
      selection: TextSelection.collapsed(offset: yeniMetin.length),
    );
  }
}

/// BinlikAyraciFormatter ile noktalı gösterilen bir tutar metnini
/// ("400.000" gibi) gerçek sayıya çevirir. Tutar kutularından değer
/// okurken her zaman double.tryParse yerine bu kullanılmalı.
double? tutarMetniniSayiyaCevir(String metin) {
  final temiz = metin.replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(temiz);
}

/// Bir fiş fotoğrafını tam ekran (lightbox) olarak açar.
void fisiBuyukGoster(BuildContext context, String fotoUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(fotoUrl),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
