import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/ui/kv_ui.dart';
import '../orders/presentation/widgets/order_status_chip.dart' show formatOrderDate;
import 'returns.dart';

String _last6(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

PillTone _tone(String status) => switch (status) {
      'Approved' => PillTone.success,
      'Rejected' => PillTone.danger,
      'Completed' => PillTone.info,
      _ => PillTone.warning,
    };

/// `/returns`: the customer's return requests.
class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(myReturnsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Returns')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myReturnsProvider.future),
        child: returns.when(
          skipLoadingOnRefresh: true,
          loading: () => ListView(
            padding: const EdgeInsets.only(top: 12),
            children: const [ListSkeleton(rows: 4, height: 120)],
          ),
          error: (e, _) => ListView(children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your returns',
              message: e is ApiException ? e.message : 'Please try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(myReturnsProvider),
            ),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  EmptyState(
                    icon: Icons.assignment_return_outlined,
                    title: 'No return requests',
                    message: 'If something isn’t right, you can request a return from a delivered order.',
                    actionLabel: 'View my orders',
                    onAction: () => context.push('/orders'),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, Kv.gap),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ReturnCard(r: list[i]),
                ),
        ),
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.r});
  final ReturnRequest r;

  @override
  Widget build(BuildContext context) {
    final code = r.videoReferenceCode ?? '';
    return KvCard(
      onTap: r.orderId.isEmpty ? null : () => context.push('/orders/${r.orderId}'),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Return #${_last6(r.id)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                  'Order #${_last6(r.orderId)}${r.createdAt == null ? '' : ' · ${formatOrderDate(r.createdAt!)}'}',
                  style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
          StatusPill(r.status, tone: _tone(r.status)),
        ]),
        const SizedBox(height: 10),
        Text(r.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        Row(children: [
          StatusPill(r.isKvFault ? 'KV fault claim' : 'Exchange / store credit',
              tone: r.isKvFault ? PillTone.info : PillTone.neutral),
          if (r.videoStatus == 'received') ...[
            const SizedBox(width: 6),
            const StatusPill('Video received', tone: PillTone.success, icon: Icons.check_rounded),
          ],
          const Spacer(),
          if (r.refundAmount > 0) PriceText(r.refundAmount, size: 15),
        ]),
        if (r.videoStatus == 'awaiting') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(color: Kv.warningSoft, borderRadius: Kv.smallRadius),
            child: Row(children: [
              const Icon(Icons.videocam_outlined, color: Kv.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  code.isEmpty
                      ? 'Video pending — send your unboxing video on WhatsApp'
                      : 'Video pending — WhatsApp it with code $code',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3A06), fontWeight: FontWeight.w500),
                ),
              ),
              if (code.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showKvToast(context, 'Code copied');
                  },
                  child: const Text('Copy'),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}
