import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../auth/application/address_controller.dart';
import '../../application/installment_payer.dart';
import '../../data/savings_repository.dart';
import 'passbook_view.dart';
import 'print_boundary.dart';
import 'scheme_details_view.dart';

/// Ledger width; the web lets the table scroll sideways on phones instead of squeezing it.
const _passbookWidth = 760.0;

/// Full-page plan details for one passbook (kv-ui SavingsPlanDetails).
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
    final cs = Theme.of(context).colorScheme;
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

    Widget? passbook;
    if (scheme != null) {
      passbook = RepaintBoundary(
        key: _passbookKey,
        child: SizedBox(
          width: _passbookWidth,
          child: PassbookView(
              scheme: scheme, userName: customerName, userPhone: customerPhone, userAddress: addressLine),
        ),
      );
    }

    final Widget body;
    if (scheme == null && async.isLoading) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    } else if (scheme == null) {
      final e = async.error;
      body = Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: cs.surface, border: Border.all(color: cs.outline), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(
            e is ServerException && e.statusCode == 403
                ? 'This passbook belongs to another customer.'
                : 'No savings plan found for this passbook number.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/savings-scheme'), child: const Text('Back to my schemes')),
        ]),
      );
    } else if (isFlexible) {
      // KV Smart Purchase Plan keeps the ledger as its main view.
      body = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: cs.surface,
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: passbook),
        ),
      );
    } else {
      body = Container(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 640 ? 24 : 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: SchemeDetailsView(
          scheme: scheme,
          userName: customerName,
          userPhone: customerPhone,
          paying: _payer.payingSchemeId == scheme.id,
          onPay: isOwner ? () => _payer.pay(scheme, isFlexible: isFlexible) : null,
        ),
      );
    }

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 64),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () => context.go('/savings-scheme'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('My schemes'),
                  ),
                  const Spacer(),
                  if (scheme != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          printBoundary(context, _passbookKey, 'KV-Silver-Zone-Passbook-$number'),
                      icon: const Icon(Icons.print_outlined, size: 14),
                      label: const Text('Print passbook'),
                    ),
                ]),
              ),
              body,
            ]),
          ),
        ),
      ],
    );

    final background = Color.alphaBlend(cs.surfaceContainerHighest.withValues(alpha: 0.3), cs.surface);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(children: [
          // Fixed plans only print the ledger: it is painted beneath the opaque page so the
          // print raster can capture it without showing it.
          if (passbook != null && !isFlexible)
            Positioned(top: 0, left: 0, width: _passbookWidth, child: ExcludeSemantics(child: passbook)),
          Positioned.fill(child: ColoredBox(color: background, child: page)),
        ]),
      ),
    );
  }
}
