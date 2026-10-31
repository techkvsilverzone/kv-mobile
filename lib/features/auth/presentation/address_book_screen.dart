import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../application/address_controller.dart';
import '../data/models/address.dart';

/// Full address-book CRUD. Note this is *new* UI, not a port — the web app
/// only ever creates addresses inline during checkout and has no list, edit, or
/// delete screen at all.
class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressListProvider.notifier).load());
  }

  void _add() => context.push('/profile/addresses/new');
  void _edit(Address a) => context.push('/profile/addresses/edit', extra: a);

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('${address.fullName}, ${address.city} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Kv.danger, minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressListProvider.notifier).remove(address.id);
      if (mounted) showKvToast(context, 'Address deleted');
    } on ApiException catch (e) {
      if (mounted) showKvToast(context, "Couldn't delete address", message: e.message, error: true);
    }
  }

  Future<void> _makeDefault(Address address) async {
    try {
      // The server unsets the previous default itself; the controller re-lists
      // afterwards so the whole list reflects that.
      await ref.read(addressListProvider.notifier).update(address.id, address.copyWith(isDefault: true));
      if (mounted) showKvToast(context, 'Default address updated');
    } on ApiException catch (e) {
      if (mounted) showKvToast(context, "Couldn't update address", message: e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressListProvider);
    final hasList = addresses.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      bottomNavigationBar: hasList
          ? BottomActionBar(
              action: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add new address'),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(addressListProvider.notifier).load(),
        child: addresses.when(
          loading: () => ListView(
            padding: const EdgeInsets.only(top: Kv.pad),
            children: const [ListSkeleton(rows: 3, height: 140)],
          ),
          error: (error, _) => ListView(children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your addresses",
              message: error is ApiException ? error.message : 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.read(addressListProvider.notifier).load(),
            ),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.location_on_outlined,
                    title: 'No saved addresses',
                    message: 'Add a delivery address to check out faster.',
                    actionLabel: 'Add address',
                    onAction: _add,
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(Kv.pad),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => AddressCard(
                    address: list[i],
                    onTap: () => _edit(list[i]),
                    onEdit: () => _edit(list[i]),
                    onDelete: () => _delete(list[i]),
                    onMakeDefault: () => _makeDefault(list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

/// One saved address with its ⋮ actions.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final Address address;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final label = (address.label ?? '').trim();
    final icon = switch (label.toLowerCase()) {
      'home' => Icons.home_outlined,
      'office' || 'work' => Icons.work_outline_rounded,
      _ => Icons.location_on_outlined,
    };

    return KvCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: address.isDefault ? Kv.blueSoft : Kv.bg, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: address.isDefault ? Kv.blue : Kv.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(label.isEmpty ? address.fullName : label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (address.isDefault) const StatusPill('Default', tone: PillTone.info),
              ]),
              const SizedBox(height: 6),
              if (label.isNotEmpty)
                Text(address.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${address.address}\n${address.city}, ${address.state} ${address.pincode}',
                  style: const TextStyle(color: Kv.muted, height: 1.45)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 14, color: Kv.subtle),
                const SizedBox(width: 6),
                Text('+91 ${address.phone}', style: const TextStyle(color: Kv.muted, fontSize: 13)),
              ]),
            ]),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Address options',
          icon: const Icon(Icons.more_vert_rounded, color: Kv.muted),
          shape: RoundedRectangleBorder(borderRadius: Kv.smallRadius),
          onSelected: (v) => switch (v) {
            'edit' => onEdit(),
            'default' => onMakeDefault(),
            _ => onDelete(),
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: _MenuItem(Icons.edit_outlined, 'Edit')),
            if (!address.isDefault)
              const PopupMenuItem(value: 'default', child: _MenuItem(Icons.check_circle_outline_rounded, 'Set as default')),
            const PopupMenuItem(value: 'delete', child: _MenuItem(Icons.delete_outline_rounded, 'Delete', danger: true)),
          ],
        ),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label, {this.danger = false});
  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: danger ? Kv.danger : Kv.ink),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: danger ? Kv.danger : Kv.ink)),
      ]);
}
