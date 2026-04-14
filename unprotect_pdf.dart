import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

class UnprotectPdfScreen extends StatefulWidget {
  const UnprotectPdfScreen({super.key});

  @override
  State<UnprotectPdfScreen> createState() => _UnprotectPdfScreenState();
}

class _UnprotectPdfScreenState extends State<UnprotectPdfScreen> {
  bool _isLoading = false;

  Future<String?> _askPassword() async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("File is Locked 🔒"),
        content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(hintText: "Enter Password")),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
           ElevatedButton(
             onPressed: () => Navigator.pop(context, controller.text),
             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
             child: const Text("Unlock"),
           ),
        ],
      ),
    );
  }

  void _showAlreadyUnprotectedAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Not Protected"),
        content: const Text("This file is NOT password protected.\nPlease select a protected file."),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _pickAndUnlock() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null) return;
    setState(() => _isLoading = true);

    try {
      File file = File(result.files.single.path!);
      List<int> bytes = await file.readAsBytes();
      PdfDocument? document;
      bool isProtected = false;
      try {
        PdfDocument testDoc = PdfDocument(inputBytes: bytes);
        testDoc.dispose();
      } catch (e) {
        isProtected = true;
      }

      if (!isProtected) {
        setState(() => _isLoading = false);
        _showAlreadyUnprotectedAlert();
        return;
      }

      String? pwd = await _askPassword();
      if (pwd == null) { setState(() => _isLoading = false); return; }
      
      try {
          document = PdfDocument(inputBytes: bytes, password: pwd);
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wrong Password!"), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
      }

      document.security.userPassword = ""; 
      document.security.ownerPassword = "";
      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      String fileName = "DakScan_Unlocked_${DateTime.now().millisecondsSinceEpoch}.pdf";
      File newFile = File("${directory!.path}/$fileName");
      await newFile.writeAsBytes(await document.save());
      document.dispose();

      HistoryManager.addToHistory(filePath: newFile.path, type: "Unprotect");

      setState(() => _isLoading = false);
      if(mounted) {
         // Success Screen par jao (Note: Yahan variable 'newFile' hai)
         Navigator.push(
           context, 
           MaterialPageRoute(builder: (context) => SuccessScreen(filePath: newFile.path, featureName: "PDF Unlocked"))
         );
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: const Text("Unlock PDF"), foregroundColor: const Color(0xFFD32F2F), elevation: 0),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : SingleChildScrollView(
  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
  child: SizedBox(
    width: double.infinity, // <--- YEH HAI MAGIC LINE (Isse center ho jayega)
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Sab kuch beech mein layega
              children: [
                const Icon(Icons.no_encryption_gmailerrorred, size: 80, color: Color(0xFFD32F2F)),
                const SizedBox(height: 20),
                const Text("Unlock PDF File", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Remove password from PDF", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _pickAndUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text("Select Protected PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }
}