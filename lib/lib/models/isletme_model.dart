import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işin altındaki bir işletmeyi (ör. "Motorcu") temsil eden model.
/// ID'si, işletme adından türetilen bir "slug" (bkz. FirestoreService._slug).
class IsletmeModel {
  final String id;
  final String isim;
  final double toplam;

  IsletmeModel({
    required this.id,
    required this.isim,
    required this.toplam,
  });

  factory IsletmeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return IsletmeModel(
      id: doc.id,
      isim: data['isim'] as String? ?? '',
      toplam: (data['toplam'] as num?)?.toDouble() ?? 0,
    );
  }
}
