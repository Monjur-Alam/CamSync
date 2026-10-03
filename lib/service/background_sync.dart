import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/api/camsync_client.dart';
import '../data/db/sync_database.dart';
import '../data/repository/capture_repository.dart';
import 'sync_engine.dart';

const syncTaskName = 'misurlUpload';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final database = await SyncDatabase.open();
      final repository = CaptureRepository(database);
      await repository.ensureDeviceAndBatch();
      final engine = SyncEngine(
        repository: repository,
        client: CamSyncClient(),
      );
      await engine.drain();
      return true;
    } catch (error, stack) {
      debugPrint('Misurl background sync failed: $error\n$stack');
      return false;
    }
  });
}

Future<void> registerBackgroundSync() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'misurl-periodic',
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  } catch (error, stack) {
    debugPrint('Background sync was not scheduled: $error\n$stack');
  }
}

Future<void> kickBackgroundSync() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
  try {
    await Workmanager().registerOneOffTask(
      'misurl-once',
      syncTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  } catch (error) {
    debugPrint('One-off sync was not scheduled: $error');
  }
}
