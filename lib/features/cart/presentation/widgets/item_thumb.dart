import 'package:flutter/material.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../../catalog/data/models/product.dart';
import '../../../catalog/presentation/widgets/product_image.dart';

/// Rounded product thumbnail for cart, checkout, order and return rows.
/// [voucher] draws a gift-voucher tile instead of a photo.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, this.image, this.size = 72, this.voucher = false});

  final String? image;
  final double size;
  final bool voucher;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: Kv.smallRadius,
        child: SizedBox.square(
          dimension: size,
          child: voucher
              ? ColoredBox(
                  color: Kv.goldSoft,
                  child: Icon(Icons.card_giftcard_rounded, color: Kv.gold, size: size * 0.42),
                )
              : ColoredBox(
                  color: Kv.bg,
                  child: ProductImageView(
                    image: image == null ? null : ProductImage(data: image!, sortOrder: 0),
                    decodeWidth: size,
                  ),
                ),
        ),
      );
}
