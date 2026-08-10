import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bekleyen_foto.dart';
import 'firestore_service.dart';

/// Fiş fotoğraflarının offline-first yükleme kuyruğu.
///
/// NEDEN GEREKLİ: Firestore'un aksine Firebase Storage, internet olmadan
/// başlatılan yüklemeleri kendiliğinden kuyruğa alıp bağlantı gelince
/// devam ettirmiyor. Orman/dağ gibi sinyalsiz alanlarda çekilen fişler bu
/// yüzden kaybolabilir. Bu servis, fotoğrafı önce cihaza kaydedip
/// (Hive kutusu + dosya sistemi), bağlantı geldiğinde sırayla Storage'a
/// yüklüyor ve ilgili Firestore kaydını günceliyor.
class PhotoUploadService {
  static const _kutuAdi = 'bekleyenFotolar';

  final FirestoreService _firestoreService;
  final _uuid = const Uuid();
  Box<BekleyenFoto>? _kutu;

  PhotoUploadService(this._firestoreService);

  /// main() içinde, uygulama açılırken bir kere çağrılmalı.
  Future<void> baslat() async {
    Hive.registerAdapter(BekleyenFotoAdapter());
    _kutu = await Hive.openBox<BekleyenFoto>(_kutuAdi);

    // Bağlantı her geldiğinde bekleyen fotoğrafları otomatik dene.
    Connectivity().onConnectivityChanged.listen((sonuclar) {
      final baglantiVar = sonuclar.any((s) => s != ConnectivityResult.none);
      if (baglantiVar) {
        kuyruguIsle();
      }
    });

    // Açılışta da bir kere dene (uygulama offline kapanıp online açılmış olabilir).
    kuyruguIsle();
  }

  /// Çekilen fotoğrafı cihazın kalıcı dizinine kopyalar ve kuyruğa ekler.
  /// Kayıt zaten oluşturulmuş olmalı (fotoBekliyor: true ile).
  Future<void> kuyrugaEkle({
    required File secilenFoto,
    required String isId,
    required String isletmeId,
    required String kayitId,
  }) async {
    final belgeDizini = await getApplicationDocumentsDirectory();
    final hedefYol =
        '${belgeDizini.path}/fisler/${_uuid.v4()}${_uzanti(secilenFoto.path)}';
    await Directory('${belgeDizini.path}/fisler').create(recursive: true);
    final kalici = await secilenFoto.copy(hedefYol);

    await _kutu!.add(BekleyenFoto(
      yerelDosyaYolu: kalici.path,
      isId: isId,
      isletmeId: isletmeId,
      kayitId: kayitId,
    ));

    // Bağlantı varsa hemen dene, yoksa bir sonraki onConnectivityChanged
    // tetiklenmesini bekle.
    _kuyruguGuvenliIsle();
  }

  void _kuyruguGuvenliIsle() {
    kuyrugunuIsle().catchError((_) {
      // Sessizce yut — bağlantı yoksa zaten normal, sıradaki tetiklemede tekrar denenecek.
    });
  }

  /// Kuyruktaki tüm bekleyen fotoğrafları sırayla Storage'a yüklemeyi dener.
  Future<void> kuyrugunuIsle() async {
    if (_kutu == null || _kutu!.isEmpty) return;

    final baglanti = await Connectivity().checkConnectivity();
    if (baglanti.every((s) => s == ConnectivityResult.none)) return;

    // Kopyasını al: işlerken kutu değişebilir.
    final bekleyenler = _kutu!.values.toList();

    for (final bekleyen in bekleyenler) {
      try {
        final dosya = File(bekleyen.yerelDosyaYolu);
        if (!await dosya.exists()) {
          await bekleyen.delete();
          continue;
        }

        final storageYolu =
            'fisler/${bekleyen.isId}/${bekleyen.isletmeId}/${bekleyen.kayitId}${_uzanti(bekleyen.yerelDosyaYolu)}';
        final ref = FirebaseStorage.instance.ref(storageYolu);
        await ref.putFile(dosya);
        final url = await ref.getDownloadURL();

        await _firestoreService.kayitFotoGuncelle(
          isId: bekleyen.isId,
          isletmeId: bekleyen.isletmeId,
          kayitId: bekleyen.kayitId,
          fotoUrl: url,
        );

        await bekleyen.delete(); // Hive kutusundan çıkar.
      } catch (_) {
        bekleyen.denemeSayisi += 1;
        await bekleyen.save();
        // 10 denemeden sonra bile başarısızsa kullanıcıya ayrıca bir
        // "senkronize edilemedi" göstergesi eklenebilir; şimdilik kuyrukta
        // bırakıp bir sonraki bağlantı tetiklemesinde tekrar deniyoruz.
      }
    }
  }

  /// Fotoğrafı senkronize olmayı bekleyen kayıt sayısı (UI'da rozet için).
  int bekleyenSayisi() => _kutu?.length ?? 0;

  String _uzanti(String yol) {
    final nokta = yol.lastIndexOf('.');
    return nokta == -1 ? '.jpg' : yol.substring(nokta);
  }
}
