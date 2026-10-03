import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../model/queued_image.dart';
import 'upload_result.dart';

class CamSyncClient {
  CamSyncClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 40),
              sendTimeout: const Duration(seconds: 90),
              headers: {'X-Api-Key': ApiConfig.apiKey},
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  Future<bool> health() async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/v1/health',
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final data = response.data;
      return response.statusCode == 200 && data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> storedIds(String batchId) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/batches/$batchId',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != 200) return const [];
    final data = response.data;
    if (data is! Map) return const [];
    final images = data['images'];
    if (images is! List) return const [];
    return [
      for (final image in images)
        if (image is Map && image['client_image_id'] is String)
          image['client_image_id'] as String,
    ];
  }

  Future<UploadResult> upload(
    QueuedImage image, {
    required String deviceId,
    CancelToken? cancelToken,
    void Function(int progress)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          image.filePath,
          filename: image.fileName,
        ),
        'client_image_id': image.clientImageId,
        'batch_id': image.batchId,
        'device_id': deviceId,
        'captured_at': image.capturedAt,
      });
      final response = await _dio.post<dynamic>(
        '/api/v1/images',
        data: form,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          onProgress?.call(((sent / total) * 100).round().clamp(0, 100));
        },
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      return interpretUpload(
        status: response.statusCode,
        body: response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : null,
        transportError: false,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return const UploadResult(disposition: UploadDisposition.cancelled);
      }
      final data = error.response?.data;
      return interpretUpload(
        status: error.response?.statusCode,
        body: data is Map<String, dynamic>
            ? data
            : data is Map
            ? Map<String, dynamic>.from(data)
            : null,
        transportError: error.response == null,
      );
    }
  }
}
