import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../../auth/application/address_controller.dart';
import '../../application/installment_payer.dart';
import '../../data/savings_repository.dart';
import '../savings_scheme_screen.dart' show canPayScheme;
import '../widgets/scheme_widgets.dart';
import 'passbook_view.dart';
import 'print_boundary.dart';
import 'scheme_details_view.dart';

/// Ledger width for printing; the paper ledger is wider than a phone.
const _passbookWidth = 760.0;

/// One passbook (kv-ui SavingsPlanDetails): app-style summary and history, the printable
/// ledger behind the print action, and Pay in a bottom bar for the owner.
class PassbookScreen extends ConsumerStatefulWidget {
  const PassbookScreen({super.key, required this.passbookNumber});

  final String passbookNumber;

  @override
  ConsumerState<PassbookScreen> createState() => _PassbookScreenState();
}

class _PassbookScreenState extends ConsumerState<PassbookScreen> {
  final _passbookKey = GlobalKey();
  late final InstallmentPayer _payer;
  bool _addressesRequested = false;

  @override
  void initState() {
    super.initState();
    _payer = InstallmentPayer(
      ref: ref,
      context: () => context,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onPaid: (_) => ref.invalidate(passbookProvider(widget.passbookNumber)),
    );
  }

  @override
  void dispose() {
    _payer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.passbookNumber;
    final async = ref.watch(passbookProvider(number));
    final scheme = async.valueOrNull;
    final user = ref.watch(currentUserProvider);

    final isOwner = scheme != null && user != null && scheme.owner.id == user.id;
    final isFlexible = scheme != null && ref.watch(isFlexibleTypeProvider(scheme.schemeType));

    // The address is only known for the signed-in customer, so staff lookups print without it.
    String? addressLine;
    if (isOwner) {
      if (!_addressesRequested) {
        _addressesRequested = true;
        Future.microtask(() => ref.read(addressListProvider.notifier).load());
      }
      final addresses = ref.watch(addressListProvider).valueOrNull ?? const [];
      final a = addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
      if (a != null) addressLine = '${a.address}, ${a.city}, ${a.state} - ${a.pincode}';
    }

    String? orElse(String? v, String? fallback) => (v ?? '').isNotEmpty ? v : fallback;
    final customerName = orElse(scheme?.owner.name, isOwner ? user.name : null);
    final customerPhone = orElse(scheme?.owner.phone, isOwner ? user.phone : null);

    final Widget body;
    if (scheme == null && async.isLoading) {
      body = KvShimmer(
        child: ListView(padding: const EdgeInsets.all(Kv.pad), physics: const NeverScrollableScrollPhysics(), children: const [
          KvSkeleton(height: 250, radius: Kv.radius),
          SizedBox(height: Kv.gap),
          KvSkeleton(width: 140, height: 18),
          SizedBox(height: 12),
          KvSkeleton(height: 280, radius: Kv.radius),
        ]),
      );
    } else if (scheme == null) {
      final forbidden = async.error is ServerException && (async.error as ServerException).statusCode == 403;
      body = Center(
        child: EmptyState(
          icon: forbidden ? Icons.lock_outline_rounded : Icons.search_off_rounded,
          title: forbidden ? 'This passbook belongs to another customer.' : 'No savings plan found for this passbook number.',
          message: forbidden ? null : 'Check the number on your passbook and try again.',
          actionLabel: 'Back to my schemes',
          onAction: () => context.go('/savings-scheme'),
        ),
      );
    } else {
      // The ledger is painted beneath the opaque page so the print raster can capture it unseen.
      body = Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          width: _passbookWidth,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              key: _passbookKey,
              child: SizedBox(
                width: _passbookWidth,
                child: PassbookView(
                    scheme: scheme, userName: customerName, userPhone: customerPhone, userAddress: addressLine),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Kv.bg,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(passbookProvider(number));
                await ref.read(passbookProvider(number).future).catchError((_) => scheme);
              },
              child: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 32), children: [
                SchemeDetailsView(
                    scheme: scheme, userName: customerName, userPhone: customerPhone, flexible: isFlexible),
              ]),
            ),
          ),
        ),
      ]);
    }

    final payable = isOwner && canPayScheme(scheme, isFlexible: isFlexible);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passbook'),
        actions: [
          if (scheme != null)
            IconButton(
              tooltip: 'Print passbook',
              onPressed: () => printBoundary(context, _passbookKey, 'KV-Silver-Zone-Passbook-$number'),
              icon: const Icon(Icons.print_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      bottomNavigationBar: payable
          ? PassbookPayBar(
              scheme: scheme,
              flexible: isFlexible,
              paying: _payer.payingSchemeId == scheme.id,
              onPay: () async {
                if (!isFlexible) return _payer.pay(scheme, isFlexible: false);
                final amount = await showFlexAmountSheet(context, scheme);
                if (amount != null && mounted) await _payer.pay(scheme, isFlexible: true, customAmount: amount);
              },
            )
          : null,
    );
  }
}
