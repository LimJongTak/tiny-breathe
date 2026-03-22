import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/garden_viewmodel.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

/// Watch this provider to enable automatic 30-second debounced cloud sync.
/// Usage: `ref.watch(gardenSyncProvider)` in a long-lived widget (e.g. HomeScreen).
final gardenSyncProvider = Provider<void>((ref) {
  Timer? debounce;

  ref.listen<GardenState>(gardenProvider, (_, next) {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null) return;
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 30), () {
      FirestoreService.saveGarden(uid, next.toJson());
    });
  });

  ref.onDispose(() => debounce?.cancel());
});
