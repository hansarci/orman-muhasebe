import 'package:flutter/material.dart';
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
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: RichText(
          text: TextSpan(
            style: AppTheme.paraStili(size: 17, renk: AppColors.yazi),
            children: [
              TextSpan(text: '$etiket: '),
              TextSpan(
                text: _paraFormat.format(tutar),
                style: const TextStyle(color: AppColors.yesilTik),
              ),
              const TextSpan(text: ' ₺', style: TextStyle(color: AppColors.yesilTik)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Geçmiş kayıtlar listesindeki "10 Ağu 2026" + tutar satırı, opsiyonel fiş thumbnail'i ile.
String tarihFormatla(DateTime tarih) {
  return DateFormat('dd MMM yyyy', 'tr_TR').format(tarih);
}

String paraFormatla(double tutar) => _paraFormat.format(tutar);

/// Dart'ın standart `toUpperCase()`'i Türkçe'ye uygun değil — "iş" gibi
/// kelimelerdeki noktalı küçük "i"yi yanlışlıkla noktasız "I" yapıyor
/// (doğrusu "İ" olmalı). Sayfa başlıkları gibi Türkçe metinleri büyük
/// harfe çevirirken bunun yerine bu fonksiyon kullanılmalı.
String turkceBuyukHarf(String metin) {
  return metin.replaceAll('i', 'İ').toUpperCase();
}

/// İşletme detayındaki "Geçmiş Kayıtlar" listesinin tek satırı.
/// Fişi varsa solda küçük thumbnail, tıklanınca büyütülüyor.
class GecmisKayitSatiri extends StatelessWidget {
  final DateTime tarih;
  final double tutar;
  final String? fotoUrl;
  final bool fotoBekliyor;
  final VoidCallback? onFotoTikla;

  const GecmisKayitSatiri({
    super.key,
    required this.tarih,
    required this.tutar,
    this.fotoUrl,
    this.fotoBekliyor = false,
    this.onFotoTikla,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.turuncu.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (fotoUrl != null) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onFotoTikla,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          fotoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 32,
                            height: 32,
                            color: AppColors.zemin,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 16, color: AppColors.yaziSoluk),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ] else if (fotoBekliyor) ...[
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(Icons.cloud_upload_outlined,
                      size: 18, color: AppColors.yaziSoluk),
                ),
                const SizedBox(width: 10),
              ],
              Text(tarihFormatla(tarih),
                  style: const TextStyle(fontSize: 13.5, color: AppColors.yazi)),
            ],
          ),
          RichText(
            text: TextSpan(
              style: AppTheme.paraStili(size: 13.5),
              children: [
                TextSpan(text: paraFormatla(tutar)),
                const TextSpan(text: ' ₺', style: TextStyle(color: AppColors.yesilTik)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
