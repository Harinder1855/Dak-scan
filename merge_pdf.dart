import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true,
    );
    if (result != null) setState(() => _selectedFiles.addAll(result.files));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selectedFiles.removeAt(oldIndex);
      _selectedFiles.insert(newIndex, item);
    });
  }

  // Password Dialog Helper
  Future<String?> _showPasswordDialog(String fileName) async {
    TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Password for $fileName"),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter Password"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Skip")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
              child: const Text("Unlock"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mergeAndSave() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 2 PDF files")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final PdfDocument finalDoc = PdfDocument();

      for (var file in _selectedFiles) {
        final List<int> bytes = await File(file.path!).readAsBytes();
        PdfDocument? loadedDoc;

        try {
           loadedDoc = PdfDocument(inputBytes: bytes);
        } catch (e) {
           String? pwd = await _showPasswordDialog(file.name);
           if (pwd != null) {
              try {
                loadedDoc = PdfDocument(inputBytes: bytes, password: pwd);
              } catch (e2) {
                print("Wrong password");
              }
           }
        }

        if (loadedDoc == null) continue;

        int pageCount = loadedDoc.pages.count;
        for (int i = 0; i < pageCount; i++) {
          PdfTemplate template = loadedDoc.pages[i].createTemplate();
          PdfPage newPage = finalDoc.pages.add();
          newPage.graphics.drawPdfTemplate(
            template, const Offset(0, 0),
            new Size(newPage.getClientSize().width, newPage.getClientSize().height)
          );
        }
        loadedDoc.dispose();
      }

      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      
      String fileName = "DakScan_Merge_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await finalDoc.save());
      finalDoc.dispose();

      HistoryManager.addToHistory(filePath: file.path, type: "Merge");
      
      if(mounted) {
        setState(() => _isLoading = false);
        
        // Success Screen par jao
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "Merge PDF"))
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
      
      appBar: AppBar(
        title: Text(_selectedFiles.isEmpty ? "Merge PDF" : "${_selectedFiles.length} Files Selected"),
        foregroundColor: const Color(0xFFD32F2F), elevation: 0
      ),
      bottomNavigationBar: _selectedFiles.length >= 2
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _mergeAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(_isLoading ? "Merging..." : "Merge Files"),
              ),
            )
          : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : _selectedFiles.isEmpty
          // Empty State
          ? SingleChildScrollView(
  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
  child: SizedBox(
    width: double.infinity, // <--- YEH HAI MAGIC LINE (Isse center ho jayega)
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Sab kuch beech mein layega
                children: [
                  const Icon(Icons.merge_type, size: 80, color: Color(0xFFD32F2F)),
                  const SizedBox(height: 20),
                  const Text("Merge PDF Files", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Combine multiple PDFs into one", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _pickPdfFiles,
                    icon: const Icon(Icons.add),
                    label: const Text("Select PDF Files"),
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
          // List State
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView(
                    onReorder: _onReorder,
                    padding: const EdgeInsets.all(10),
                    children: [
                      for (int index = 0; index < _selectedFiles.length; index++)
                        Card(
                          key: ValueKey(_selectedFiles[index].path),
                          elevation: 2,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
                            title: Text(_selectedFiles[index].name),
                            subtitle: const Text("Long press to move", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.grey),
                              onPressed: () => setState(() => _selectedFiles.removeAt(index)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Add More Button
                TextButton.icon(
                  onPressed: _pickPdfFiles,
                  icon: const Icon(Icons.add_circle, color: Color(0xFFD32F2F)),
                  label: const Text("Add More Files", style: TextStyle(color: Color(0xFFD32F2F))),
                ),
              ],
            ),
    );
  }
}