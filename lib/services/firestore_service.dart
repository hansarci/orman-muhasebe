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
/// olarak seçilir (bkz. _slug). Böylece "bu işletme zaten var mı" sorusu
/// bir Firestore SORGUSU gerektirmeden, doğrudan doc(id) ile cevaplanabiliyor.
///
/// ÖNEMLİ — offline çalışma: toplamları güncellerken bilerek Firestore
/// "transaction"ları KULLANILMIYOR. Transaction'lar sunucudan güncel veri
/// okumayı gerektirdiği için internet olmadan tamamen çalışmıyor (sonsuza
/// kadar bekliyor/başarısız oluyor). Bunun yerine `FieldValue.increment()`
/// kullanılıyor — bu, hem online hem offline çalışan, yerel önbelleğe
/// hemen yazılıp bağlantı gelince sunucuyla senkronize olan atomik bir
/// artırma/azaltma işlemi.
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
  /// ÖNEMLİ — "gönder ve unut" (fire-and-forget): belge ID'si zaten
  /// tamamen yerel olarak (ağa hiç değmeden) üretiliyor, bu yüzden onu
  /// senkron döndürüyoruz. `.set()` yazma işlemini BEKLEMİYORUZ —
  /// Firestore bunu kendi iç kuyruğuna alıp (internet olsun olmasın)
  /// arka planda tamamlıyor. Böylece UI hiçbir zaman "yazma bitene kadar"
  /// beklemek zorunda kalmıyor; sinyalsiz bir ormanda bile arayüz anında
  /// tepki veriyor.
  String bosIsOlustur({required String isAdi}) {
    final isRef = _islerRef.doc();
    // Bilerek await YOK — arka planda çalışsın.
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

  /// Bir işin altına yeni bir masraf kaydı ekler. İşletme daha önce yoksa
  /// otomatik oluşturulur, varsa toplamı artırılır.
  ///
  /// "Gönder ve unut": tüm ID'ler yerel olarak (ağa değmeden) üretiliyor,
  /// bu yüzden fonksiyon senkron dönüyor. Üç yazma işlemi de (`.set()`)
  /// BEKLENMİYOR — Firestore'un kendi kuyruğuna bırakılıyor, arka planda
  /// (internet olsun olmasın) tamamlanıyor. UI hiçbir zaman askıda kalmıyor.
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
      // Bağlantı yoksa (Source.server zaten offline'da hemen hata verir)
      // ya da gerekli Firestore index'i henüz oluşmadıysa sessizce vazgeç —
      // bir sonraki açılışta, bağlantı varken tekrar denenecek.
    }
  }
}
