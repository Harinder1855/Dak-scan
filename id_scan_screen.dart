import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

// Model to store Front and Back of an ID
class IdCardModel {
  String? frontPath;
  String? backPath;
}

class IdScanScreen extends StatefulWidget {
  const IdScanScreen({super.key});

  @override
  State<IdScanScreen> createState() => _IdScanScreenState();
}

class _IdScanScreenState extends State<IdScanScreen> {
  // List of IDs (Shuru mein ek ID ka box khali hoga)
  List<IdCardModel> _idCards = [IdCardModel()];
  bool _isLoading = false;

  // Scanner open karna
  Future<void> _scanDocument(int index, bool isFront) async {
    try {
      List<String>? images = await CunningDocumentScanner.getPictures();
      if (images != null && images.isNotEmpty) {
        setState(() {
          // Native scanner multiple de sakta hai, par humein sirf 1 chahiye (first)
          if (isFront) {
            _idCards[index].frontPath = images.first;
          } else {
            _idCards[index].backPath = images.first;
          }
        });
      }
    } catch (e) {
      print("Error scanning: $e");
    }
  }

  // Nayi ID add karna (Add More)
  void _addNewId() {
    setState(() {
      _idCards.add(IdCardModel());
    });
  }

  // ID Box delete karna
  void _removeId(int index) {
    setState(() {
      _idCards.removeAt(index);
      if (_idCards.isEmpty) {
        _idCards.add(IdCardModel()); // Kam se kam ek khali box rahe
      }
    });
  }

  // Compress Helper
  Future<List<int>?> _compressImage(String path) async {
    return await FlutterImageCompress.compressWithFile(
      path,
      quality: 85, // Good quality for ID cards
      minWidth: 1080,
      minHeight: 1920,
    );
  }

  // Generate PDF Logic
  Future<void> _generateIdPdf() async {
    // Check if at least one front or back is scanned
    bool hasAnyImage = _idCards.any((id) => id.frontPath != null || id.backPath != null);
    if (!hasAnyImage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please scan at least one ID card!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    var status = await Permission.storage.status;
    if (!status.isGranted) await Permission.storage.request();

    final pdf = pw.Document();

    try {
      for (var idCard in _idCards) {
        // Agar front aur back dono null hain, toh us page ko skip karo
        if (idCard.frontPath == null && idCard.backPath == null) continue;

        pw.MemoryImage? frontImage;
        pw.MemoryImage? backImage;

        if (idCard.frontPath != null) {
          final compFront = await _compressImage(idCard.frontPath!);
          if (compFront != null) frontImage = pw.MemoryImage(compFront as dynamic);
        }
        
        if (idCard.backPath != null) {
          final compBack = await _compressImage(idCard.backPath!);
          if (compBack != null) backImage = pw.MemoryImage(compBack as dynamic);
        }

        // Ek A4 Page par dono (Front aur Back) set karna
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40), // Side se thodi jagah chhodna
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children:[
                  if (frontImage != null) ...[
                    
                    pw.Expanded(child: pw.Image(frontImage, fit: pw.BoxFit.contain)),
                  ],
                  if (frontImage != null && backImage != null) pw.SizedBox(height: 40), // Beech ka gap
                  if (backImage != null) ...[
                    
                    pw.Expanded(child: pw.Image(backImage, fit: pw.BoxFit.contain)),
                  ],
                ]
              );
            },
          ),
        );
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = "DakScan_ID_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      HistoryManager.addToHistory(filePath: file.path, type: "ID Card");

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "ID Card Scanned"))
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan ID Card"),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _generateIdPdf,
          icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
          label: Text(_isLoading ? "Generating PDF..." : "Generate PDF"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _idCards.length + 1, // +1 for the "Add More" button
            itemBuilder: (context, index) {
              
              // Last item is the "Add More" button
              if (index == _idCards.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  child: OutlinedButton.icon(
                    onPressed: _addNewId,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Add Another ID Card"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    ),
                  ),
                );
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children:[
                          Text("ID Card ${index + 1}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_idCards.length > 1) // Sirf tabhi delete dikhao agar 1 se zyada ho
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeId(index),
                            )
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),
                      
                      // FRONT & BACK ROW
                      Row(
                        children:[
                          // FRONT SIDE BOX
                          Expanded(
                            child: _buildImageScanBox(
                              title: "Front Side",
                              imagePath: _idCards[index].frontPath,
                              onTap: () => _scanDocument(index, true),
                              isDark: isDark
                            ),
                          ),
                          const SizedBox(width: 15),
                          // BACK SIDE BOX
                          Expanded(
                            child: _buildImageScanBox(
                              title: "Back Side",
                              imagePath: _idCards[index].backPath,
                              onTap: () => _scanDocument(index, false),
                              isDark: isDark
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text("Tap on box to scan. Skip if not needed.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // Helper Widget for the Scan Boxes
  Widget _buildImageScanBox({required String title, required String? imagePath, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children:[
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: imagePath == null 
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    const Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                    const SizedBox(height: 5),
                    Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(imagePath), fit: BoxFit.cover),
                ),
          ),
          if (imagePath != null)
            TextButton.icon(
              onPressed: onTap, 
              icon: const Icon(Icons.edit, size: 14), 
              label: const Text("Retake", style: TextStyle(fontSize: 12))
            )
        ],
      ),
    );
  }
}