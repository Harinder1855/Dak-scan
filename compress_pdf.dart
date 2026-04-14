import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  PlatformFile? _selectedFile;
  String _originalSize = "";
  String _compressedSize = "";
  bool _isLoading = false;
  double _quality = 50;

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'],
      );
      if (result != null) {
        File file = File(result.files.single.path!);
        int sizeBytes = await file.length();
        setState(() {
          _selectedFile = result.files.single;
          _originalSize = (sizeBytes / 1024).toStringAsFixed(2) + " KB";
          _compressedSize = "";
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _compressAndSave() async {
    if (_selectedFile == null) return;
    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();
      final File originalFile = File(_selectedFile!.path!);
      final Uint8List fileBytes = await originalFile.readAsBytes();

      double dpi = _quality < 50 ? 72 : 120; 

      await for (var page in Printing.raster(fileBytes, dpi: dpi)) {
        final Uint8List pngBytes = await page.toPng();
        final Uint8List? compressedImage = await FlutterImageCompress.compressWithList(
          pngBytes, quality: _quality.toInt(), format: CompressFormat.png, 
        );
        if (compressedImage == null) continue;
        final image = pw.MemoryImage(compressedImage);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ));
      }

      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      
      String fileName = "DakScan_Comp_${_quality.toInt()}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      
      int newLen = await file.length();
      String newSizeStr = (newLen / 1024).toStringAsFixed(2) + " KB";

      HistoryManager.addToHistory(filePath: file.path, type: "Compress");

      setState(() {
        _isLoading = false;
        _compressedSize = newSizeStr;
      });

      if (mounted) {
        // Success Screen par jao
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "Compress PDF"))
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: const Text("Compress PDF"), foregroundColor: const Color(0xFFD32F2F), elevation: 0),
      bottomNavigationBar: _selectedFile != null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _compressAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(_isLoading ? "Compressing..." : "Compress PDF"),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : _selectedFile == null
              // Empty State
              ? SingleChildScrollView(
  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
  child: SizedBox(
    width: double.infinity, // <--- YEH HAI MAGIC LINE (Isse center ho jayega)
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Sab kuch beech mein layega
                    children: [
                      const Icon(Icons.compress, size: 80, color: Color(0xFFD32F2F)),
                      const SizedBox(height: 20),
                      const Text("Reduce PDF Size", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("Optimize PDF for sharing", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: _pickPdf,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Select PDF File"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                )
              )
              // Selected State
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.red.shade50,
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
                          title: Text(_selectedFile!.name),
                          subtitle: Text("Size: $_originalSize"),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => setState(() { _selectedFile = null; _compressedSize = ""; }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text("Compression Level", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Low Quality (Small Size)", style: TextStyle(color: Colors.green, fontSize: 12)),
                          Text("High Quality (Big Size)", style: TextStyle(color: Colors.blue, fontSize: 12)),
                        ],
                      ),
                      Slider(
                        value: _quality,
                        min: 10, max: 90, divisions: 8,
                        label: "${_quality.toInt()}%",
                        activeColor: const Color(0xFFD32F2F),
                        onChanged: (val) => setState(() => _quality = val),
                      ),
                      Center(child: Text("${_quality.toInt()}% Quality", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      
                      if (_compressedSize.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 10),
                              Text("New Size: $_compressedSize", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}