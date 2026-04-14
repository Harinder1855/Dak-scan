import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dakscan/history_manager.dart';
import 'package:dakscan/success_screen.dart';
import 'package:dakscan/ad_manager.dart';

class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  PlatformFile? _selectedFile;
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true;
  bool _isMatched = false;

  // Helper: Red Error Dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Error", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message, 
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        List<int> bytes = await file.readAsBytes();

        // CHECK: Kya file pehle se protected hai?
        bool isAlreadyProtected = false;
        try {
          // Bina password ke kholne ki koshish karo
          final PdfDocument doc = PdfDocument(inputBytes: bytes);
          doc.dispose();
          isAlreadyProtected = false; // Khul gayi, matlab password nahi hai
        } catch (e) {
          // Error aaya, matlab password laga hua hai
          isAlreadyProtected = true;
        }

        if (isAlreadyProtected) {
          _showErrorDialog("This file is already Password Protected!\nPlease select an unprotected file.");
          return; // Yahan ruk jao, file select mat karo
        }

        // Agar protected nahi hai, tabhi select karo
        setState(() => _selectedFile = result.files.single);
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  void _checkPasswordMatch() {
    setState(() {
      _isMatched = _passController.text.isNotEmpty && 
                   (_passController.text == _confirmPassController.text);
    });
  }

  Future<void> _saveProtectedPdf() async {
    if (_selectedFile == null) return;
    if (!_isMatched) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final List<int> bytes = await File(_selectedFile!.path!).readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // Security Logic
      PdfSecurity security = document.security;
      security.userPassword = _passController.text;
      security.ownerPassword = _passController.text;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      List<int> newBytes = await document.save();
      document.dispose();

      // Save File
      Directory? directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) directory = await getExternalStorageDirectory();
      
      String fileName = "DakScan_Protected_${DateTime.now().millisecondsSinceEpoch}.pdf";
      File file = File("${directory!.path}/$fileName");
      await file.writeAsBytes(newBytes);

      // Clear Fields
      _passController.clear();
      _confirmPassController.clear();
      
      // Save History
      HistoryManager.addToHistory(filePath: file.path, type: "Protect");

      if(mounted) {
        setState(() {
          _isLoading = false;
          _isMatched = false;
          _selectedFile = null;
        });
        
        // Success Screen par jao
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SuccessScreen(filePath: file.path, featureName: "PDF Protected"))
        );
      }

    } catch (e) {
      setState(() => _isLoading = false);
      print(e);
      _showErrorDialog("Failed to protect file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: const Text("Protect PDF"), foregroundColor: const Color(0xFFD32F2F), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Select Button (Jab file select na ho)
            if (_selectedFile == null)
             SizedBox(
               height: 300,
               child: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.lock_outline, size: 80, color: Color(0xFFD32F2F)),
                     const SizedBox(height: 20),
                     const Text("Protect PDF File", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 10),
                     const Text("Encrypt your PDF with a password", style: TextStyle(color: Colors.grey)),
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
                     )
                   ],
                 ),
               ),
             )
            else 
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // File Info Card
                 Card(
                   color: Colors.red.shade50,
                   elevation: 0,
                   child: ListTile(
                     leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
                     title: Text(_selectedFile!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                     trailing: IconButton(
                       icon: const Icon(Icons.close, color: Colors.grey),
                       onPressed: () => setState(() => _selectedFile = null),
                     ),
                   ),
                 ),

                 const SizedBox(height: 30),
                 const Text("Set Password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 15),

                 // Password Fields
                 TextField(
                   controller: _passController,
                   obscureText: _isObscure,
                   onChanged: (_) => _checkPasswordMatch(),
                   decoration: InputDecoration(
                     labelText: "Password",
                     border: const OutlineInputBorder(),
                     suffixIcon: IconButton(
                       icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                       onPressed: () => setState(() => _isObscure = !_isObscure),
                     ),
                   ),
                 ),
                 const SizedBox(height: 15),

                 TextField(
                   controller: _confirmPassController,
                   obscureText: _isObscure,
                   onChanged: (_) => _checkPasswordMatch(),
                   decoration: const InputDecoration(
                     labelText: "Confirm Password",
                     border: OutlineInputBorder(),
                   ),
                 ),
                 
                 const SizedBox(height: 10),
                 
                 // Match Indicator
                 if (_passController.text.isNotEmpty)
                  Row(
                    children: [
                      Icon(_isMatched ? Icons.check_circle : Icons.error, color: _isMatched ? Colors.green : Colors.red, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        _isMatched ? "Passwords Matched" : "Passwords do not match",
                        style: TextStyle(color: _isMatched ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                 const SizedBox(height: 30),

                 // Protect Button
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                     onPressed: (_isLoading || !_isMatched) ? null : _saveProtectedPdf, 
                     icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.lock),
                     label: Text(_isLoading ? "Encrypting..." : "Protect & Save PDF"),
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.all(15), 
                       backgroundColor: const Color(0xFFD32F2F), 
                       foregroundColor: Colors.white,
                       textStyle: const TextStyle(fontSize: 18),
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