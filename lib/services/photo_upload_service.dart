import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'firestore_service.dart';

/// Fiş fotoğraflarını internet olmadan da "kaybetmeden" yükleyebilmek için
/// basit bir yerel kuyruk. Fotoğraf seçildiğinde hemen kuyruğa (Hive) yazılır;
/// bağlantı durumuna bakılmaksızın arka planda yükleme denenir, başarısız
/// olursa bağlantı gelince otomatik tekrar denenir.
class PhotoUploadService {
  static const _kutuAdi = 'foto_kuyrugu';
  final FirestoreService _firestoreService;
  late Box _kutu;

  PhotoUploadService(this._firestoreService);

  Future<void> baslat() async {
    _kutu = await Hive.openBox(_kutuAdi);
    // Açılışta bekleyen varsa hemen bir deneme yap.
    kuyrugunuIsle();
    Connectivity().onConnectivityChanged.listen((sonuc) {
      if (sonuc != ConnectivityResult.none) {
        kuyrugunuIsle();
      }
    });
  }

  Future<void> kuyrugaEkle({
    required File secilenFoto,
    required String isId,
    required String isletmeId,
    required String kayitId,
  }) async {
    final belge = jsonEncode({
      'yerelYol': secilenFoto.path,
      'isId': isId,
      'isletmeId': isletmeId,
      'kayitId': kayitId,
      'denemeSayisi': 0,
    });
    await _kutu.add(belge);
    kuyrugunuIsle();
  }

  Future<void> kuyrugunuIsle() async {
    final anahtarlar = _kutu.keys.toList();
    for (final anahtar in anahtarlar) {
      final ham = _kutu.get(anahtar);
      if (ham == null) continue;
      Map<String, dynamic> veri;
      try {
        veri = jsonDecode(ham as String) as Map<String, dynamic>;
      } catch (_) {
        await _kutu.delete(anahtar);
        continue;
      }

      final yerelYol = veri['yerelYol'] as String;
      final dosya = File(yerelYol);
      if (!await dosya.exists()) {
        await _kutu.delete(anahtar);
        continue;
      }

      try {
        final isId = veri['isId'] as String;
        final isletmeId = veri['isletmeId'] as String;
        final kayitId = veri['kayitId'] as String;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('fisler')
            .child('$isId-$isletmeId-$kayitId.jpg');

        await storageRef.putFile(dosya);
        final url = await storageRef.getDownloadURL();

        await _firestoreService.kayitFotoGuncelle(
          isId: isId,
          isletmeId: isletmeId,
          kayitId: kayitId,
          fotoUrl: url,
        );

        await _kutu.delete(anahtar);
      } catch (_) {
        final denemeSayisi = (veri['denemeSayisi'] as int? ?? 0) + 1;
        veri['denemeSayisi'] = denemeSayisi;
        await _kutu.put(anahtar, jsonEncode(veri));
        // Bağlantı yoksa ya da geçici bir hata varsa sessizce vazgeç,
        // bir sonraki bağlantı değişiminde tekrar denenecek.
      }
    }
  }
}
