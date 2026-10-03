import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newImageId() => 'img_${_uuid.v4().replaceAll('-', '')}';

String newBatchId() => 'batch_${_uuid.v4().replaceAll('-', '')}';

String newDeviceId() => 'dev_${_uuid.v4().replaceAll('-', '')}';

String captureFileName(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  return 'CAPTURE_${local.year}${two(local.month)}${two(local.day)}_${two(local.hour)}${two(local.minute)}${two(local.second)}.jpg';
}
