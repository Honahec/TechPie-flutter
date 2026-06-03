import '../utils/platform.dart';
import 'storage_service.dart';

const String prodApiBaseUrl = 'https://techpie.geekpie.club/api';
const String localApiBaseUrl = 'http://localhost:3000/api';
const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:3000/api';

String apiBaseUrl(StorageService storage) {
  if (!storage.useLocalhost) return prodApiBaseUrl;
  return isAndroid() ? androidEmulatorApiBaseUrl : localApiBaseUrl;
}
