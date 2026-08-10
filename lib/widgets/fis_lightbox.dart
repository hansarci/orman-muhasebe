import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Geçmiş kayıtlardaki küçük fiş resmine tıklanınca açılan tam ekran görünüm.
void fisiBuyukGoster(BuildContext context, String fotoUrl) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.9),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: fotoUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
    ),
  );
}
