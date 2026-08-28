import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işi (ör. "Ballıdağ") temsil eden model. "toplam" alanı, o işin
/// altındaki tüm işletmelerin net (borç - ödeme) toplamını gösterir.
class IsModel {
  final String id;
  final String isim;
  final double toplam;
  final DateTime olusturulmaTarihi;

  IsModel({
    required this.id,
    required this.isim,
    required this.toplam,
    required this.olusturulmaTarihi,
  });

  factory IsModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IsModel(
      id: doc.id,
      isim: data['isim'] as String? ?? '',
      toplam: (data['toplam'] as num?)?.toDouble() ?? 0,
      olusturulmaTarihi:
          (data['olusturulmaTarihi'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isim': isim,
      'toplam': toplam,
      'olusturulmaTarihi': Timestamp.fromDate(olusturulmaTarihi),
    };
  }
}
