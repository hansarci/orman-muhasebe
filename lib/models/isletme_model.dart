import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir işin (iş sahasının) altındaki işletme/kişi (ör. Motorcu, Benzinlik).
///
/// Firestore yolu: isler/{isId}/isletmeler/{isletmeId}
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
      isim: data['isim'] as String,
      toplam: (data['toplam'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isim': isim,
      'toplam': toplam,
    };
  }
}
