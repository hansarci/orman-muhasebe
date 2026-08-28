import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işçiyi temsil eden model. "kazanc" alanı, o işçinin o anki
/// ÖDENMEMİŞ (birikmiş) hak edişini gösterir — "Evet, geldi" dendikçe
/// artar, "Ödeme Yap" ile azalır.
class IsciModel {
  final String id;
  final String isim;
  final double gunlukUcret;
  final double kazanc;

  IsciModel({
    required this.id,
    required this.isim,
    required this.gunlukUcret,
    required this.kazanc,
  });

  factory IsciModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IsciModel(
      id: doc.id,
      isim: data['isim'] as String? ?? '',
      gunlukUcret: (data['gunlukUcret'] as num?)?.toDouble() ?? 0,
      kazanc: (data['kazanc'] as num?)?.toDouble() ?? 0,
    );
  }
}
