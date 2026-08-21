import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/gelir_model.dart';
import '../models/is_model.dart';
import '../models/isletme_model.dart';
import '../models/kayit_model.dart';
import 'firestore_service.dart';

/// Bir işin (ör. "Ballıdağ") tüm masraf dökümünü — altındaki her işletme
/// ve o işletmelerin borç/ödeme geçmişi, kazanç (gelir) kayıtları ve
/// otomatik hesaplanan Kazanılan/Toplam Masraf/Kâr özetiyle birlikte —
/// bir PDF'e döküp telefonun kendi paylaşım menüsüyle (WhatsApp, e-posta
/// vs.) paylaşır.
class PdfService {
  final FirestoreService _firestoreService;
  final _paraFormat = NumberFormat.decimalPattern('tr_TR');

  PdfService(this._firestoreService);

  Future<void> isiPdfOlarakPaylas(IsModel is_) async {
    final regularFontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final isletmeler = await _firestoreService.isletmeleriGetir(is_.id);
    final gelirler = await _firestoreService.gelirleriGetir(is_.id);

    // Her işletmenin kayıtlarını topluca çekiyoruz.
    final isletmeKayitlari = <IsletmeModel, List<KayitModel>>{};
    for (final isletme in isletmeler) {
      isletmeKayitlari[isletme] =
          await _firestoreService.kayitlariGetir(is_.id, isletme.id);
    }

    // Ödenen/kalan/masraf/kâr — hepsi GÜVENİLİR OLSUN diye kayıtların
    // kendisinden hesaplanıyor, saklanan "toplam" alanlarına güvenmiyoruz
    // (offline'da sapma ihtimaline karşı, işletme detayındaki aynı mantık).
    double genelOdenen = 0;
    double genelKalan = 0;
    for (final kayitlar in isletmeKayitlari.values) {
      for (final kayit in kayitlar) {
        if (kayit.odemeMi) {
          genelOdenen += kayit.tutar;
        } else {
          genelKalan += kayit.tutar;
        }
      }
    }
    genelKalan -= genelOdenen; // Kalan = toplam borç - ödenen.

    final kazanilan = gelirler.fold<double>(0, (t, g) => t + g.tutar);
    final toplamMasraf = genelOdenen + genelKalan;
    final kar = kazanilan - toplamMasraf;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _baslikOlustur(
          is_,
          boldFont,
          regularFont,
          genelOdenen: genelOdenen,
          genelKalan: genelKalan,
          kazanilan: kazanilan,
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          if (isletmeler.isEmpty)
            pw.Text('Bu işin altında henüz işletme eklenmedi.',
                style: pw.TextStyle(font: regularFont, fontSize: 11)),
          for (final isletme in isletmeler) ...[
            _isletmeBolumu(isletme, isletmeKayitlari[isletme] ?? [], regularFont, boldFont),
            pw.SizedBox(height: 16),
          ],
          if (gelirler.isNotEmpty) ...[
            _gelirBolumu(gelirler, regularFont, boldFont),
            pw.SizedBox(height: 16),
          ],
          _ozetBolumu(kazanilan, toplamMasraf, kar, regularFont, boldFont),
        ],
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              'Sayfa ${context.pageNumber} / ${context.pagesCount}  ·  Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_dosyaAdiTemizle(is_.isim)}_masraf_dokumu.pdf',
    );
  }

  pw.Widget _baslikOlustur(
    IsModel is_,
    pw.Font boldFont,
    pw.Font regularFont, {
    required double genelOdenen,
    required double genelKalan,
    required double kazanilan,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_turkceBuyukHarf(is_.isim), style: pw.TextStyle(font: boldFont, fontSize: 20)),
                pw.Text('Masraf Dökümü',
                    style: pw.TextStyle(font: regularFont, fontSize: 11, color: PdfColors.grey600)),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text('Toplam Ödenen Borç: ',
                        style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600)),
                    pw.Text('₺${_paraFormat.format(genelOdenen)}',
                        style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green700)),
                    pw.SizedBox(width: 20),
                    pw.Text('Toplam Kalan Borç: ',
                        style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600)),
                    pw.Text('₺${_paraFormat.format(genelKalan)}',
                        style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.red800)),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Kazanılan Para:',
                    style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey600)),
                pw.Text('₺${_paraFormat.format(kazanilan)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColors.green700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey400, thickness: 1),
      ],
    );
  }

  pw.Widget _isletmeBolumu(
    IsletmeModel isletme,
    List<KayitModel> kayitlar,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    final odenen = kayitlar.where((k) => k.odemeMi).fold<double>(0, (t, k) => t + k.tutar);
    final borcToplami = kayitlar.where((k) => !k.odemeMi).fold<double>(0, (t, k) => t + k.tutar);
    final kalan = borcToplami - odenen;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(isletme.isim, style: pw.TextStyle(font: boldFont, fontSize: 13)),
              pw.Row(
                children: [
                  pw.Text('Ödenen: ', style: pw.TextStyle(font: regularFont, fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text('₺${_paraFormat.format(odenen)}',
                      style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.green700)),
                  pw.SizedBox(width: 12),
                  pw.Text('Kalan: ', style: pw.TextStyle(font: regularFont, fontSize: 9.5, color: PdfColors.grey700)),
                  pw.Text('₺${_paraFormat.format(kalan)}',
                      style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.red800)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          if (kayitlar.isEmpty)
            pw.Text('Kayıt yok.',
                style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey600))
          else
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _hucre('Tarih', boldFont, baslikMi: true),
                    _hucre('Tür', boldFont, baslikMi: true),
                    _hucre('Tutar', boldFont, baslikMi: true, sagaYasli: true),
                  ],
                ),
                for (final kayit in kayitlar)
                  pw.TableRow(
                    children: [
                      _hucre(DateFormat('dd.MM.yyyy').format(kayit.tarih), regularFont),
                      _hucre(kayit.odemeMi ? 'Ödeme' : 'Borç', regularFont),
                      _hucre(
                        '${kayit.odemeMi ? '- ' : ''}₺${_paraFormat.format(kayit.tutar)}',
                        regularFont,
                        sagaYasli: true,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _gelirBolumu(List<GelirModel> gelirler, pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'KAZANÇ KAYITLARI',
          style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 6),
        for (final gelir in gelirler)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(DateFormat('dd.MM.yyyy').format(gelir.tarih),
                    style: pw.TextStyle(font: regularFont, fontSize: 10)),
                pw.Text('₺${_paraFormat.format(gelir.tutar)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green700)),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _ozetBolumu(
    double kazanilan,
    double toplamMasraf,
    double kar,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1.2)),
      ),
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          _ozetKalemi('Kazanılan:', kazanilan, PdfColors.orange800, regularFont, boldFont),
          _ozetKalemi('Toplam Masraf:', toplamMasraf, PdfColors.red800, regularFont, boldFont),
          _ozetKalemi('Kâr:', kar, PdfColors.green700, regularFont, boldFont),
        ],
      ),
    );
  }

  pw.Widget _ozetKalemi(
    String etiket,
    double tutar,
    PdfColor renk,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Text(etiket, style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text('₺${_paraFormat.format(tutar)}',
            style: pw.TextStyle(font: boldFont, fontSize: 15, color: renk)),
      ],
    );
  }

  pw.Widget _hucre(String metin, pw.Font font, {bool baslikMi = false, bool sagaYasli = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        metin,
        style: pw.TextStyle(font: font, fontSize: 9),
        textAlign: sagaYasli ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  String _dosyaAdiTemizle(String metin) {
    return metin
        .replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ-]'), '')
        .replaceAll(' ', '_');
  }

  /// Dart'ın standart `toUpperCase()`'i Türkçe'ye uygun değil — "Eflani"
  /// gibi kelimelerdeki noktalı küçük "i"yi yanlışlıkla noktasız "I" yapıp
  /// "EFLANI" yerine "EFLANI" değil "EFLANİ" olması gerekirken "Efanı" gibi
  /// bozuk sonuçlar üretebiliyor. Bu, uygulama ekranlarında kullanılan
  /// turkceBuyukHarf() ile aynı düzeltmenin PDF tarafındaki karşılığı.
  String _turkceBuyukHarf(String metin) {
    return metin.replaceAll('i', 'İ').toUpperCase();
  }
}
