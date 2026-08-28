import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "Geçmiş Kayıt Ekle" ekranındaki, birden fazla günün tıklanıp yeşile
/// dönebildiği basit ay takvimi. Seçili günler [secilenGunler] setinde
/// (saat kısmı sıfırlanmış DateTime olarak) tutulur.
class CokluSecimTakvimi extends StatefulWidget {
  final Set<DateTime> secilenGunler;
  final ValueChanged<Set<DateTime>> onDegisti;

  const CokluSecimTakvimi({
    super.key,
    required this.secilenGunler,
    required this.onDegisti,
  });

  @override
  State<CokluSecimTakvimi> createState() => _CokluSecimTakvimiState();
}

class _CokluSecimTakvimiState extends State<CokluSecimTakvimi> {
  late DateTime _gosterilenAy;

  static const _ayAdlari = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _gunEtiketleri = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  void initState() {
    super.initState();
    final su = DateTime.now();
    _gosterilenAy = DateTime(su.year, su.month);
  }

  DateTime _saatsiz(DateTime t) => DateTime(t.year, t.month, t.day);

  void _gunuSecToggle(DateTime gun) {
    final temiz = _saatsiz(gun);
    final yeniSet = Set<DateTime>.from(widget.secilenGunler);
    final mevcutVarMi = yeniSet.any((g) => g == temiz);
    if (mevcutVarMi) {
      yeniSet.removeWhere((g) => g == temiz);
    } else {
      yeniSet.add(temiz);
    }
    widget.onDegisti(yeniSet);
  }

  @override
  Widget build(BuildContext context) {
    final ilkGun = DateTime(_gosterilenAy.year, _gosterilenAy.month, 1);
    final bosGunSayisi = (ilkGun.weekday - 1) % 7; // Pazartesi ilk gün.
    final ayinGunSayisi = DateTime(_gosterilenAy.year, _gosterilenAy.month + 1, 0).day;
    final bugun = _saatsiz(DateTime.now());

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.turuncu),
              onPressed: () => setState(() {
                _gosterilenAy = DateTime(_gosterilenAy.year, _gosterilenAy.month - 1);
              }),
            ),
            Text(
              '${_ayAdlari[_gosterilenAy.month - 1]} ${_gosterilenAy.year}',
              style: const TextStyle(
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.yazi,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.turuncu),
              onPressed: () => setState(() {
                _gosterilenAy = DateTime(_gosterilenAy.year, _gosterilenAy.month + 1);
              }),
            ),
          ],
        ),
        Row(
          children: _gunEtiketleri
              .map((e) => Expanded(
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 10, color: AppColors.yaziSoluk)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < bosGunSayisi; i++) const SizedBox.shrink(),
            for (var gun = 1; gun <= ayinGunSayisi; gun++)
              _gunHucresi(gun, bugun),
          ],
        ),
      ],
    );
  }

  Widget _gunHucresi(int gun, DateTime bugun) {
    final tarih = DateTime(_gosterilenAy.year, _gosterilenAy.month, gun);
    final secili = widget.secilenGunler.any((g) => g == tarih);
    final buGun = tarih == bugun;

    return GestureDetector(
      onTap: () => _gunuSecToggle(tarih),
      child: Container(
        decoration: BoxDecoration(
          color: secili ? AppColors.yesilTik : AppColors.zemin,
          borderRadius: BorderRadius.circular(8),
          border: buGun && !secili ? Border.all(color: AppColors.turuncu) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$gun',
          style: TextStyle(
            fontSize: 12,
            fontWeight: secili ? FontWeight.w700 : FontWeight.w400,
            color: secili ? const Color(0xFF10231A) : AppColors.yazi,
          ),
        ),
      ),
    );
  }
}
