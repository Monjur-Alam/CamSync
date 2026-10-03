enum UploadDisposition { synced, retry, stop, cancelled }

class UploadResult {
  const UploadResult({
    required this.disposition,
    this.errorCode,
    this.remoteUrl,
  });

  final UploadDisposition disposition;
  final String? errorCode;
  final String? remoteUrl;

  bool get synced => disposition == UploadDisposition.synced;
}

/// Maps an API response onto the queue rule from the CamSync contract.
UploadResult interpretUpload({
  required int? status,
  required Map<String, dynamic>? body,
  required bool transportError,
  bool cancelled = false,
}) {
  if (cancelled) {
    return const UploadResult(disposition: UploadDisposition.cancelled);
  }
  if (transportError || status == null) {
    return const UploadResult(disposition: UploadDisposition.retry);
  }
  if (status == 200 || status == 201) {
    return UploadResult(
      disposition: UploadDisposition.synced,
      remoteUrl: _remoteUrl(body),
    );
  }
  final code = _errorCode(body);
  final retryable = body?['retryable'] == true;
  if (status == 401 || status == 413 || status == 415) {
    return UploadResult(disposition: UploadDisposition.stop, errorCode: code);
  }
  if (status >= 500) {
    return UploadResult(disposition: UploadDisposition.retry, errorCode: code);
  }
  if (status == 400 &&
      (retryable || code == 'partial_upload' || code == 'upload_failed')) {
    return UploadResult(disposition: UploadDisposition.retry, errorCode: code);
  }
  if (status >= 400) {
    return UploadResult(disposition: UploadDisposition.stop, errorCode: code);
  }
  return UploadResult(disposition: UploadDisposition.retry, errorCode: code);
}

String? _errorCode(Map<String, dynamic>? body) {
  final error = body?['error'];
  if (error is Map && error['code'] is String) return error['code'] as String;
  return null;
}

String? _remoteUrl(Map<String, dynamic>? body) {
  final image = body?['image'];
  if (image is Map && image['url'] is String) return image['url'] as String;
  return null;
}
