import 'package:flutter/material.dart';

import '../../bloc/sync/sync_state.dart';
import '../../core/theme/misurl_colors.dart';
import '../../core/util/byte_format.dart';
import 'upload_card.dart';

class UploadDashboard extends StatelessWidget {
  const UploadDashboard({
    super.key,
    required this.state,
    required this.onPause,
    required this.onNewBatch,
  });

  final SyncState state;
  final VoidCallback onPause;
  final VoidCallback onNewBatch;

  @override
  Widget build(BuildContext context) {
    final percent = (state.fraction * 100).round();
    return Scaffold(
      backgroundColor: MisurlColors.navy,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Upload Manager',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _LinkPill(stable: state.linkStable),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: _SectionLabel('BATCH SYNC PROGRESS')),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: MisurlColors.label,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: state.fraction,
                      minHeight: 6,
                      backgroundColor: MisurlColors.track,
                      color: MisurlColors.progress,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${formatBytes(state.uploadedBytes)} / ${formatBytes(state.totalBytes)} Uploaded',
                          style: const TextStyle(
                            color: MisurlColors.body,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onPause,
                        style: TextButton.styleFrom(
                          foregroundColor: MisurlColors.pause,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          state.paused ? 'RESUME ALL' : 'PAUSE ALL',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel('PENDING UPLOADS (${state.pendingCount})'),
                  const SizedBox(height: 12),
                  if (state.images.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 28),
                      child: Text(
                        'NO CAPTURES IN QUEUE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MisurlColors.label,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    )
                  else
                    for (final image in state.images)
                      UploadCard(
                        image: image,
                        online: state.online && !state.paused,
                        onPause: onPause,
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MisurlColors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onNewBatch,
                  child: const Text(
                    'START NEW UPLOAD BATCH',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.05,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: MisurlColors.label,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.15,
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.stable});

  final bool stable;

  @override
  Widget build(BuildContext context) {
    final color = stable ? MisurlColors.green : MisurlColors.linkDown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            stable ? 'STABLE LINK' : 'NO LINK',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
