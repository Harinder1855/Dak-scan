import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // VIBRATION (Haptic Feedback) ke liye
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Screens Import
import 'package:dakscan/scan_screen.dart';
import 'package:dakscan/id_scan_screen.dart';
import 'package:dakscan/image_to_pdf.dart';
import 'package:dakscan/merge_pdf.dart';
import 'package:dakscan/split_pdf.dart';
import 'package:dakscan/compress_pdf.dart';
import 'package:dakscan/protect_pdf.dart';
import 'package:dakscan/unprotect_pdf.dart';
import 'package:dakscan/ad_manager.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showThemeDialog(BuildContext context, Box box) {
    String currentTheme = box.get('themeMode', defaultValue: 'system');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Theme"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              RadioListTile(title: const Text("System Default"), value: 'system', groupValue: currentTheme, activeColor: const Color(0xFFD32F2F), onChanged: (val) { box.put('themeMode', val); Navigator.pop(context); }),
              RadioListTile(title: const Text("Light Mode"), value: 'light', groupValue: currentTheme, activeColor: const Color(0xFFD32F2F), onChanged: (val) { box.put('themeMode', val); Navigator.pop(context); }),
              RadioListTile(title: const Text("Dark Mode"), value: 'dark', groupValue: currentTheme, activeColor: const Color(0xFFD32F2F), onChanged: (val) { box.put('themeMode', val); Navigator.pop(context); }),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const[
            Icon(Icons.document_scanner, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text("DakScan", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      
      // DRAWER (Side Menu)
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children:[
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFD32F2F)),
              accountName: const Text("DakScan", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              accountEmail: const Text("Version 1.0.0", style: TextStyle(color: Colors.white70)),
              currentAccountPicture: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), color: Colors.white),
                child: const Icon(Icons.document_scanner, size: 40, color: Color(0xFFD32F2F)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children:[
                  _buildDrawerItem(Icons.home, "Home", () => Navigator.pop(context)),
                  const Divider(),
                  ValueListenableBuilder(
                    valueListenable: Hive.box('settings').listenable(),
                    builder: (context, Box box, _) {
                      String theme = box.get('themeMode', defaultValue: 'system');
                      String displayTheme = theme == 'system' ? 'System Default' : (theme == 'dark' ? 'Dark Mode' : 'Light Mode');
                      return ListTile(
                        leading: const Icon(Icons.brightness_6, color: Colors.grey),
                        title: const Text("Theme", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(displayTheme),
                        onTap: () { Navigator.pop(context); _showThemeDialog(context, box); },
                      );
                    }
                  ),
                  const Divider(),
                  _buildDrawerItem(Icons.share, "Share App", () { Navigator.pop(context); Share.share("Scan docs, Merge PDF & more with DakScan! Download now."); }),
                  _buildDrawerItem(Icons.star_rate, "Rate Us", () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link will be added after Play Store publish"))); }),
                  _buildDrawerItem(Icons.mail, "Contact / Feedback", () async {
                    Navigator.pop(context);
                    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: 'dakscan@support.com', query: 'subject=DakScan Feedback');
                    if (await canLaunchUrl(emailLaunchUri)) await launchUrl(emailLaunchUri);
                  }),
                  const Divider(),
                  _buildDrawerItem(Icons.privacy_tip_outlined, "Privacy Policy", () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Privacy Policy: All data is stored locally."))); }),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(20.0), child: Text("Made in India 🇮🇳\nby DakScan Team", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),

      // --- BODY (NO SCROLL, FIT TO SCREEN) ---
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              const Text("Primary Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              
              // TOP 2 BIG CARDS (Takes 30% of remaining space)
              Expanded(
                flex: 3,
                child: Row(
                  children:[
                    Expanded(
                      child: Bouncing3DCard(
                        isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ScanScreen())),
                        gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        child: _buildBigCardContent("Scan Doc", "Camera to PDF", Icons.document_scanner),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Bouncing3DCard(
                        isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const IdScanScreen())),
                        gradient: LinearGradient(colors:[Colors.blue.shade600, Colors.blue.shade800], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        child: _buildBigCardContent("ID Card", "Aadhar/PAN", Icons.badge),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              const Text("PDF Tools", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),

              // BOTTOM 6 GRID TOOLS (Takes 60% of remaining space perfectly divided)
              Expanded(
                flex: 6,
                child: Column(
                  children:[
                    // ROW 1
                    Expanded(
                      child: Row(
                        children:[
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ImageToPdfScreen())), child: _buildSmallCardContent("Image to PDF", Icons.image, isDark))),
                          const SizedBox(width: 15),
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MergePdfScreen())), child: _buildSmallCardContent("Merge PDF", Icons.merge_type, isDark))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    // ROW 2
                    Expanded(
                      child: Row(
                        children:[
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SplitPdfScreen())), child: _buildSmallCardContent("Split PDF", Icons.call_split, isDark))),
                          const SizedBox(width: 15),
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CompressPdfScreen())), child: _buildSmallCardContent("Compress", Icons.compress, isDark))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    // ROW 3
                    Expanded(
                      child: Row(
                        children:[
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProtectPdfScreen())), child: _buildSmallCardContent("Protect", Icons.lock, isDark))),
                          const SizedBox(width: 15),
                          Expanded(child: Bouncing3DCard(isDark: isDark, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UnprotectPdfScreen())), child: _buildSmallCardContent("Unlock", Icons.lock_open, isDark))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Niche thodi jagah bottom bar ke liye
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget Content for Big Cards
  Widget _buildBigCardContent(String title, String subtitle, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 35),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // Helper Widget Content for Small Cards
  Widget _buildSmallCardContent(String title, IconData icon, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        CircleAvatar(
          radius: 22,
          backgroundColor: isDark ? Colors.red.withOpacity(0.1) : const Color(0xFFFFEBEE), 
          child: Icon(icon, color: const Color(0xFFD32F2F), size: 24),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: Colors.grey), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), onTap: onTap);
  }
}

// ============================================================================
// CUSTOM 3D BOUNCING CARD WIDGET (With Haptic Feedback/Vibration)
// ============================================================================

class Bouncing3DCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final bool isDark;

  const Bouncing3DCard({super.key, required this.child, required this.onTap, this.gradient, required this.isDark});

  @override
  State<Bouncing3DCard> createState() => _Bouncing3DCardState();
}

class _Bouncing3DCardState extends State<Bouncing3DCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    // FIX: Strong Vibration
    HapticFeedback.vibrate(); 
    setState(() => _scale = 0.95);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0); // Wapis normal size
    widget.onTap(); // Function call
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0); // Agar dabakar ungli hata li bina click kiye
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100), // Speed of bounce
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? Theme.of(context).cardColor : null,
            borderRadius: BorderRadius.circular(16),
            // 3D SHADOW EFFECT
            boxShadow:[
              BoxShadow(
                color: widget.isDark ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                offset: const Offset(4, 6), // Shadow neeche ki taraf
                blurRadius: 10,
              ),
              // Agar light mode hai to upar se slight white glow (Real 3D feel)
              if (!widget.isDark)
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 5,
                ),
            ],
            border: widget.gradient == null 
                ? Border.all(color: widget.isDark ? Colors.grey.shade800 : Colors.white, width: 1.5)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}