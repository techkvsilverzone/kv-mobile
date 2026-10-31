import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ContactRepository {
  ContactRepository(this._api);

  final ApiClient _api;

  /// `POST /contact` with `{name, email, subject, message}` — the same body as
  /// the web's contactService. kv-api rejects (400) if any of the four is
  /// empty and returns 502 "Failed to send message" if the mail send fails.
  Future<void> sendEnquiry(Map<String, String> payload) => _api.post('/contact', data: payload);
}

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(apiClientProvider));
});
