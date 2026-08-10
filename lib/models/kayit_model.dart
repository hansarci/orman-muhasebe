import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işletmeye ait tek bir borç kaydı (tarih + tutar + opsiyonel fiş fotoğrafı).
///
/// Firestore yolu: isler/{isId}/isletmeler/{isletmeId}/kayitlar/{kayitId}
class KayitModel {
  final String id;
  final double tutar;
  final DateTime tarih;

  /// Firebase Storage'daki fişin indirilebilir URL'i. Henüz yüklenmediyse
  /// (offline kuyrukta bekliyorsa) null olabilir.
  final String? fotoUrl;

  /// Fotoğraf hâlâ yerel kuyrukta bekliyorsa (internet yoksa) true.
  final bool fotoBekliyor;

  KayitModel({
    required this.id,
    required this.tutar,
    required this.tarih,
    this.fotoUrl,
    this.fotoBekliyor = false,
  });

  factory KayitModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return KayitModel(
      id: doc.id,
      tutar: (data['tutar'] as num).toDouble(),
      tarih: (data['tarih'] as Timestamp).toDate(),
      fotoUrl: data['fotoUrl'] as String?,
      fotoBekliyor: data['fotoBekliyor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tutar': tutar,
      'tarih': Timestamp.fromDate(tarih),
      'fotoUrl': fotoUrl,
      'fotoBekliyor': fotoBekliyor,
    };
  }
}
