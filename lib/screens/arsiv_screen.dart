import 'package:flutter/material.dart';
import '../models/is_model.dart';
import '../services/firestore_service.dart';
import '../services/photo_upload_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ortak_widgetlar.dart';
import '../widgets/yeni_is_modal.dart';
import 'is_detay_screen.dart';

/// Uygulamanın karşılama ekranı: tüm işlerin (Ballıdağ, Karaçam Yolu vb.)
/// listelendiği arşiv. Firestore boşsa liste de boş görünür — burada
/// hiçbir örnek/test kaydı oluşturulmaz.
class ArsivScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final PhotoUploadService photoUploadService;

  const ArsivScreen({
    super.key,
    required this.firestoreService,
    required this.photoUploadService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BORÇ KAYITLARI'),
      ),
      body: StreamBuilder<List<IsModel>>(
        stream: firestoreService.islerStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final isler = snapshot.data ?? [];

          if (isler.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz bir iş eklenmedi.\nSağ alttaki + butonuyla ilk işi oluşturabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.yaziSoluk),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: isler.length,
            itemBuilder: (context, index) {
              final is_ = isler[index];
              return KayitSatiri(
                isim: is_.isim,
                tutar: is_.toplam,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => IsDetayScreen(
                        isId: is_.id,
                        firestoreService: firestoreService,
                        photoUploadService: photoUploadService,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => yeniIsModalAc(
          context,
          firestoreService: firestoreService,
          photoUploadService: photoUploadService,
        ),
        child: const Text('+', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}
