import 'package:hive/hive.dart';

part 'bekleyen_foto.g.dart';

/// İnternet olmadan çekilen fiş fotoğraflarının yerel kuyruğu.
///
/// Firebase Storage, Firestore'un aksine, offline başlatılan yüklemeleri
/// kendiliğinden kuyruğa almıyor. Bu yüzden fotoğrafı önce cihaza (bu Hive
/// kutusuna) kaydediyoruz; bağlantı gelince [PhotoUploadService] sırayla
/// Storage'a yükleyip ilgili Firestore kaydını günceller.
@HiveType(typeId: 0)
class BekleyenFoto extends HiveObject {
  /// Yerel dosya sistemindeki geçici fotoğraf yolu.
  @HiveField(0)
  final String yerelDosyaYolu;

  /// Fotoğrafın ait olduğu iş kaydının Firestore ID'si.
  @HiveField(1)
  final String isId;

  /// Fotoğrafın ait olduğu işletme kaydının Firestore ID'si.
  @HiveField(2)
  final String isletmeId;

  /// Fotoğrafın ait olduğu borç kaydının Firestore ID'si.
  @HiveField(3)
  final String kayitId;

  /// Kaç kez yükleme denendiği (aşırı tekrar denemeyi önlemek için).
  @HiveField(4)
  int denemeSayisi;

  BekleyenFoto({
    required this.yerelDosyaYolu,
    required this.isId,
    required this.isletmeId,
    required this.kayitId,
    this.denemeSayisi = 0,
  });
}
