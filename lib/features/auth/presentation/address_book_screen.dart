import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
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

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('${address.fullName}, ${address.city} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressListProvider.notifier).remove(address.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _makeDefault(Address address) async {
    try {
      // The server unsets the previous default itself; the controller re-lists
      // afterwards so the whole list reflects that.
      await ref
          .read(addressListProvider.notifier)
          .update(address.id, address.copyWith(isDefault: true));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Address book')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profile/addresses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(addressListProvider.notifier).load(),
        child: addresses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : 'Could not load your addresses.',
            onRetry: () => ref.read(addressListProvider.notifier).load(),
          ),
          data: (list) {
            if (list.isEmpty) return const _EmptyState();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AddressCard(
                address: list[i],
                onEdit: () => context.push('/profile/addresses/edit', extra: list[i]),
                onDelete: () => _delete(list[i]),
                onMakeDefault: () => _makeDefault(list[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(address.fullName, style: theme.textTheme.titleMedium),
                ),
                if (address.isDefault)
                  Chip(
                    label: const Text('Default'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (address.label != null && address.label!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(address.label!, style: theme.textTheme.labelMedium),
            ],
            const SizedBox(height: 8),
            Text(address.address),
            Text('${address.city}, ${address.state} ${address.pincode}'),
            const SizedBox(height: 4),
            Text(address.phone, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
                const Spacer(),
                if (!address.isDefault)
                  TextButton(onPressed: onMakeDefault, child: const Text('Set default')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.location_off_outlined,
            size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text('No addresses yet',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Add a delivery address to speed up checkout.',
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onRetry, child: const Text('Try again'))),
      ],
    );
  }
}
