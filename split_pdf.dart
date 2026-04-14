import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  PlatformFile? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;
  String? _filePassword;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  Future<String?> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Password Required"),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter PDF Password"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
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

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      PlatformFile file = result.files.first;
      final List<int> bytes = await File(file.path!).readAsBytes();

      PdfDocument? doc;
      String? password;

      try {
        doc = PdfDocument(inputBytes: bytes);
      } catch (e) {
        password = await _showPasswordDialog();
        if (password != null) {
          try {
            doc = PdfDocument(inputBytes: bytes, password: password);
          } catch (e) {
            setState(() => _isLoading = false);
            return;
          }
        } else {
           setState(() => _isLoading = false);
           return; 
        }
      }

      int count = doc!.pages.count;
      doc.dispose();

      setState(() {
        _selectedFile = file;
        _totalPages = count;
        _filePassword = password;
        _isLoading = false;
        _startController.text = "1";
        _endController.text = count.toString();
      });
    }
  }

  Future<void> _splitAndSave() async {
    if (_selectedFile == null) return;
    int start = int.tryParse(_startController.text) ?? 1;
    int end = int.tryParse(_endController.text) ?? 1;

    if (start < 1 || end > _totalPages || start > end) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Page Range!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<int> bytes = await File(_selectedFile!.path!).readAsBytes();
      final PdfDocument originalDoc = _filePassword != null 
          ? PdfDocument(inputBytes: bytes, password: _filePassword!)
          : PdfDocument(inputBytes: bytes);
      final PdfDocument newDoc = PdfDocument();

      for (int i = start - 1; i < end; i++) {
        PdfTemplate template = originalDoc.pages[i].createTemplate();
        PdfPage newPage = newDoc.pages.add();
        newPage.graphics.drawPdfTemplate(
          template, const Offset(0, 0),
          new Size(newPage.getClientSize().width, newPage.getClientSize().height)
        );
      }

      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      
      String fileName = "DakScan_Split_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(await newDoc.save());
      originalDoc.dispose();
      newDoc.dispose();

      HistoryManager.addToHistory(filePath: file.path, type: "Split");

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Success Screen par jao
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "Split PDF"))
        );
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: const Text("Split PDF"), foregroundColor: const Color(0xFFD32F2F), elevation: 0),
      bottomNavigationBar: _selectedFile != null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _splitAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(_isLoading ? "Splitting..." : "Split PDF"),
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
                  const Icon(Icons.call_split, size: 80, color: Color(0xFFD32F2F)),
                  const SizedBox(height: 20),
                  const Text("Split PDF Files", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Extract pages from your PDF", style: TextStyle(color: Colors.grey)),
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
                      subtitle: Text("Total Pages: $_totalPages"),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => setState(() { _selectedFile = null; _filePassword = null; }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Page Range", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "From Page",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.first_page),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _endController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "To Page",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.last_page),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}