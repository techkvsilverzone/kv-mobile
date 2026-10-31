import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';

String _idOf(dynamic v) => v is Map ? (v['_id'] ?? v['id'] ?? '').toString() : (v ?? '').toString();

/// A customer's return request (kv-ui services/returns.ts).
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.reason,
    required this.status,
    required this.refundAmount,
    required this.isKvFault,
    required this.videoStatus,
    this.videoReferenceCode,
    this.createdAt,
  });

  final String id, orderId, reason;

  /// 'Pending' | 'Approved' | 'Rejected' | 'Completed'.
  final String status;
  final double refundAmount;

  /// faultType == 'kv_fault' (else 'customer_preference').
  final bool isKvFault;

  /// 'not_required' | 'awaiting' | 'received'.
  final String videoStatus;
  final String? videoReferenceCode;
  final DateTime? createdAt;

  factory ReturnRequest.fromJson(Map<String, dynamic> j) => ReturnRequest(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        orderId: _idOf(j['orderId']),
        reason: (j['reason'] ?? '').toString(),
        status: (j['status'] ?? 'Pending').toString(),
        refundAmount: (j['refundAmount'] as num?)?.toDouble() ?? 0,
        isKvFault: j['faultType'] == 'kv_fault',
        videoStatus: (j['videoStatus'] ?? 'not_required').toString(),
        videoReferenceCode: j['videoReferenceCode']?.toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

/// Where to WhatsApp the unboxing video for a KV-fault claim.
class VideoInstructions {
  const VideoInstructions(this.whatsappNumber, this.referenceCode, this.windowHours);
  final String whatsappNumber, referenceCode;
  final int windowHours;
}

class ReturnItemInput {
  const ReturnItemInput({required this.product, required this.name, required this.quantity, required this.price});
  final String product, name;
  final int quantity;
  final double price;
  Map<String, dynamic> toJson() => {'product': product, 'name': name, 'quantity': quantity, 'price': price};
}

class ReturnsRepository {
  ReturnsRepository(this._api);
  final ApiClient _api;

  Future<List<ReturnRequest>> fetchMine() async {
    final data = await _api.get('/returns/me');
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => ReturnRequest.fromJson(e.cast<String, dynamic>())).toList();
  }

  /// `claimWindowHours` from `GET /returns/policy`.
  Future<int?> fetchClaimWindowHours() async {
    final data = await _api.get('/returns/policy');
    return data is Map ? (data['claimWindowHours'] as num?)?.toInt() : null;
  }

  /// Returns the video instructions for a KV-fault claim, else null.
  Future<VideoInstructions?> create({
    required String orderId,
    required bool kvFault,
    required String reason,
    required String description,
    required List<ReturnItemInput> items,
  }) async {
    final data = await _api.post('/returns', data: {
      'orderId': orderId,
      'faultType': kvFault ? 'kv_fault' : 'customer_preference',
      'reason': reason,
      'description': description,
      'items': [for (final i in items) i.toJson()],
    });
    final v = data is Map ? data['videoInstructions'] : null;
    if (v is! Map) return null;
    return VideoInstructions((v['whatsappNumber'] ?? '').toString(), (v['referenceCode'] ?? '').toString(),
        (v['windowHours'] as num?)?.toInt() ?? 0);
  }
}

final returnsRepositoryProvider = Provider<ReturnsRepository>((ref) => ReturnsRepository(ref.watch(apiClientProvider)));

final myReturnsProvider = FutureProvider<List<ReturnRequest>>((ref) async {
  if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
  return ref.watch(returnsRepositoryProvider).fetchMine();
});

final claimWindowHoursProvider =
    FutureProvider<int?>((ref) => ref.watch(returnsRepositoryProvider).fetchClaimWindowHours());
