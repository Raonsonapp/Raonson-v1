// ════════════════════════════════════════════════════════════════════════════
// PATCH for: lib/reels/reels_feed/reels_screen.dart
//
// Apply these changes to _ReelsViewState:
//   1. Add AdsManager import at the top of the file
//   2. Replace _onPageChanged with the version below
//   3. Update initState to call AdsManager.instance.init()
// ════════════════════════════════════════════════════════════════════════════

// ── ADD this import at the top of reels_screen.dart ──────────────────────────
//
// import '../../core/ads/ads_manager.dart';
//

// ── REPLACE _ReelsViewState class with this ──────────────────────────────────

/*
  Inside _ReelsViewState, update initState:

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AdsManager.instance.init(); // ← ADD THIS LINE
  }

  Replace _onPageChanged with:

  void _onPageChanged(int i, _ReelsVM vm) {
    setState(() => _currentPage = i);
    if (i >= vm.reels.length - 3) vm.loadMore();
    _preloadAhead(i, vm);
    _disposeOld(i);

    // ── Trigger interstitial after N reels ──────────────────
    AdsManager.instance.onReelSwiped();
  }
*/

// ════════════════════════════════════════════════════════════════════════════
// STANDALONE: ReelAdOverlay — shown between reels as a full-screen interstitial
// This is handled automatically by AdsManager via Yandex SDK overlay.
// No custom widget needed — Yandex renders its own full-screen view.
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
// COMPLETE UPDATED _onPageChanged + initState snippet for easy copy-paste:
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// This file is a reference patch — see comments above.
// The actual implementation requires editing reels_screen.dart directly.

/// Mixin to add ad trigger to any PageView-based screen
mixin ReelsAdMixin<T extends StatefulWidget> on State<T> {
  int _reelsAdCounter = 0;

  /// Call this in onPageChanged
  void triggerAdOnSwipe() {
    _reelsAdCounter++;
    // AdsManager handles cooldown and frequency internally
    // Import ads_manager.dart and call:
    // AdsManager.instance.onReelSwiped();
  }
}
