import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/gelir_model.dart';
import '../models/is_model.dart';
import '../models/isci_kayit_model.dart';
import '../models/isci_model.dart';
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

  CollectionReference<Map<String, dynamic>> get _iscilerRef =>
      _db.collection('kullanicilar').doc(_uid).collection('iscilerdb');

  CollectionReference<Map<String, dynamic>> _isciKayitlarRef(String isciId) =>
      _iscilerRef.doc(isciId).collection('kayitlar');

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

  // ---------------------------------------------------------------------
  // İşçiler
  // ---------------------------------------------------------------------

  /// İşçi listesini canlı olarak dinler (isme göre sıralı).
  Stream<List<IsciModel>> iscilerStream() {
    return _iscilerRef
        .orderBy('isim')
        .snapshots()
        .map((snap) => snap.docs.map(IsciModel.fromFirestore).toList());
  }

  /// Yeni bir işçi ekler. "Gönder ve unut": ID yerel üretiliyor, yazma
  /// beklenmiyor — arayüz anında devam ediyor.
  String isciEkle({required String isim, required double gunlukUcret}) {
    final isciRef = _iscilerRef.doc();
    // ignore: unawaited_futures
    isciRef.set({
      'isim': isim,
      'gunlukUcret': gunlukUcret,
      'kazanc': 0,
    });
    return isciRef.id;
  }

  /// Aynı isimde işçi var mı diye bakar (Geçmiş Kayıt Ekle'de "yeni mi,
  /// var olana mı ekleniyor" ayrımı için). Tek seferlik bir sorgu.
  Future<IsciModel?> isciIsimleBul(String isim) async {
    final snap = await _iscilerRef.get();
    final eslesenler = snap.docs.map(IsciModel.fromFirestore).where(
          (i) => i.isim.trim().toLowerCase() == isim.trim().toLowerCase(),
        );
    return eslesenler.isEmpty ? null : eslesenler.first;
  }

  /// Bir işçinin geçmiş (borç/ödeme tarzı) hareket kayıtlarını canlı dinler.
  Stream<List<IsciKayitModel>> isciKayitlarStream(String isciId) {
    return _isciKayitlarRef(isciId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(IsciKayitModel.fromFirestore).toList());
  }

  /// PDF oluşturma gibi tek seferlik ihtiyaçlar için: bir işçinin
  /// kayıtlarını, canlı dinlemeden, bir kerelik (anlık görüntü) çeker.
  Future<List<IsciKayitModel>> isciKayitlariGetir(String isciId) async {
    final snap = await _isciKayitlarRef(isciId).orderBy('tarih', descending: true).get();
    return snap.docs.map(IsciKayitModel.fromFirestore).toList();
  }

  /// Bir işçiye tek bir günlük kayıt ekler — 'gelis' ise kazancı ARTIRIR,
  /// 'odeme' ise AZALTIR. "Gönder ve unut": yazmalar beklenmiyor.
  /// [tarih] verilmezse bugünün tarihi kullanılır (Geçmiş Kayıt Ekle'de
  /// geçmiş bir tarih verilir).
  void isciKayitEkle({
    required String isciId,
    required double tutar,
    required String tur,
    DateTime? tarih,
  }) {
    final isciRef = _iscilerRef.doc(isciId);
    final kayitRef = _isciKayitlarRef(isciId).doc();
    final etki = tur == 'odeme' ? -1 : 1;

    // ignore: unawaited_futures
    kayitRef.set(
      IsciKayitModel(
        id: kayitRef.id,
        tarih: tarih ?? DateTime.now(),
        tutar: tutar,
        tur: tur,
      ).toFirestore(),
    );

    // ignore: unawaited_futures
    isciRef.set(
      {'kazanc': FieldValue.increment(tutar * etki)},
      SetOptions(merge: true),
    );
  }

  /// Bir işçi için BUGÜN zaten bir "geldi" kaydı girilmiş mi diye bakar.
  /// Aynı satıra günde birden fazla kez tıklayıp yanlışlıkla defalarca
  /// hak ediş eklenmesini önlemek için kullanılıyor.
  Future<bool> isciBugunIsaretliMi(String isciId) async {
    final buGunBasi = DateTime.now();
    final gunBaslangici = DateTime(buGunBasi.year, buGunBasi.month, buGunBasi.day);
    final gunSonu = gunBaslangici.add(const Duration(days: 1));

    final snap = await _isciKayitlarRef(isciId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(gunBaslangici))
        .where('tarih', isLessThan: Timestamp.fromDate(gunSonu))
        .get();

    return snap.docs.any((doc) => doc.data()['tur'] == 'gelis');
  }

  /// Bir işçiyi ve tüm hareket kayıtlarını komple siler. Tamamen ödenmiş
  /// (kazanç sıfırlanmış) ve PDF'i gönderilmiş bir işçiyi listeden
  /// otomatik kaldırmak için kullanılıyor. Geri dönüşü yok, bu yüzden
  /// beklenip (fire-and-forget DEĞİL) her adımın tamamlandığından
  /// emin olunuyor.
  Future<void> isciSil(String isciId) async {
    final kayitlarSnap = await _isciKayitlarRef(isciId).get();

    // Silmeden önce, bu işçiye bugüne kadar ödenen toplamı kalıcı bir
    // sayaca ekliyoruz — böylece kayıtlar silinse de "Toplam Masraf"
    // istatistiğinden düşmüyor.
    double odenenToplam = 0;
    for (final kayitDoc in kayitlarSnap.docs) {
      final data = kayitDoc.data();
      if (data['tur'] == 'odeme') {
        odenenToplam += (data['tutar'] as num?)?.toDouble() ?? 0;
      }
    }
    if (odenenToplam > 0) {
      await _db.collection('kullanicilar').doc(_uid).set(
        {'silinenIscilereOdenenToplam': FieldValue.increment(odenenToplam)},
        SetOptions(merge: true),
      );
    }

    for (final kayitDoc in kayitlarSnap.docs) {
      await kayitDoc.reference.delete();
    }
    await _iscilerRef.doc(isciId).delete();
  }

  /// "Geçmiş Kayıt Ekle" özelliğinin gizli olup olmadığını canlı olarak
  /// dinler. Kullanıcı "artık ihtiyacım yok" deyip kalıcı olarak
  /// gizleyene kadar false (yani görünür) döner.
  Stream<bool> gecmisKayitGizliMi() {
    return _db.collection('kullanicilar').doc(_uid).snapshots().map(
          (doc) => doc.data()?['gecmisKayitGizli'] as bool? ?? false,
        );
  }

  /// "Geçmiş Kayıt Ekle" butonunu kalıcı olarak gizler. Tek seferlik bir
  /// veri aktarımı özelliği olduğu için, kullanıcı işini bitirdiğinde bir
  /// daha görmek istemeyebilir.
  Future<void> gecmisKayitOzelliginiGizle() async {
    await _db.collection('kullanicilar').doc(_uid).set(
      {'gecmisKayitGizli': true},
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------
  // Profil paneli — İstatistikler ve Hesabı Sil
  // ---------------------------------------------------------------------

  /// Profil panelindeki "İstatistikler" penceresi için: kullanıcının TÜM
  /// işleri üzerinden toplam kazanç, toplam masraf ve kârı hesaplar.
  /// Dönen map anahtarları: 'kazanc', 'masraf', 'kar'.
  Future<Map<String, double>> tumZamanIstatistikleriGetir() async {
    final islerSnap = await _islerRef.get();

    double toplamKazanc = 0;
    double toplamMasraf = 0;

    for (final isDoc in islerSnap.docs) {
      final isId = isDoc.id;

      final gelirlerSnap = await _gelirlerRef(isId).get();
      for (final gelirDoc in gelirlerSnap.docs) {
        toplamKazanc += (gelirDoc.data()['tutar'] as num?)?.toDouble() ?? 0;
      }

      final isletmelerSnap = await _isletmelerRef(isId).get();
      for (final isletmeDoc in isletmelerSnap.docs) {
        final kayitlarSnap = await _isletmelerRef(isId)
            .doc(isletmeDoc.id)
            .collection('kayitlar')
            .get();
        for (final kayitDoc in kayitlarSnap.docs) {
          final data = kayitDoc.data();
          final tur = data['tur'] as String? ?? 'borc';
          // Sadece borç kayıtları "yapılan masraf" sayılır — ödemeler,
          // zaten yapılmış bir masrafın kapatılması, yeni masraf değil.
          if (tur != 'odeme') {
            toplamMasraf += (data['tutar'] as num?)?.toDouble() ?? 0;
          }
        }
      }
    }

    // İşçilere ödenen paralar da masraf sayılır. Hâlâ listede duran
    // işçilerin ödeme kayıtları buradan toplanıyor; tamamen ödenip
    // listeden silinmiş eski işçilerin ödemeleri ise (kayıtları
    // silindiği için) kalıcı bir sayaçtan (bkz. isciSil) okunuyor.
    final iscilerSnap = await _iscilerRef.get();
    for (final isciDoc in iscilerSnap.docs) {
      final kayitlarSnap = await _isciKayitlarRef(isciDoc.id).get();
      for (final kayitDoc in kayitlarSnap.docs) {
        final data = kayitDoc.data();
        if (data['tur'] == 'odeme') {
          toplamMasraf += (data['tutar'] as num?)?.toDouble() ?? 0;
        }
      }
    }

    final kullaniciDoc = await _db.collection('kullanicilar').doc(_uid).get();
    toplamMasraf += (kullaniciDoc.data()?['silinenIscilereOdenenToplam'] as num?)?.toDouble() ?? 0;

    return {
      'kazanc': toplamKazanc,
      'masraf': toplamMasraf,
      'kar': toplamKazanc - toplamMasraf,
    };
  }

  /// "Hesabı Sil" onaylandığında çağrılır: kullanıcının TÜM Firestore
  /// verilerini (işler, işletmeler, kayıtlar, gelirler) ve Storage'daki
  /// fiş fotoğraflarını KOMPLE siler. Firebase Auth hesabının kendisini
  /// SİLMEZ — bu, FirebaseAuth.instance.currentUser.delete() ile ayrıca,
  /// çağıran arayüz (profil paneli) tarafından yapılmalı, çünkü o bir
  /// Auth işlemi, Firestore işlemi değil.
  ///
  /// Bilerek fire-and-forget DEĞİL — geri dönüşü olmayan bir işlem
  /// olduğu için her adımın gerçekten tamamlandığından emin olunuyor.
  Future<void> tumVerileriSil() async {
    final islerSnap = await _islerRef.get();

    for (final isDoc in islerSnap.docs) {
      final isId = isDoc.id;

      final isletmelerSnap = await _isletmelerRef(isId).get();
      for (final isletmeDoc in isletmelerSnap.docs) {
        final kayitlarRef = _isletmelerRef(isId).doc(isletmeDoc.id).collection('kayitlar');
        final kayitlarSnap = await kayitlarRef.get();

        for (final kayitDoc in kayitlarSnap.docs) {
          final fotoUrl = kayitDoc.data()['fotoUrl'] as String?;
          if (fotoUrl != null) {
            try {
              await FirebaseStorage.instance.refFromURL(fotoUrl).delete();
            } catch (_) {
              // Dosya zaten silinmiş olabilir — sorun değil, devam et.
            }
          }
          await kayitDoc.reference.delete();
        }
        await isletmeDoc.reference.delete();
      }

      final gelirlerSnap = await _gelirlerRef(isId).get();
      for (final gelirDoc in gelirlerSnap.docs) {
        await gelirDoc.reference.delete();
      }

      await isDoc.reference.delete();
    }

    final iscilerSnap = await _iscilerRef.get();
    for (final isciDoc in iscilerSnap.docs) {
      final kayitlarSnap = await _isciKayitlarRef(isciDoc.id).get();
      for (final kayitDoc in kayitlarSnap.docs) {
        await kayitDoc.reference.delete();
      }
      await isciDoc.reference.delete();
    }

    // isciSil'in yazdığı kalıcı "silinen işçilere ödenen" sayacını da
    // temizle — yoksa hesap sıfırlandıktan sonra bile eski bir rakam
    // istatistiklerde kalmaya devam eder.
    await _db.collection('kullanicilar').doc(_uid).set(
      {'silinenIscilereOdenenToplam': 0},
      SetOptions(merge: true),
    );
  }
}
