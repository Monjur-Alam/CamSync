import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/misurl_colors.dart';
import '../../core/util/byte_format.dart';
import '../../core/util/status_label.dart';
import '../../data/model/queued_image.dart';

class UploadCard extends StatelessWidget {
  const UploadCard({
    super.key,
    required this.image,
    required this.online,
    required this.onPause,
  });

  final QueuedImage image;
  final bool online;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final role = statusRole(image, online: online);
    final label = statusLabel(image, online: online);
    final uploading = image.status == QueueStatus.uploading;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: MisurlColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MisurlColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Image.file(
                File(image.filePath),
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFFD7D3CC)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        image.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (uploading) ...[
                      _PauseMark(onPressed: onPause),
                      const SizedBox(width: 8),
                      Text(
                        '${image.progress}%',
                        style: const TextStyle(
                          color: MisurlColors.label,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatBytes(image.bytes),
                  style: const TextStyle(
                    color: MisurlColors.label,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                _StatusLine(label: label, role: role),
                if (uploading) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: image.progress / 100,
                      minHeight: 4,
                      backgroundColor: MisurlColors.track,
                      color: MisurlColors.progress,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseMark extends StatelessWidget {
  const _PauseMark({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MisurlColors.label),
        ),
        child: const Icon(Icons.pause, size: 12, color: Colors.white),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.role});

  final String label;
  final ColorRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      ColorRole.synced => MisurlColors.green,
      ColorRole.failed => MisurlColors.failed,
      ColorRole.uploading => MisurlColors.progress,
      ColorRole.retrying => MisurlColors.amber,
      ColorRole.waiting => MisurlColors.waiting,
      ColorRole.queued => MisurlColors.label,
    };
    return Row(
      children: [
        if (role == ColorRole.synced) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: MisurlColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
