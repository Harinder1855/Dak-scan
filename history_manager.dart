import 'package:hive_flutter/hive_flutter.dart';
import 'package:dakscan/ad_manager.dart';

class HistoryManager {
  // Yeh function file ki details Hive database mein save karega
  static void addToHistory({required String filePath, required String type}) {
    // Box wahi hona chahiye jo main.dart mein open kiya tha
    final box = Hive.box('files_history');
    
    // File ka naam path se nikal lenge
    String fileName = filePath.split('/').last;

    // Data ka map banaya
    final entry = {
      'path': filePath,
      'name': fileName,
      'type': type, // e.g. Scan, Merge, Split
      'date': DateTime.now().toIso8601String(), // Aaj ki date
    };
    
    // Hive mein add kiya
    box.add(entry);
    print("History Saved: $fileName ($type)");
  }
}