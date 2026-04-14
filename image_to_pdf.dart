import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart'; // Import Success Screen
import 'package:dakscan/ad_manager.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final XFile item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _showSizeSelectionDialog() {
    if (_selectedImages.isEmpty) return;
    showModalBottomSheet(
      context: context,
      
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("PDF Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _generatePdf(1024); },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Small Size (Below 1MB)"),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _generatePdf(2048); },
                  style: ElevatedButton.styleFrom(foregroundColor: const Color(0xFFD32F2F), side: const BorderSide(color: Color(0xFFD32F2F)), padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("Medium Size (Below 2MB)"),
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
    int targetPerImageKb = maxFileSizeKb > 0 ? (maxFileSizeKb / _selectedImages.length).floor() : 10000;
    if (targetPerImageKb < 50) targetPerImageKb = 50;

    try {
      for (var imgFile in _selectedImages) {
        final compressedBytes = await _compressImageToTarget(imgFile.path, targetPerImageKb);
        if (compressedBytes == null) continue;
        final image = pw.MemoryImage(compressedBytes as dynamic);
        pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
      }

      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      String fileName = "DakScan_Img2Pdf_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      HistoryManager.addToHistory(filePath: file.path, type: "Image2PDF");

      if (mounted) {
        setState(() => _isLoading = false);
        
        // --- FIX: Direct Success Screen (OpenFile hata diya) ---
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "Image to PDF"))
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: Text(_selectedImages.isEmpty ? "Image to PDF" : "${_selectedImages.length} Images Selected"),
        
        foregroundColor: const Color(0xFFD32F2F),
        elevation: 0,
        actions: [
          if (_selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: _pickImages,
            )
        ],
      ),
      bottomNavigationBar: _selectedImages.isNotEmpty 
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _showSizeSelectionDialog,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                child: Text(_isLoading ? "Generating..." : "Generate PDF"),
              ),
            )
          : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : _selectedImages.isEmpty 
            ? SingleChildScrollView(
  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
  child: SizedBox(
    width: double.infinity, // <--- YEH HAI MAGIC LINE (Isse center ho jayega)
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Sab kuch beech mein layega
                  children: [
                    const Icon(Icons.image_outlined, size: 80, color: Color(0xFFD32F2F)),
                    const SizedBox(height: 20),
                    const Text("Convert Images to PDF", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Select JPG or PNG images", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add),
                      label: const Text("Select Images"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), textStyle: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              )
              )
            : ReorderableListView(
                padding: const EdgeInsets.all(10),
                onReorder: _onReorder,
                children: [
                  for (int index = 0; index < _selectedImages.length; index++)
                    Card(
                      key: ValueKey(_selectedImages[index].path),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.file(File(_selectedImages[index].path), width: 50, height: 50, fit: BoxFit.cover)),
                        title: Text("Image ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Long press to move", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => _removeImage(index)),
                      ),
                    ),
                ],
              ),
    );
  }
}