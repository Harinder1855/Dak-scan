import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart'; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf; 
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/ad_manager.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  PlatformFile? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // 1. Pick PDF
  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        
        File file = File(result.files.single.path!);
        List<int> bytes = await file.readAsBytes();
        
        final sync_pdf.PdfDocument doc = sync_pdf.PdfDocument(inputBytes: bytes);
        int count = doc.pages.count;
        doc.dispose();

        setState(() {
          _selectedFile = result.files.single;
          _totalPages = count;
          _startController.text = "1";
          _endController.text = count.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. Convert Logic (Fixed Cropping)
  Future<void> _convertRangeToImages() async {
    if (_selectedFile == null) return;

    int start = int.tryParse(_startController.text) ?? 1;
    int end = int.tryParse(_endController.text) ?? _totalPages;

    if (start < 1 || end > _totalPages || start > end) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Page Range!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      File file = File(_selectedFile!.path!);
      final Uint8List fileBytes = await file.readAsBytes();

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/DakScan_Images');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      int currentPageIndex = 0;
      int savedCount = 0;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // FIX 1: 'scale' hata kar 'dpi: 200' kar diya (Clear Full Page, No Crop)
      await for (var page in Printing.raster(fileBytes, dpi: 200)) {
        currentPageIndex++; 

        if (currentPageIndex < start) continue; 
        if (currentPageIndex > end) break;      

        final Uint8List pngBytes = await page.toPng();

        // FIX 2: Format ko 'png' kar diya taaki Black Background na aaye
        final Uint8List? compressedBytes = await FlutterImageCompress.compressWithList(
          pngBytes,
          quality: 80, // PNG Quality (Size control ke liye)
          format: CompressFormat.png, // <--- Yeh zaroori hai Black screen hatane ke liye
        );

        if (compressedBytes != null) {
          // Extension bhi .png kar di
          String imgName = "IMG_${timestamp}_Page_$currentPageIndex.png";
          File imgFile = File("${directory.path}/$imgName");
          await imgFile.writeAsBytes(compressedBytes);
          savedCount++;
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Success!"),
            content: Text("$savedCount Images Saved in:\nDownloads/DakScan_Images/"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
            ],
          ),
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF to Image")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedFile == null)
              Expanded(
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Select PDF"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
                  ),
                ),
              )
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.teal),
                  title: Text(_selectedFile!.name),
                  subtitle: Text("Total Pages: $_totalPages"),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() { _selectedFile = null; }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text("Select Page Range:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "From", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "To", border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _convertRangeToImages,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Icon(Icons.image),
                  label: Text(_isLoading ? "Converting..." : "Convert to Images"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}