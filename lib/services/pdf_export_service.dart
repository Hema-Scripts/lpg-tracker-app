// lib/services/pdf_export_service.dart
//
// Exports cylinder booking history to a PDF file stored locally on device.
// No cloud upload — pure local storage.

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/cylinder_booking.dart';
import 'database_service.dart';

class PdfExportService {
  final _db = DatabaseService();
  final _fmt = DateFormat('d MMM yyyy');
  final _fmtFull = DateFormat('d MMM yyyy, h:mm a');

  static const _orange = PdfColor.fromInt(0xFFE8581A);
  static const _lightOrange = PdfColor.fromInt(0xFFFFF0E8);
  static const _green = PdfColor.fromInt(0xFF1A9E5F);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F0);

  /// Generate and save PDF. Returns file path.
  Future<String> exportHistory() async {
    final bookings = await _db.getAllBookings();
    final totalSpent = await _db.getTotalSpent();
    final delivered = bookings.where((b) => b.status == BookingStatus.delivered).toList();

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ctx),
      footer: (ctx) => _buildFooter(ctx),
      build: (ctx) => [
        _buildSummarySection(delivered.length, totalSpent),
        pw.SizedBox(height: 20),
        _buildBookingsTable(bookings),
        pw.SizedBox(height: 20),
        _buildPrivacyNote(),
      ],
    ));

    // Save to Downloads
    final dir = await getExternalStorageDirectory();
    final downloadsPath = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('$downloadsPath/lpg_history_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Share via system share sheet
  Future<void> sharePdf() async {
    final bookings = await _db.getAllBookings();
    final totalSpent = await _db.getTotalSpent();
    final delivered = bookings.where((b) => b.status == BookingStatus.delivered).toList();

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ctx),
      footer: (ctx) => _buildFooter(ctx),
      build: (ctx) => [
        _buildSummarySection(delivered.length, totalSpent),
        pw.SizedBox(height: 20),
        _buildBookingsTable(bookings),
        pw.SizedBox(height: 20),
        _buildPrivacyNote(),
      ],
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'lpg_history_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildHeader(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _orange, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'LPG Cylinder History',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _orange,
                ),
              ),
              pw.Text(
                'Generated on ${_fmtFull.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: _grey),
              ),
            ],
          ),
          pw.Text('🛢️ LPG Tracker', style: pw.TextStyle(fontSize: 12, color: _grey)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'All data stored locally. Not affiliated with any LPG company.',
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(int cylinderCount, double totalSpent) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lightOrange,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total Cylinders', '$cylinderCount'),
          _summaryItem('Total Spent', '₹${totalSpent.toStringAsFixed(2)}'),
          _summaryItem('Report Date', DateFormat('d MMM yyyy').format(DateTime.now())),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _grey)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _orange)),
      ],
    );
  }

  pw.Widget _buildBookingsTable(List<CylinderBooking> bookings) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _orange),
          children: [
            _tableHeader('Booking ID'),
            _tableHeader('Company'),
            _tableHeader('DAC No.'),
            _tableHeader('Delivery Date'),
            _tableHeader('Price'),
            _tableHeader('Status'),
          ],
        ),
        // Data rows
        ...bookings.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final isEven = i % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _lightGrey,
            ),
            children: [
              _tableCell(b.bookingId),
              _tableCell(b.companyDisplayName),
              _tableCell(b.dacNumber ?? '—'),
              _tableCell(b.deliveryDate != null ? _fmt.format(b.deliveryDate!) : '—'),
              _tableCell(b.price != null ? '₹${b.price!.toStringAsFixed(2)}' : '—'),
              _tableCell(b.statusDisplayName, color: b.status == BookingStatus.delivered ? _green : _grey),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  pw.Widget _tableCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black),
      ),
    );
  }

  pw.Widget _buildPrivacyNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        'Privacy notice: This report was generated entirely on your device. No data was transmitted to any server. '
        'LPG Tracker is an independent app and is not affiliated with Indane, HP Gas, or Bharat Gas.',
        style: pw.TextStyle(fontSize: 8, color: _grey),
      ),
    );
  }
}
