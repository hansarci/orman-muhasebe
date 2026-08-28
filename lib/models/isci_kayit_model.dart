import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işçinin tek bir günlük hareketi — 'gelis' (o gün işe geldi, hak
/// ediş kazandı) veya 'odeme' (o gün kendisine ödeme yapıldı).
///
/// Firestore yolu: kullanicilar/{uid}/iscilerdb/{isciId}/kayitlar/{kayitId}
class IsciKayitModel {
  final String id;
  final DateTime tarih;
  final double tutar;
  final String tur;

  IsciKayitModel({
    required this.id,
    required this.tarih,
    required this.tutar,
    required this.tur,
  });

  bool get gelisMi => tur == 'gelis';

  factory IsciKayitModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IsciKayitModel(
      id: doc.id,
      tarih: (data['tarih'] as Timestamp).toDate(),
      tutar: (data['tutar'] as num).toDouble(),
      tur: data['tur'] as String? ?? 'gelis',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tarih': Timestamp.fromDate(tarih),
      'tutar': tutar,
      'tur': tur,
    };
  }
}
