import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/api/camsync_client.dart';
import 'data/db/sync_database.dart';
import 'data/repository/capture_repository.dart';
import 'service/background_sync.dart';
import 'service/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prepareMisurlChrome();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF07111F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final database = await SyncDatabase.open();
  final repository = CaptureRepository(database);
  await repository.ensureDeviceAndBatch();
  await registerBackgroundSync();
  runApp(
    CamSyncApp(
      repository: repository,
      engine: SyncEngine(repository: repository, client: CamSyncClient()),
    ),
  );
}
