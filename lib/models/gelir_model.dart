import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işin kazandığı geliri temsil eden tek bir kayıt (tarih + tutar).
/// "Kazanç ekle" ile eklenen her giriş ayrı bir belge olarak tutulur —
/// böylece PDF'te tarih tarih dökülebilir ve toplamı her zaman kayıtların
/// kendisinden hesaplanabilir (offline'da da güvenilir olsun diye).
///
/// Firestore yolu: isler/{isId}/gelirler/{gelirId}
class GelirModel {
  final String id;
  final double tutar;
  final DateTime tarih;

  GelirModel({
    required this.id,
    required this.tutar,
    required this.tarih,
  });

  factory GelirModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GelirModel(
      id: doc.id,
      tutar: (data['tutar'] as num).toDouble(),
      tarih: (data['tarih'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tutar': tutar,
      'tarih': Timestamp.fromDate(tarih),
    };
  }
}
