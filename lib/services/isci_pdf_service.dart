import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/isci_model.dart';
import '../services/firestore_service.dart';

/// Bir işçinin tarihli ödeme dökümünü (geldiği günler + aldığı ödemeler +
/// Toplam Hak Ediş / Toplam Ödenen / Kalan özeti) PDF'e döküp telefonun
/// paylaşım menüsüyle (WhatsApp dahil) paylaşır.
class IsciPdfService {
  final FirestoreService _firestoreService;
  final _paraFormat = NumberFormat.decimalPattern('tr_TR');

  IsciPdfService(this._firestoreService);

  Future<void> isciyiPdfOlarakPaylas(IsciModel isci) async {
    final regularFontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final kayitlar = await _firestoreService.isciKayitlariGetir(isci.id);

    double toplamHakedis = 0;
    double toplamOdenen = 0;
    for (final k in kayitlar) {
      if (k.gelisMi) {
        toplamHakedis += k.tutar;
      } else {
        toplamOdenen += k.tutar;
      }
    }
    final kalan = toplamHakedis - toplamOdenen;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_turkceBuyukHarf(isci.isim), style: pw.TextStyle(font: boldFont, fontSize: 20)),
            pw.Text('İşçi Ödeme Dökümü',
                style: pw.TextStyle(font: regularFont, fontSize: 11, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          if (kayitlar.isEmpty)
            pw.Text('Henüz kayıt yok.', style: pw.TextStyle(font: regularFont, fontSize: 11))
          else
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2.4),
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
                      _hucre(
                        kayit.gelisMi ? 'Geldi (Hak ediş)' : 'Ödeme',
                        regularFont,
                        renk: kayit.gelisMi ? PdfColors.orange800 : PdfColors.green700,
                      ),
                      _hucre(
                        '${kayit.gelisMi ? '' : '- '}₺${_paraFormat.format(kayit.tutar)}',
                        regularFont,
                        sagaYasli: true,
                      ),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 18),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1.2)),
            ),
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _ozetKalemi('Toplam Hak Ediş', toplamHakedis, PdfColors.orange800, regularFont, boldFont),
                _ozetKalemi('Toplam Ödenen', toplamOdenen, PdfColors.green700, regularFont, boldFont),
                _ozetKalemi('Kalan', kalan, PdfColors.red800, regularFont, boldFont),
              ],
            ),
          ),
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
      filename: '${_dosyaAdiTemizle(isci.isim)}_odeme_dokumu.pdf',
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

  pw.Widget _hucre(
    String metin,
    pw.Font font, {
    bool baslikMi = false,
    bool sagaYasli = false,
    PdfColor? renk,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        metin,
        style: pw.TextStyle(font: font, fontSize: 9, color: renk),
        textAlign: sagaYasli ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  String _dosyaAdiTemizle(String metin) {
    return metin.replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ-]'), '').replaceAll(' ', '_');
  }

  String _turkceBuyukHarf(String metin) {
    return metin.replaceAll('i', 'İ').toUpperCase();
  }
}
