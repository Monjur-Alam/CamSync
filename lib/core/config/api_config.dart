/// Contract for the CamSync upload API deployed with this project.
///
/// The key matches `config.php` on the host. Health checks do not require it;
/// every other route does. Rotate the key if this source is published.
abstract final class ApiConfig {
  static const baseUrl = 'https://munjuralam.com/camsync';
  static const apiKey =
      '4f11fd374b5e48978ec9eb5b7abc410ba9143a5ee80812c4cf891c5e0c2e4cb5';
  static const maxUploadBytes = 8 * 1024 * 1024;
}
