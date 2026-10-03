import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_route.dart';
import 'bloc/camera/camera_cubit.dart';
import 'bloc/sync/sync_cubit.dart';
import 'core/theme/misurl_colors.dart';
import 'data/repository/capture_repository.dart';
import 'service/background_sync.dart';
import 'service/sync_engine.dart';
import 'ui/camera/camera_screen.dart';

class CamSyncApp extends StatelessWidget {
  const CamSyncApp({
    super.key,
    required this.repository,
    required this.engine,
  });

  final CaptureRepository repository;
  final SyncEngine engine;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SyncCubit(repository: repository, engine: engine),
        ),
        BlocProvider(
          create: (context) => CameraCubit(
            repository: repository,
            onCaptured: () {
              context.read<SyncCubit>().pump();
              kickBackgroundSync();
            },
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Misurl',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [misurlRouteObserver],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: MisurlColors.navy,
          colorScheme: const ColorScheme.dark(
            primary: MisurlColors.blue,
            surface: MisurlColors.navy,
          ),
        ),
        home: const CameraScreen(),
      ),
    );
  }
}

Future<void> prepareMisurlChrome() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}
