import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/arsiv_screen.dart';
import 'services/firestore_service.dart';
import 'services/photo_upload_service.dart';
import 'theme/app_theme.dart';
// import 'firebase_options.dart'; // `flutterfire configure` ile üretilir.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase henüz bağlanmadıysa (google-services.json / firebase_options.dart
  // eksikse) uygulama çökmesin diye deneme-yakalama ile sarmalanıyor.
  // Firebase bağlanana kadar ekranlar açılır ama veri gelmez.
  bool firebaseHazir = true;
  try {
    await Firebase.initializeApp(
      // `flutterfire configure` komutunu çalıştırdığınızda otomatik oluşan
      // firebase_options.dart dosyasındaki DefaultFirebaseOptions.currentPlatform
      // değerini buraya verin:
      // options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    firebaseHazir = false;
    debugPrint('Firebase henüz bağlanmadı: $e');
  }

  await initializeDateFormatting('tr_TR', null);

  final firestoreService = FirestoreService();
  final photoUploadService = PhotoUploadService(firestoreService);
  if (firebaseHazir) {
    await photoUploadService.baslat();
  }

  runApp(OrmanMuhasebeApp(
    firestoreService: firestoreService,
    photoUploadService: photoUploadService,
    firebaseHazir: firebaseHazir,
  ));
}

class OrmanMuhasebeApp extends StatelessWidget {
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;
  final bool firebaseHazir;

  const OrmanMuhasebeApp({
    super.key,
    required this.firestoreService,
    required this.photoUploadService,
    required this.firebaseHazir,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orman Muhasebe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.tema,
      home: firebaseHazir
          ? ArsivScreen(
              firestoreService: firestoreService,
              photoUploadService: photoUploadService,
            )
          : const _FirebaseBaglanmadiEkrani(),
    );
  }
}

/// Firebase henüz bağlanmadıysa gösterilen basit uyarı ekranı — uygulama
/// çökmek yerine bunu gösterir. Firebase bağlanınca normal akışa döner.
class _FirebaseBaglanmadiEkrani extends StatelessWidget {
  const _FirebaseBaglanmadiEkrani();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Firebase henüz bağlanmadı.\n\n'
            'flutterfire configure çalıştırılıp firebase_options.dart '
            'oluşturulduktan sonra main.dart içindeki ilgili satırın '
            'yorumu kaldırılmalı.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
