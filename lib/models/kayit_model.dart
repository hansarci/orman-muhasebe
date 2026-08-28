import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işletmeye ait tek bir kayıt — borç ('borc') veya ödeme ('odeme').
/// Ödeme kayıtları toplamdan DÜŞER, borç kayıtları toplama EKLENİR.
///
/// Firestore yolu: kullanicilar/{uid}/isler/{isId}/isletmeler/{isletmeId}/kayitlar/{kayitId}
class KayitModel {
  final String id;
  final double tutar;
  final DateTime tarih;

  /// 'borc' veya 'odeme'. Eski kayıtlarda bu alan yoksa 'borc' varsayılır.
  final String tur;

  /// Firebase Storage'daki fişin indirilebilir URL'i. Henüz yüklenmediyse
  /// (offline kuyrukta bekliyorsa) null olabilir.
  final String? fotoUrl;

  /// Fotoğraf hâlâ yerel kuyrukta bekliyorsa (internet yoksa) true.
  final bool fotoBekliyor;

  KayitModel({
    required this.id,
    required this.tutar,
    required this.tarih,
    this.tur = 'borc',
    this.fotoUrl,
    this.fotoBekliyor = false,
  });

  bool get odemeMi => tur == 'odeme';

  factory KayitModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return KayitModel(
      id: doc.id,
      tutar: (data['tutar'] as num).toDouble(),
      tarih: (data['tarih'] as Timestamp).toDate(),
      tur: data['tur'] as String? ?? 'borc',
      fotoUrl: data['fotoUrl'] as String?,
      fotoBekliyor: data['fotoBekliyor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tutar': tutar,
      'tarih': Timestamp.fromDate(tarih),
      'tur': tur,
      'fotoUrl': fotoUrl,
      'fotoBekliyor': fotoBekliyor,
    };
  }
}
