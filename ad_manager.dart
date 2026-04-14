import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;

  // 1. Ad ko Background mein Load karna
  static void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Google Test Interstitial Ad ID
          : 'ca-app-pub-3940256099942544/4411468910',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Ad failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  // 2. Ad Dikhana aur Success Screen par bhejna
  static void showInterstitialAd(BuildContext context, Widget nextScreen) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose(); // Ad band hone par memory clean karo
          loadInterstitialAd(); // Agli baar ke liye naya ad load karo
          // Success Screen par jao
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitialAd();
          // Agar ad fail ho jaye toh direct screen khol do
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null; // Ek baar dikhane ke baad khali kar do
    } else {
      // Agar internet slow hone ki wajah se ad load nahi hui, toh direct Success Screen par bhej do
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
      loadInterstitialAd(); // Agli baar ke liye try karo
    }
  }
}