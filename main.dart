import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ADs Import
import 'home_screen.dart';
import 'package:dakscan/ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await MobileAds.instance.initialize();// Initialize Ads
  AdManager.loadInterstitialAd();
  await Hive.initFlutter();
  await Hive.openBox('files_history');
  await Hive.openBox('settings'); 
  
  runApp(const DakScanApp());
}

class DakScanApp extends StatelessWidget {
  const DakScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box box, _) {
        String themeString = box.get('themeMode', defaultValue: 'system');
        
        ThemeMode currentThemeMode;
        if (themeString == 'light') {
          currentThemeMode = ThemeMode.light;
        } else if (themeString == 'dark') {
          currentThemeMode = ThemeMode.dark;
        } else {
          currentThemeMode = ThemeMode.system; 
        }

        return MaterialApp(
          title: 'DakScan',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode, 
          
          // ☀️ LIGHT THEME
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFFD32F2F),
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(primary: Color(0xFFD32F2F), secondary: Colors.black87),
            textTheme: GoogleFonts.openSansTextTheme(ThemeData.light().textTheme),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, centerTitle: true),
            cardColor: Colors.white,
            navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: Colors.red.shade100, iconTheme: MaterialStateProperty.all(const IconThemeData(color: Colors.black87)), labelTextStyle: MaterialStateProperty.all(const TextStyle(color: Colors.black87))),
          ),

          // 🌙 DARK THEME
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFD32F2F),
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(primary: Color(0xFFD32F2F), secondary: Colors.white70, surface: Color(0xFF1E1E1E)),
            textTheme: GoogleFonts.openSansTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212), foregroundColor: Colors.white, elevation: 0, centerTitle: true),
            cardColor: const Color(0xFF1E1E1E),
            navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFF1E1E1E), indicatorColor: const Color(0xFFD32F2F).withOpacity(0.3), iconTheme: MaterialStateProperty.all(const IconThemeData(color: Colors.white70)), labelTextStyle: MaterialStateProperty.all(const TextStyle(color: Colors.white70))),
          ),
          
          // --- GLOBAL AD LOGIC HERE ---
          // Builder property app ki har screen ko wrap karti hai
          builder: (context, child) {
            return Material(
              child: Column(
                children:[
                  Expanded(child: child!), // Ye aapki current screen (Home/Scan etc) hogi
                  const PersistentAdBanner(), // Ye ad hamesha niche rahegi!
                ],
              ),
            );
          },
          // -----------------------------

          home: const MainContainer(),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// GLOBAL AD BANNER WIDGET (App me hamesha niche rahega)
// ------------------------------------------------------------------
class PersistentAdBanner extends StatefulWidget {
  const PersistentAdBanner({super.key});

  @override
  State<PersistentAdBanner> createState() => _PersistentAdBannerState();
}

class _PersistentAdBannerState extends State<PersistentAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' 
      : 'ca-app-pub-3940256099942544/2934735716'; 

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, err) {
          print('Ad failed to load: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Theme ke hisaab se background
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox(height: 50); // Jab tak ad load ho rahi hai
    }
  }
}
// ------------------------------------------------------------------

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});
  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const HistoryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const[
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.folder_open_rounded), label: 'Files'),
        ],
      ),
    );
  }
}

// --- HISTORY SCREEN ---
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _box = Hive.box('files_history');

  void _renameFile(int key, Map data) {
    TextEditingController controller = TextEditingController(text: data['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename File"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "New Name", suffixText: ".pdf")),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String newName = controller.text.trim();
              if (!newName.endsWith(".pdf")) newName += ".pdf";
              String oldPath = data['path'];
              File oldFile = File(oldPath);
              if (await oldFile.exists()) {
                String newPath = oldPath.replaceAll(data['name'], newName);
                await oldFile.rename(newPath);
                Map newData = Map.from(data);
                newData['name'] = newName;
                newData['path'] = newPath;
                _box.put(key, newData);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renamed Successfully!")));
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
  }

  void _deleteFile(int key, String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete File?"),
        content: const Text("This will permanently delete the file from your phone storage."),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              File file = File(path);
              if (await file.exists()) await file.delete();
              _box.delete(key);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File Deleted Permanently")));
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Files")),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.folder_off, size: 80, color: Colors.grey.shade400), const SizedBox(height: 10), const Text("No files yet. Start Scanning!", style: TextStyle(color: Colors.grey))]));
          }
          final keys = box.keys.toList().reversed.toList();
          bool isDark = Theme.of(context).brightness == Brightness.dark;

          return ListView.builder(
            itemCount: keys.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final key = keys[index];
              final data = box.get(key) as Map;
              String name = data['name'], path = data['path'], type = data['type'];
              DateTime date = DateTime.parse(data['date']);

              IconData icon = Icons.picture_as_pdf; Color color = Colors.red;
              if (type == 'Scan') color = Colors.red;
              if (type == 'Merge') { icon = Icons.merge_type; color = Colors.orange; }
              if (type == 'Split') { icon = Icons.call_split; color = Colors.purple; }
              if (type == 'Compress') { icon = Icons.compress; color = Colors.blue; }
              if (type == 'Protect') { icon = Icons.lock; color = Colors.blueGrey; }
              if (type == 'Unprotect') { icon = Icons.lock_open; color = Colors.green; }

              return Card(
                elevation: 0, color: Theme.of(context).cardColor, margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color)),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${DateFormat('dd MMM, hh:mm a').format(date)} • $type"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:[
                      IconButton(icon: const Icon(Icons.share, color: Colors.blueGrey), onPressed: () async { await Share.shareXFiles([XFile(path)], text: "Shared via DakScan"); }),
                      PopupMenuButton<String>(
                        onSelected: (value) { if (value == 'open') OpenFile.open(path); if (value == 'rename') _renameFile(key, data); if (value == 'delete') _deleteFile(key, path); },
                        itemBuilder: (context) =>[const PopupMenuItem(value: 'open', child: Row(children:[Icon(Icons.visibility, size: 20), SizedBox(width: 10), Text("Open")])), const PopupMenuItem(value: 'rename', child: Row(children:[Icon(Icons.edit, size: 20), SizedBox(width: 10), Text("Rename")])), const PopupMenuItem(value: 'delete', child: Row(children:[Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text("Delete")]))],
                      ),
                    ],
                  ),
                  onTap: () => OpenFile.open(path),
                ),
              );
            },
          );
        },
      ),
    );
  }
}