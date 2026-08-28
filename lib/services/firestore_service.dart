import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/gelir_model.dart';
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
/// Veri yapısı — HER KULLANICININ KENDİ VERİSİ olacak şekilde, giriş
/// yapan kullanıcının UID'si altında saklanıyor:
///   kullanicilar/{uid}/isler/{isId}
///     isletmeler/{isletmeId}
///       kayitlar/{kayitId}
///     gelirler/{gelirId}
///
/// Not: İşletme belgesinin ID'si, işletme adından türetilen bir "slug"
/// olarak seçilir (bkz. _slug). Böylece "bu işletme zaten var mı" sorusu
/// bir Firestore SORGUSU gerektirmeden, doğrudan doc(id) ile cevaplanabiliyor.
///
/// ÖNEMLİ — offline çalışma: toplamları güncellerken bilerek Firestore
/// "transaction"ları KULLANILMIYOR. Transaction'lar sunucudan güncel veri
/// okumayı gerektirdiği için internet olmadan tamamen çalışmıyor. Bunun
/// yerine `FieldValue.increment()` ve "gönder ve unut" (fire-and-forget)
/// yazma kullanılıyor — ID'ler yerel üretiliyor, `.set()`/`.update()`
/// çağrıları BEKLENMİYOR, arayüz hiçbir zaman ağ/Firestore cevabını
/// beklemek zorunda kalmıyor.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Giriş yapan kullanıcının UID'si. Giriş yapılmadan bu servisin
  /// kullanılmaması gerekir (main.dart, giriş yapılmadan ArsivScreen'i
  /// hiç açmıyor) — yine de bir güvenlik önlemi olarak burada kontrol var.
  String get _uid {
    final kullanici = _auth.currentUser;
    if (kullanici == null) {
      throw StateError('FirestoreService kullanılmadan önce giriş yapılmalı.');
    }
    return kullanici.uid;
  }

  CollectionReference<Map<String, dynamic>> get _islerRef =>
      _db.collection('kullanicilar').doc(_uid).collection('isler');

  CollectionReference<Map<String, dynamic>> _isletmelerRef(String isId) =>
      _islerRef.doc(isId).collection('isletmeler');

  CollectionReference<Map<String, dynamic>> _gelirlerRef(String isId) =>
      _islerRef.doc(isId).collection('gelirler');

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

  /// "İşi Başlat" panelindeki akışın karşılığı — sadece iş adıyla, hiç
  /// işletme/tutar olmadan boş bir iş açar. İşletmeler daha sonra iş
  /// detay ekranından tek tek eklenir. Oluşturulan işin ID'sini döndürür.
  ///
  /// "Gönder ve unut": ID yerel üretiliyor, yazma beklenmiyor.
  String bosIsOlustur({required String isAdi}) {
    final isRef = _islerRef.doc();
    // ignore: unawaited_futures
    isRef.set(
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

  /// PDF oluşturma gibi tek seferlik ihtiyaçlar için: bir işin altındaki
  /// işletmeleri, canlı dinlemeden, bir kerelik (anlık görüntü) çeker.
  Future<List<IsletmeModel>> isletmeleriGetir(String isId) async {
    final snap = await _isletmelerRef(isId).orderBy('isim').get();
    return snap.docs.map(IsletmeModel.fromFirestore).toList();
  }

  /// PDF oluşturma gibi tek seferlik ihtiyaçlar için: bir işletmenin
  /// kayıtlarını, canlı dinlemeden, bir kerelik (anlık görüntü) çeker.
  Future<List<KayitModel>> kayitlariGetir(String isId, String isletmeId) async {
    final snap = await _isletmelerRef(isId)
        .doc(isletmeId)
        .collection('kayitlar')
        .orderBy('tarih', descending: true)
        .get();
    return snap.docs.map(KayitModel.fromFirestore).toList();
  }

  /// Bir işin altına yeni bir masraf kaydı ekler. İşletme daha önce yoksa
  /// otomatik oluşturulur, varsa toplamı artırılır.
  ///
  /// "Gönder ve unut": tüm ID'ler yerel olarak üretiliyor, bu yüzden
  /// fonksiyon senkron dönüyor. Üç yazma işlemi de BEKLENMİYOR.
  KayitKimlikleri isletmeyeKayitEkle({
    required String isId,
    required String isletmeAdi,
    required double tutar,
    String? yerelFotoYolu,
  }) {
    final isletmeId = _slug(isletmeAdi);
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    // ignore: unawaited_futures
    isletmeRef.set(
      {
        'isim': isletmeAdi,
        'toplam': FieldValue.increment(tutar),
      },
      SetOptions(merge: true),
    );

    // ignore: unawaited_futures
    kayitRef.set(
      KayitModel(
        id: kayitRef.id,
        tutar: tutar,
        tarih: DateTime.now(),
        tur: 'borc',
        fotoBekliyor: yerelFotoYolu != null,
      ).toFirestore(),
    );

    // ignore: unawaited_futures
    isRef.set(
      {'toplam': FieldValue.increment(tutar)},
      SetOptions(merge: true),
    );

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
  /// yeni bir kayıt ekler. Gönder-ve-unut mantığı yukarıdakiyle aynı.
  KayitKimlikleri borcEkle({
    required String isId,
    required String isletmeId,
    required double tutar,
    String? yerelFotoYolu,
  }) {
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    // ignore: unawaited_futures
    kayitRef.set(
      KayitModel(
        id: kayitRef.id,
        tutar: tutar,
        tarih: DateTime.now(),
        tur: 'borc',
        fotoBekliyor: yerelFotoYolu != null,
      ).toFirestore(),
    );

    // ignore: unawaited_futures
    isletmeRef.set(
      {'toplam': FieldValue.increment(tutar)},
      SetOptions(merge: true),
    );
    // ignore: unawaited_futures
    isRef.set(
      {'toplam': FieldValue.increment(tutar)},
      SetOptions(merge: true),
    );

    return KayitKimlikleri(isId: isId, isletmeId: isletmeId, kayitId: kayitRef.id);
  }

  /// İşletme detayındaki "Ödeme Yap" — borcEkle'nin tersi: toplamı ARTIRMAK
  /// yerine DÜŞÜRÜR, kaydı tur:'odeme' olarak işaretler. Gönder-ve-unut.
  KayitKimlikleri odemeEkle({
    required String isId,
    required String isletmeId,
    required double tutar,
  }) {
    final isletmeRef = _isletmelerRef(isId).doc(isletmeId);
    final isRef = _islerRef.doc(isId);
    final kayitRef = isletmeRef.collection('kayitlar').doc();

    // ignore: unawaited_futures
    kayitRef.set(
      KayitModel(
        id: kayitRef.id,
        tutar: tutar,
        tarih: DateTime.now(),
        tur: 'odeme',
      ).toFirestore(),
    );

    // ignore: unawaited_futures
    isletmeRef.set(
      {'toplam': FieldValue.increment(-tutar)},
      SetOptions(merge: true),
    );
    // ignore: unawaited_futures
    isRef.set(
      {'toplam': FieldValue.increment(-tutar)},
      SetOptions(merge: true),
    );

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

    await kayitRef.update({'tutar': yeniTutar});
    await isletmeRef.set(
      {'toplam': FieldValue.increment(fark)},
      SetOptions(merge: true),
    );
    await isRef.set(
      {'toplam': FieldValue.increment(fark)},
      SetOptions(merge: true),
    );
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

    await kayitRef.delete();
    await isletmeRef.set(
      {'toplam': FieldValue.increment(geriAl)},
      SetOptions(merge: true),
    );
    await isRef.set(
      {'toplam': FieldValue.increment(geriAl)},
      SetOptions(merge: true),
    );
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
  /// İnternet yoksa da hata vermez, sadece bir sonraki açılışta tekrar dener.
  Future<void> eskiFisleriTemizle() async {
    try {
      final esikTarih = DateTime.now().subtract(const Duration(days: 365));

      final sorguSonucu = await _db
          .collectionGroup('kayitlar')
          .where('tarih', isLessThan: Timestamp.fromDate(esikTarih))
          .get(const GetOptions(source: Source.server));

      for (final belge in sorguSonucu.docs) {
        final data = belge.data();
        final fotoUrl = data['fotoUrl'] as String?;
        if (fotoUrl == null) continue;

        try {
          await FirebaseStorage.instance.refFromURL(fotoUrl).delete();
        } catch (_) {
          // Storage'da dosya zaten silinmiş olabilir.
        }

        await belge.reference.update({'fotoUrl': null, 'fotoBekliyor': false});
      }
    } catch (e) {
      // Bağlantı yoksa ya da index henüz oluşmadıysa sessizce vazgeç.
    }
  }

  // ---------------------------------------------------------------------
  // Gelir (kazanç) — Arşivdeki iş satırına uzun basınca "Kazanç ekle"
  // ---------------------------------------------------------------------

  /// Bir işe yeni bir kazanç (gelir) kaydı ekler. Her giriş ayrı, tarihli
  /// bir belge — PDF ve ekranlar toplamı her zaman bu kayıtların
  /// kendisinden hesaplıyor. "Gönder ve unut": ID yerel üretiliyor.
  String gelirEkle({required String isId, required double tutar}) {
    final gelirRef = _gelirlerRef(isId).doc();
    // ignore: unawaited_futures
    gelirRef.set(
      GelirModel(id: gelirRef.id, tutar: tutar, tarih: DateTime.now()).toFirestore(),
    );
    return gelirRef.id;
  }

  /// Bir işin kazanç kayıtlarını canlı olarak dinler (en yeni en üstte).
  Stream<List<GelirModel>> gelirlerStream(String isId) {
    return _gelirlerRef(isId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(GelirModel.fromFirestore).toList());
  }

  /// PDF oluşturma gibi tek seferlik ihtiyaçlar için: bir işin kazanç
  /// kayıtlarını, canlı dinlemeden, bir kerelik (anlık görüntü) çeker.
  Future<List<GelirModel>> gelirleriGetir(String isId) async {
    final snap = await _gelirlerRef(isId).orderBy('tarih', descending: true).get();
    return snap.docs.map(GelirModel.fromFirestore).toList();
  }
}
