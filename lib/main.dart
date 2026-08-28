import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/arsiv_screen.dart';
import 'screens/giris_screen.dart';
import 'services/firestore_service.dart';
import 'services/photo_upload_service.dart';
import 'theme/app_theme.dart';
// import 'firebase_options.dart'; // `flutterfire configure` ile üretilir.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive, fotoğraf kuyruğu (PhotoUploadService) tarafından kullanılıyor.
  await Hive.initFlutter();

  bool firebaseHazir = true;
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform,
    );

    // Offline-first: Firestore'a açıkça "internet olmadan da çalış" ayarı.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    firebaseHazir = false;
    debugPrint('Firebase henüz bağlanmadı: $e');
  }

  await initializeDateFormatting('tr_TR', null);

  final firestoreService = FirestoreService();
  final photoUploadService = PhotoUploadService(firestoreService);
  if (firebaseHazir) {
    try {
      await photoUploadService.baslat();
    } catch (e) {
      debugPrint('Fotoğraf kuyruğu başlatılamadı: $e');
    }
    // ignore: unawaited_futures
    firestoreService.eskiFisleriTemizle();
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
      home: !firebaseHazir
          ? const _FirebaseBaglanmadiEkrani()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final kullanici = snapshot.data;
                if (kullanici == null) {
                  return const GirisScreen();
                }

                return ArsivScreen(
                  firestoreService: firestoreService,
                  photoUploadService: photoUploadService,
                );
              },
            ),
    );
  }
}

class _FirebaseBaglanmadiEkrani extends StatelessWidget {
  const _FirebaseBaglanmadiEkrani();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Firebase henüz bağlanmadı.\ngoogle-services.json dosyasının doğru yerde olduğundan emin ol.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.yaziSoluk),
          ),
        ),
      ),
    );
  }
}
