import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class Review {
  const Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.title,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String userName;
  final int rating;
  final String title;
  final String comment;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        userName: (j['userName'] ?? '').toString(),
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        comment: (j['comment'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

/// `GET /products/:id/reviews` → `{averageRating, totalReviews, reviews}`.
class ReviewSummary {
  const ReviewSummary({this.averageRating = 0, this.totalReviews = 0, this.reviews = const []});
  final double averageRating;
  final int totalReviews;
  final List<Review> reviews;

  factory ReviewSummary.fromJson(dynamic raw) {
    final j = raw is Map ? raw : const {};
    return ReviewSummary(
      averageRating: (j['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
      reviews: j['reviews'] is List
          ? (j['reviews'] as List).whereType<Map>().map((e) => Review.fromJson(e.cast<String, dynamic>())).toList()
          : const [],
    );
  }
}

class ReviewRepository {
  ReviewRepository(this._api);
  final ApiClient _api;

  Future<ReviewSummary> fetch(String productId) async =>
      ReviewSummary.fromJson(await _api.get('/products/$productId/reviews'));

  Future<void> create(String productId, {required int rating, required String title, required String comment}) =>
      _api.post('/products/$productId/reviews',
          data: {'productId': productId, 'rating': rating, 'title': title, 'comment': comment});
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(apiClientProvider)));

final productReviewsProvider =
    FutureProvider.family<ReviewSummary, String>((ref, id) => ref.watch(reviewRepositoryProvider).fetch(id));
