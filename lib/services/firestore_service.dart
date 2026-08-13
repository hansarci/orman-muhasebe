import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/is_model.dart';
import '../models/isletme_model.dart';
import '../models/kayit_model.dart';

/// Yeni oluşturulan bir kaydın üç seviyeli kimliği. Fotoğraf varsa,
/// çağıran taraf (ekran) bunu PhotoUploadService.kuyrugaEkle'ye geçirir.
class KayitKimlikleri {
  final String isId;
  final String isletmeId;
  final String kayitId;

  const KayitKimlikleri({
    required this.isId,
    required this.isletmeId,
    required this.kayitId,
  });
}

/// Tüm Firestore okuma/yazma işlemlerini tek yerde toplayan servis.
///
/// Veri yapısı, HTML mockup'ta üzerinde uzlaşılan üç seviyeli hiyerarşiyi
/// birebir yansıtır:
///   isler/{isId}
///     isletmeler/{isletmeId}
///       kayitlar/{kayitId}
///
/// Not: İşletme belgesinin ID'si, işletme adından türetilen bir "slug"
/// olarak seçilir (bkz. _slug). Bu sayede "aynı isimde işletme var mı"
/// sorusunu bir Firestore SORGUSU yerine doğrudan doc(id) ile cevaplayıp
/// transaction içinde güvenle kullanabiliyoruz — Firestore transaction'ları
/// sorgu tabanlı okumaları desteklemez, sadece belirli belge referanslarını
/// okuyabilir.
///
/// Firestore'un offline persistence'ı varsayılan olarak açıktır; bu
/// sayede internet olmayan alanlarda da okuma/yazma çalışır ve bağlantı
/// gelince otomatik senkronize olur. (Fotoğraflar için ayrı bir kuyruk
/// gerekiyor — bkz. photo_upload_service.dart)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _islerRef =>
      _db.collection('isler');

  CollectionReference<Map<String, dynamic>> _isletmelerRef(String isId) =>
      _islerRef.doc(isId).collection('isletmeler');

  /// "Motorcu " -> "motorcu", "Kara Çam Yolu" -> "kara-cam-yolu" gibi basit
  /// bir slug üretir. Türkçe karakterleri sadeleştirir.
  String _slug(String metin) {
    final tr = {
      'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'I': 'i',
      'İ': 'i', 'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
    };
    var sonuc = metin.trim().toLowerCase();
    tr.forEach((k, v) => sonuc = sonuc.replaceAll(k, v));
    sonuc = sonuc.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    sonuc = sonuc.replaceAll(RegExp(r'^-+|-+$'), '');
    return sonuc.isEmpty ? 'x' : sonuc;
  }

  // ---------------------------------------------------------------------
  // İş (1. seviye) — Ana sayfa / arşiv
  // ---------------------------------------------------------------------

  /// Ana sayfadaki iş listesini canlı olarak dinler (en yeni en üstte).
  Stream<List<IsModel>> islerStream() {
    return _islerRef
        .orderBy('olusturulmaTarihi', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(IsModel.fromFirestore).toList());
  }

  Stream<IsModel> isStream(String isId) {
    return _islerRef.doc(isId).snapshots().map(IsModel.fromFirestore);
  }

  /// Yeni bir iş oluşturur ve içine ilk işletme+tutar kaydını ekler.
  /// "Masraf kaydı oluştur" panelindeki akışın karşılığıdır.
  Future<KayitKimlikleri> yeniIsOlustur({
    required String isAdi,
    required String isletmeAdi,
    required double tutar,
    String? yerelFotoYolu,
  }) async {
    final isRef = _islerRef.doc();
    await isRef.set(
      IsModel(
        id: isRef.id,
        isim: isAdi,
        toplam: 0,
        olusturulmaTarihi: DateTime.now(),
      ).toFirestore(),
    );

    return isletmeyeKayitEkle(
      isId: isRef.id,
      isletmeAdi: isletmeAdi,
      tutar: tutar,
      yerelFotoYolu: yerelFotoYolu,
    );
  }

  /// "İşi Başlat" panelindeki yeni akışın karşılığı — sadece iş adıyla,
  /// hiç işletme/tutar olmadan boş bir iş açar. İşletmeler daha sonra
  /// iş detay ekranından tek tek eklenir. Oluşturulan işin ID'sini
  /// döndürür (detay sayfasına yönlendirmek için).
  Future<String> bosIsOlustur({required String isAdi}) async {
    final isRef = _islerRef.doc();
    await isRef.set(
      IsModel(
        id: isRef.id,
        isim: isAdi,
        toplam: 0,
        olusturulmaTarihi: DateTime.now(),
      ).toFirestore(),
    );
    return isRef.id;
  }

  // ---------------------------------------------------------------------
  // İşletme (2. seviye) — İş detayı içindeki işletme listesi
  // ---------------------------------------------------------------------

  /// Bir işin altındaki işletmeleri canlı olarak dinler.
  Stream<List<IsletmeModel>> isletmelerStream(String isId) {
    return _isletmelerRef(isId)
        .orderBy('isim')
        .snapshots()
        .map((snap) => snap.docs.map(IsletmeModel.fromFirestore).toList());
  }

  /// Bir işin altına yeni bir masraf kaydı ekler. İşletme daha önce yoksa
  /// otomatik oluşturulur, varsa toplamı güncellenir. İşletme ID'si adından
  /// türetildiği (slug) için sorguya gerek kalmadan transaction içinde
  /// doğrudan doc(id) ile güvenle okunup yazılabiliyor.
  Future<KayitKimlikleri> isletmeyeKayitEkle({
    required String isId,
    required String isletmeAdi,
    required double tutar,
    String? yerelFotoYolu,
  }) async {
    final isletmeId = _slug(isletmeAdi);
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    await _db.runTransaction((tx) async {
      final isletmeSnap = await tx.get(isletmeRef);
      final isSnap = await tx.get(isRef);

      final mevcutIsletmeToplam =
          isletmeSnap.exists ? (isletmeSnap.data()!['toplam'] as num).toDouble() : 0.0;
      final mevcutIsToplam =
          isSnap.exists ? (isSnap.data()!['toplam'] as num).toDouble() : 0.0;

      tx.set(
        isletmeRef,
        IsletmeModel(id: isletmeId, isim: isletmeAdi, toplam: mevcutIsletmeToplam + tutar)
            .toFirestore(),
      );

      tx.set(
        kayitRef,
        KayitModel(
          id: kayitRef.id,
          tutar: tutar,
          tarih: DateTime.now(),
          fotoBekliyor: yerelFotoYolu != null,
        ).toFirestore(),
      );

      tx.update(isRef, {'toplam': mevcutIsToplam + tutar});
    });

    return KayitKimlikleri(isId: isId, isletmeId: isletmeId, kayitId: kayitRef.id);
  }

  // ---------------------------------------------------------------------
  // Kayıt (3. seviye) — İşletme detayındaki borç geçmişi
  // ---------------------------------------------------------------------

  Stream<List<KayitModel>> kayitlarStream(String isId, String isletmeId) {
    return _isletmelerRef(isId)
        .doc(isletmeId)
        .collection('kayitlar')
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(KayitModel.fromFirestore).toList());
  }

  /// Zaten bilinen bir işletmeye (işletme detay ekranındaki "Borç ekle")
  /// yeni bir kayıt ekler.
  Future<KayitKimlikleri> borcEkle({
    required String isId,
    required String isletmeId,
    required double tutar,
    String? yerelFotoYolu,
  }) async {
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    await _db.runTransaction((tx) async {
      final isletmeSnap = await tx.get(isletmeRef);
      final isSnap = await tx.get(isRef);

      final isletmeToplam = (isletmeSnap.data()!['toplam'] as num).toDouble();
      final isToplam = (isSnap.data()!['toplam'] as num).toDouble();

      tx.set(
        kayitRef,
        KayitModel(
          id: kayitRef.id,
          tutar: tutar,
          tarih: DateTime.now(),
          fotoBekliyor: yerelFotoYolu != null,
        ).toFirestore(),
      );

      tx.update(isletmeRef, {'toplam': isletmeToplam + tutar});
      tx.update(isRef, {'toplam': isToplam + tutar});
    });

    return KayitKimlikleri(isId: isId, isletmeId: isletmeId, kayitId: kayitRef.id);
  }

  /// İşletme detayındaki "Ödeme Yap" — borcEkle'nin tersi: toplamı ARTIRMAK
  /// yerine DÜŞÜRÜR, kaydı tur:'odeme' olarak işaretler.
  Future<KayitKimlikleri> odemeEkle({
    required String isId,
    required String isletmeId,
    required double tutar,
  }) async {
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    await _db.runTransaction((tx) async {
      final isletmeSnap = await tx.get(isletmeRef);
      final isSnap = await tx.get(isRef);

      final isletmeToplam = (isletmeSnap.data()!['toplam'] as num).toDouble();
      final isToplam = (isSnap.data()!['toplam'] as num).toDouble();

      tx.set(
        kayitRef,
        KayitModel(
          id: kayitRef.id,
          tutar: tutar,
          tarih: DateTime.now(),
          tur: 'odeme',
        ).toFirestore(),
      );

      tx.update(isletmeRef, {'toplam': isletmeToplam - tutar});
      tx.update(isRef, {'toplam': isToplam - tutar});
    });

    return KayitKimlikleri(isId: isId, isletmeId: isletmeId, kayitId: kayitRef.id);
  }

  /// Bir kaydın tutarını değiştirir; işletme ve iş toplamlarını farka göre
  /// günceller. Ödeme kayıtlarında etki ters (toplamı düşürücü) yönde olur.
  Future<void> kayitDuzenle({
    required String isId,
    required String isletmeId,
    required String kayitId,
    required double eskiTutar,
    required double yeniTutar,
    required String tur,
  }) async {
    if (yeniTutar == eskiTutar) return;

    final etki = tur == 'odeme' ? -1 : 1;
    final fark = (yeniTutar - eskiTutar) * etki;

    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc(kayitId);

    await _db.runTransaction((tx) async {
      final isletmeSnap = await tx.get(isletmeRef);
      final isSnap = await tx.get(isRef);
      final isletmeToplam = (isletmeSnap.data()!['toplam'] as num).toDouble();
      final isToplam = (isSnap.data()!['toplam'] as num).toDouble();

      tx.update(kayitRef, {'tutar': yeniTutar});
      tx.update(isletmeRef, {'toplam': isletmeToplam + fark});
      tx.update(isRef, {'toplam': isToplam + fark});
    });
  }

  /// Bir kaydı siler; o kaydın işletme/iş toplamlarına yaptığı etkiyi geri
  /// alır (borç kaydıysa toplamdan düşer, ödeme kaydıysa toplama eklenir).
  Future<void> kayitSil({
    required String isId,
    required String isletmeId,
    required String kayitId,
    required double tutar,
    required String tur,
  }) async {
    final etki = tur == 'odeme' ? -1 : 1;
    final geriAl = -(tutar * etki);

    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc(kayitId);

    await _db.runTransaction((tx) async {
      final isletmeSnap = await tx.get(isletmeRef);
      final isSnap = await tx.get(isRef);
      final isletmeToplam = (isletmeSnap.data()!['toplam'] as num).toDouble();
      final isToplam = (isSnap.data()!['toplam'] as num).toDouble();

      tx.delete(kayitRef);
      tx.update(isletmeRef, {'toplam': isletmeToplam + geriAl});
      tx.update(isRef, {'toplam': isToplam + geriAl});
    });
  }

  /// Fotoğraf yüklendikten sonra (bkz. PhotoUploadService) kaydın
  /// fotoUrl / fotoBekliyor alanlarını günceller.
  Future<void> kayitFotoGuncelle({
    required String isId,
    required String isletmeId,
    required String kayitId,
    required String fotoUrl,
  }) async {
    await _isletmelerRef(isId)
        .doc(isletmeId)
        .collection('kayitlar')
        .doc(kayitId)
        .update({'fotoUrl': fotoUrl, 'fotoBekliyor': false});
  }

  /// 1 yıldan eski kayıtların FİŞ FOTOĞRAFLARINI Storage'dan siler.
  /// Kaydın kendisi (tutar, tarih, işletme) HİÇ SİLİNMEZ — sadece görsel
  /// kaldırılır ve fotoUrl alanı boşaltılır. Uygulama açılışında bir kere
  /// çağrılması yeterli; sessizce çalışır, hata olursa yutar (kritik değil).
  Future<void> eskiFisleriTemizle() async {
    try {
      final esikTarih = DateTime.now().subtract(const Duration(days: 365));

      final sorguSonucu = await _db
          .collectionGroup('kayitlar')
          .where('tarih', isLessThan: Timestamp.fromDate(esikTarih))
          .get();

      for (final belge in sorguSonucu.docs) {
        final data = belge.data();
        final fotoUrl = data['fotoUrl'] as String?;
        if (fotoUrl == null) continue; // Zaten fotoğrafı yok, atla.

        try {
          await FirebaseStorage.instance.refFromURL(fotoUrl).delete();
        } catch (_) {
          // Storage'da dosya zaten silinmiş olabilir — yine de Firestore
          // tarafını temizlemeye devam ediyoruz.
        }

        await belge.reference.update({'fotoUrl': null, 'fotoBekliyor': false});
      }
    } catch (e) {
      // Bağlantı yoksa ya da gerekli Firestore index'i henüz oluşmadıysa
      // sessizce vazgeç — bir sonraki açılışta tekrar denenecek.
    }
  }
}
