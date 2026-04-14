import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class SuccessScreen extends StatelessWidget {
  final String filePath;
  final String featureName;

  const SuccessScreen({
    super.key, 
    required this.filePath, 
    this.featureName = "Saved"
  });

  @override
  Widget build(BuildContext context) {
    String fileName = filePath.split('/').last;
    
    // Theme ke hisaab se colors chunega
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // backgroundColor hata diya, ab theme se ayega
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Big Success Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1), // Halka Green effect
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 20),
              
              // 2. Success Text (Color Theme se lega)
              Text(
                "$featureName Successfully!",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Your file is ready to use.",
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16),
              ),
              const SizedBox(height: 40),

              // 3. File Card (Dark Mode me Dark, Light Mode me Light)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F), size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text("Saved in Downloads", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 4. Action Buttons (Inka color fix hai, aacha lagega)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => OpenFile.open(filePath),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text("Open File"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Share.shareXFiles([XFile(filePath)], text: "Created via DakScan App");
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text("Share File"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
              const Spacer(),

              // 5. Home Button
              TextButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.home_rounded, color: Colors.grey),
                label: const Text("Go to Home", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}