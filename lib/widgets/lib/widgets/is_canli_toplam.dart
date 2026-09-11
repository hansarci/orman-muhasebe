import 'package:flutter/material.dart';
import '../models/isletme_model.dart';
import '../models/kayit_model.dart';
import '../services/firestore_service.dart';

/// Bir işin toplam (net) borcunu, o işin altındaki TÜM işletmelerin
/// GERÇEK kayıtlarından (borç - ödeme) canlı olarak hesaplayıp
/// [builder]'a geçirir.
///
/// Bilerek işin/işletmenin üzerinde ayrıca tutulan "toplam" alanına HİÇ
/// güvenmiyoruz — o alan, düzenleme/silme/offline senkronizasyon gibi
/// durumlarda gerçek kayıtlardan sapabiliyordu (Arşiv/İş Detay'da yanlış,
/// İşletme Detay'da doğru rakam görünmesine sebep olan hata buradan
/// kaynaklanıyordu). Burada gösterilen rakam HER ZAMAN kayıtların
/// kendisinden — yani tek doğruluk kaynağından — hesaplanıyor.
class IsCanliToplam extends StatefulWidget {
  final String isId;
  final FirestoreService firestoreService;
  final Widget Function(BuildContext context, double toplam) builder;

  const IsCanliToplam({
    super.key,
    required this.isId,
    required this.firestoreService,
    required this.builder,
  });

  @override
  State<IsCanliToplam> createState() => _IsCanliToplamState();
}

class _IsCanliToplamState extends State<IsCanliToplam> {
  final Map<String, double> _isletmeToplamlari = {};

  double get _genelToplam => _isletmeToplamlari.values.fold(0, (t, v) => t + v);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IsletmeModel>>(
      stream: widget.firestoreService.isletmelerStream(widget.isId),
      builder: (context, isletmeSnap) {
        final isletmeler = isletmeSnap.data ?? [];

        // Artık var olmayan (silinmiş) işletmelerin eski toplamlarını
        // haritadan temizle, yoksa genel toplama hayalet rakam katılır.
        _isletmeToplamlari.removeWhere(
          (id, _) => !isletmeler.any((i) => i.id == id),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            // Her işletme için görünmez bir dinleyici — yalnızca genel
            // toplamı güncel tutmak için var, ekranda hiçbir şey çizmiyor.
            for (final isletme in isletmeler)
              StreamBuilder<List<KayitModel>>(
                key: ValueKey(isletme.id),
                stream: widget.firestoreService.kayitlarStream(widget.isId, isletme.id),
                builder: (context, kayitSnap) {
                  final kayitlar = kayitSnap.data;
                  if (kayitlar != null) {
                    final yeniToplam = kayitlar.fold<double>(
                      0,
                      (t, k) => t + (k.odemeMi ? -k.tutar : k.tutar),
                    );
                    if (_isletmeToplamlari[isletme.id] != yeniToplam) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _isletmeToplamlari[isletme.id] = yeniToplam);
                        }
                      });
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            widget.builder(context, _genelToplam),
          ],
        );
      },
    );
  }
}
