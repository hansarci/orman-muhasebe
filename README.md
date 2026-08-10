# Orman Muhasebe — Flutter Uygulaması

Bu, sohbette birlikte tasarladığımız HTML mockup'ın (masraf-menu.html)
native Flutter karşılığıdır. Test/örnek veri (Motorcu, Benzinlik vb.)
YOKTUR — uygulama Firestore'dan tamamen boş başlar; ilk işi ve işletmeyi
sen ekleyeceksin.

## En hızlı yol: APK'yı GitHub Actions ile üret (kurulum YOK)

Bilgisayarına Flutter SDK, Android Studio falan kurmana gerek yok. Bu
proje `.github/workflows/build-apk.yml` dosyasını içeriyor — GitHub'a
yüklediğin an APK'yı otomatik üretiyor.

1. **GitHub'da ücretsiz hesap aç** (yoksa): github.com/join
2. **Yeni bir repo oluştur** — "New repository", isim ör. `orman-muhasebe`,
   "Public" veya "Private" fark etmez, "Create repository"
3. Repo sayfasında **"uploading an existing file"** linkine tıkla
4. Bu zip'in **içindeki tüm dosya ve klasörleri** (zip'in kendisini değil,
   içini açıp) oraya sürükle-bırak. "Commit changes" ile onayla.
5. Sol üstte **"Actions"** sekmesine geç — "APK Oluştur" workflow'u
   otomatik başlamış olacak (birkaç dakika sürer, sarı nokta dönerken
   bekle, yeşil tik olunca biter)
6. Bittiğinde workflow'a tıkla, en altta **"Artifacts"** kısmında
   `orman-muhasebe-apk` göreceksin — indir, zip'i aç, içindeki
   `app-release.apk` telefonuna kurabileceğin dosya

**Önemli:** Bu ilk APK, Firebase henüz bağlı olmadığı için açılınca
"Firebase henüz bağlanmadı" yazan basit bir ekran gösterecek — çökmez,
ama gerçek veri de göstermez. Firebase'i bağlamak için aşağıdaki adıma
geç.

## Firebase'i bağlama (gerçek verilerin akması için)

1. https://console.firebase.google.com üzerinden yeni bir proje oluştur
   (ya da Kutur M3/Orjanda'dakiyle aynı projeyi kullan)
2. Projeye bir **Android app** ekle, paket adı olarak tam şunu gir:
   `com.ormanmuhasebe.app`
3. İndirdiği **`google-services.json`** dosyasını, bu projenin
   `android/app/` klasörünün içine koy
4. Firestore Database'i ve Storage'ı Firebase konsolundan aç (Test Mode
   ile başlayabilirsin)
5. GitHub'a bu dosyayı da yükle (repo sayfasından `android/app/` klasörüne
   `google-services.json`'ı sürükle-bırak yapıp commit et — küçük/kişisel
   bir repo olduğu için bu kadarı yeterli, kurumsal bir üründe bu dosya
   genelde GitHub Secrets ile gizlenir)
6. GitHub Actions otomatik yeniden APK üretecek — Firebase bağlı yeni bir
   APK indirebilirsin

## Klasör yapısı

```
lib/
  models/           # IsModel, IsletmeModel, KayitModel, BekleyenFoto (Hive)
  services/
    firestore_service.dart      # Tüm CRUD — iş/işletme/kayıt üç seviyesi
    photo_upload_service.dart   # Offline fiş fotoğrafı yükleme kuyruğu
  screens/
    arsiv_screen.dart           # Ana sayfa — iş listesi
    is_detay_screen.dart        # Bir işin içindeki işletmeler
    isletme_detay_screen.dart   # Bir işletmenin borç geçmişi
  widgets/
    yeni_is_modal.dart          # Sağ alttaki + butonuyla açılan tam ekran panel
    fis_foto_secici.dart        # 📷 buton + önizleme (3 ekranda da ortak)
    fis_lightbox.dart           # Fişe tıklayınca tam ekran gösterme
    ortak_widgetlar.dart        # Liste satırı, toplam satırı, tarih/para format
  theme/
    app_theme.dart              # HTML mockup'taki renk paleti ve fontlar
  main.dart
android/              # Android'in kendi proje dosyaları (Gradle, Manifest vs.)
.github/workflows/
  build-apk.yml       # GitHub'a her yüklemede otomatik APK üretir
firestore.rules        # Başlangıç güvenlik kuralları (geliştirme için gevşek)
```

## Offline fiş fotoğrafı akışı — nasıl çalışıyor

1. Kullanıcı 📷 ile fotoğraf çeker → `KayitModel.fotoBekliyor = true` ile
   Firestore kaydı hemen oluşturulur (Firestore offline zaten kuyruğa alır).
2. Fotoğraf dosyası cihazın kalıcı dizinine kopyalanır ve bir Hive
   kutusuna ("bekleyenFotolar") kaydedilir.
3. `connectivity_plus` bağlantı geldiğini algıladığında, `PhotoUploadService`
   kuyruktaki tüm bekleyen fotoğrafları sırayla Firebase Storage'a yükler.
4. Her başarılı yüklemede ilgili Firestore kaydı `fotoUrl` ile güncellenir
   ve kuyruktan silinir.

## Notlar

- iOS klasörü (Xcode projesi) bu pakette YOK — şimdilik sadece Android/APK
  hedeflendi. iOS gerekirse ayrıca isteyebilirsin.
- Kimlik doğrulama (auth) eklenmedi — Kutur M3'teki gibi anonim girişle
  başlamak muhtemelen en hızlı yol.
- PDF dışa aktarma (muhasebeciye gönderme) henüz yok; Kutur M3'teki
  `pdfOlusturvePaylas` mantığı buraya da taşınabilir.
- Release APK şu an "debug" imza anahtarıyla derleniyor (test için
  yeterli); Play Store'a basmadan önce kendi imzalama anahtarını
  oluşturup `android/app/build.gradle` içindeki `signingConfig`'i
  güncellemen gerekir.

