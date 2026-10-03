import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/camera/camera_cubit.dart';
import '../../bloc/sync/sync_cubit.dart';
import '../../bloc/sync/sync_state.dart';
import 'upload_dashboard.dart';

class UploadManagerScreen extends StatelessWidget {
  const UploadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        return UploadDashboard(
          state: state,
          onPause: () => context.read<SyncCubit>().togglePause(),
          onNewBatch: () async {
            await context.read<SyncCubit>().startNewBatch();
            if (!context.mounted) return;
            await context.read<CameraCubit>().refreshBadge();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
