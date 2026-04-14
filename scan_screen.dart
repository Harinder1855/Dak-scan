import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart'; // Import Success Screen
import 'package:dakscan/ad_manager.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<String> _scannedImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanDocument();
    });
  }

  Future<void> _scanDocument() async {
    try {
      List<String>? images = await CunningDocumentScanner.getPictures();
      if (images != null && images.isNotEmpty) {
        setState(() {
          _scannedImages = images;
        });
        if(mounted) _showSizeSelectionDialog();
      } else {
        if (mounted && _scannedImages.isEmpty) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSizeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Save PDF As", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _generatePdf(1024); },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Small Size (1MB)"),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _generatePdf(2048); },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFD32F2F), side: const BorderSide(color: Color(0xFFD32F2F)), padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Medium Size (2MB)"),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () { Navigator.pop(context); _generatePdf(0); }, child: const Text("Original Quality", style: TextStyle(color: Colors.grey))),
            ],
          ),
        );
      },
    );
  }

  Future<List<int>?> _compressImageToTarget(String path, int targetSizePerImageKb) async {
    int quality = 90;
    int step = 15;
    List<int>? result;
    result = await FlutterImageCompress.compressWithFile(path, quality: quality, minWidth: 1080, minHeight: 1920);
    while (result != null && result.length > (targetSizePerImageKb * 1024) && quality > 10) {
      quality -= step;
      result = await FlutterImageCompress.compressWithFile(path, quality: quality, minWidth: 1080, minHeight: 1920);
    }
    return result;
  }

  Future<void> _generatePdf(int maxFileSizeKb) async {
    setState(() => _isLoading = true);
    var status = await Permission.storage.status;
    if (!status.isGranted) await Permission.storage.request();

    final pdf = pw.Document();
    int targetPerImageKb = maxFileSizeKb > 0 ? (maxFileSizeKb / _scannedImages.length).floor() : 10000;
    if (targetPerImageKb < 50) targetPerImageKb = 50;

    try {
      for (var imagePath in _scannedImages) {
        final compressedBytes = await _compressImageToTarget(imagePath, targetPerImageKb);
        if (compressedBytes == null) continue;
        final image = pw.MemoryImage(compressedBytes as dynamic);
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
      }

      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      String fileName = "DakScan_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      HistoryManager.addToHistory(filePath: file.path, type: "Scan");

      if (mounted) {
        setState(() => _isLoading = false);
        // CHANGE: Direct Success Screen Par Jao
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "Scanned Document"))
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Processing..."), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(color: Color(0xFFD32F2F)), SizedBox(height: 20), Text("Opening Scanner...", style: TextStyle(color: Colors.grey))])),
    );
  }
}