import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_session.dart';
import '../../core/ui/kv_ui.dart';
import 'reviews.dart';

/// Five stars, the first [rating] filled.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 14, this.onTap});
  final num rating;
  final double size;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var star = 1; star <= 5; star++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(star),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: onTap == null ? 0 : 4),
              child: Icon(
                star <= rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: star <= rating.round() ? Kv.gold : Kv.subtle,
                semanticLabel: onTap == null ? null : '$star star${star == 1 ? '' : 's'}',
              ),
            ),
          ),
      ]);
}

/// Average, stars and count, with a bar per star level.
class ReviewSummaryCard extends StatelessWidget {
  const ReviewSummaryCard({super.key, required this.summary});
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final counts = List.filled(5, 0);
    for (final r in summary.reviews) {
      if (r.rating >= 1 && r.rating <= 5) counts[r.rating - 1]++;
    }
    final total = summary.reviews.isEmpty ? 1 : summary.reviews.length;
    return KvCard(
      child: Row(children: [
        Column(children: [
          Text(summary.averageRating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          StarRow(rating: summary.averageRating, size: 16),
          const SizedBox(height: 4),
          Text('${summary.totalReviews} review${summary.totalReviews == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: Kv.muted)),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(children: [
            for (var s = 5; s >= 1; s--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 12, child: Text('$s', style: const TextStyle(fontSize: 12, color: Kv.muted))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: counts[s - 1] / total,
                        minHeight: 6,
                        color: Kv.gold,
                        backgroundColor: Kv.bg,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final name = review.userName.trim().isEmpty ? 'Customer' : review.userName.trim();
    return KvCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Kv.blueSoft,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(color: Kv.blue, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (review.createdAt != null)
                Text(DateFormat('d MMM y').format(review.createdAt!.toLocal()),
                    style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
          StarRow(rating: review.rating),
        ]),
        if (review.title.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(review.comment, style: const TextStyle(fontSize: 14, color: Kv.muted, height: 1.45)),
        ],
      ]),
    );
  }
}

/// Write-a-review form in a sheet. Same payload as the web's form.
Future<void> showWriteReviewSheet(BuildContext context, String productId) =>
    showKvSheet<void>(context, title: 'Write a review', builder: (_) => _WriteReviewForm(productId: productId));

class _WriteReviewForm extends ConsumerStatefulWidget {
  const _WriteReviewForm({required this.productId});
  final String productId;

  @override
  ConsumerState<_WriteReviewForm> createState() => _WriteReviewFormState();
}

class _WriteReviewFormState extends ConsumerState<_WriteReviewForm> {
  int _rating = 5;
  final _title = TextEditingController();
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .create(widget.productId, rating: _rating, title: _title.text, comment: _comment.text);
      ref.invalidate(productReviewsProvider(widget.productId));
      if (!mounted) return;
      Navigator.pop(context);
      showKvToast(context, 'Review submitted', message: 'Thank you for your review!');
    } catch (_) {
      if (mounted) showKvToast(context, "Couldn't submit your review", message: 'Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Text('Your rating', style: TextStyle(fontSize: 13, color: Kv.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: StarRow(rating: _rating, size: 34, onTap: (v) => setState(() => _rating = v)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title', hintText: 'Sum it up in a few words'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Your review', hintText: 'What did you like about it?', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _comment.text.trim().isEmpty || _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit review'),
          ),
        ],
      );
}

/// All reviews for a product, pushed from the product page.
class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key, required this.productId, required this.productName});
  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(productReviewsProvider(productId));
    final authed = ref.watch(authSessionProvider).isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      bottomNavigationBar: authed
          ? BottomActionBar(
              action: FilledButton.icon(
                onPressed: () => showWriteReviewSheet(context, productId),
                icon: const Icon(Icons.rate_review_outlined, size: 20),
                label: const Text('Write a review'),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(productReviewsProvider(productId).future).catchError((_) => const ReviewSummary()),
        child: reviews.when(
          loading: () => ListView(padding: const EdgeInsets.only(top: Kv.pad), children: const [ListSkeleton(rows: 4, height: 110)]),
          error: (_, __) => ListView(children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load reviews",
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(productReviewsProvider(productId)),
            ),
          ]),
          data: (s) => ListView(padding: const EdgeInsets.all(Kv.pad), children: [
            Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Kv.muted)),
            const SizedBox(height: 12),
            if (s.reviews.isEmpty)
              EmptyState(
                icon: Icons.reviews_outlined,
                title: 'No reviews yet',
                message: authed ? 'Be the first to share what you think.' : 'Sign in to be the first to review it.',
              )
            else ...[
              ReviewSummaryCard(summary: s),
              for (final r in s.reviews) ...[const SizedBox(height: 12), ReviewTile(review: r)],
            ],
          ]),
        ),
      ),
    );
  }
}
